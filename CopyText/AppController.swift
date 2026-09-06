import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var state: WorkflowState = .idle
    @Published private(set) var isBurstSession = false
    @Published var devModeEnabled: Bool {
        didSet { UserDefaults.standard.set(devModeEnabled, forKey: Keys.devMode) }
    }
    @Published var launchAtLoginEnabled: Bool {
        didSet { LaunchAtLogin.setEnabled(launchAtLoginEnabled) }
    }

    let eventLog = EventLog()
    let geminiSettings = GeminiSettings()

    private let clipboardWatcher = ClipboardWatcher()
    private var resultResetTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    private var waitingTimeoutTask: Task<Void, Never>?
    private var burstTimeoutTask: Task<Void, Never>?
    @Published private(set) var currentPipelineMode: PipelineMode = .copyText

    private enum CaptureSession {
        case none
        case single
        case burst
    }

    private var captureSession: CaptureSession = .none

    private enum Keys {
        static let devMode = "devModeEnabled"
    }

    private enum Timeouts {
        static let waiting: TimeInterval = 10
        static let burst: TimeInterval = 60
        static let burstResultFlash: TimeInterval = 0.8
    }

    init() {
        devModeEnabled = UserDefaults.standard.bool(forKey: Keys.devMode)
        launchAtLoginEnabled = LaunchAtLogin.isEnabled()

        clipboardWatcher.onImageDetected = { [weak self] payload in
            Task { @MainActor in
                self?.handleImageDetected(payload)
            }
        }

        clipboardWatcher.onChangeIgnored = { [weak self] changeCount, reason in
            Task { @MainActor in
                self?.eventLog.log("Clipboard changed (count=\(changeCount)) — ignored: \(reason)")
            }
        }

        eventLog.log("CopyText started")
    }

    func handleIconClick(mode: PipelineMode) {
        switch state {
        case .idle:
            start(mode: mode)
        case .waiting:
            cancel(reason: "Icon clicked — cancelled")
        case .success, .failure:
            if isBurstSession {
                endSession(reason: "Icon clicked — cancelled")
            }
        case .processing:
            break
        }
    }

    func upgradeToThirdCall() {
        guard state == .waiting,
              currentPipelineMode == .extractJSON,
              geminiSettings.isThirdCallEnabled else {
            return
        }
        currentPipelineMode = .extractJSONThird
        eventLog.log("Third call mode — waiting for screenshot")
    }

    func start(mode: PipelineMode = .copyText) {
        guard state.canStart else {
            eventLog.log("Start ignored — state is \(state.label)")
            return
        }

        currentPipelineMode = mode
        captureSession = .single
        beginWaiting(message: mode.waitingMessage)
        scheduleSingleWaitingTimeout()
    }

    func startForOneMinute() {
        guard state.canStart else {
            eventLog.log("Start for 1 Min ignored — state is \(state.label)")
            return
        }

        currentPipelineMode = .copyText
        captureSession = .burst
        isBurstSession = true
        beginWaiting(message: "Start for 1 Min — waiting for screenshots")
        scheduleBurstTimeout()
    }

    func cancel(reason: String = "Cancel clicked") {
        guard state.canCancel || isBurstSession else { return }
        endSession(reason: reason)
    }

    func toggleDevMode() {
        devModeEnabled.toggle()
        eventLog.log("Dev Mode \(devModeEnabled ? "enabled" : "disabled")")
    }

    func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        eventLog.log("Launch at login \(launchAtLoginEnabled ? "enabled" : "disabled")")
    }

    private func handleImageDetected(_ payload: ClipboardImagePayload) {
        guard state == .waiting else { return }

        waitingTimeoutTask?.cancel()
        let size = payload.image.size
        eventLog.log("Image detected — format=\(payload.format), bytes=\(payload.byteCount), size=\(Int(size.width))x\(Int(size.height))")
        transition(to: .processing)

        pipelineTask?.cancel()
        pipelineTask = Task { [weak self] in
            await self?.runPipeline(payload)
        }
    }

    private func runPipeline(_ payload: ClipboardImagePayload) async {
        do {
            let finalText: String

            switch currentPipelineMode {
            case .copyText:
                finalText = try await runCopyTextPipeline(payload)
            case .extractJSON:
                finalText = try await runExtractJSONPipeline(payload)
            case .extractJSONThird:
                finalText = try await runExtractJSONPipeline(payload, prompt: geminiSettings.thirdPrompt)
            }

            ClipboardWriter.writeText(finalText)
            eventLog.logText("Clipboard final", finalText)
            eventLog.log("Clipboard replaced with extracted text")
            finish(with: .success)
        } catch {
            eventLog.log("Pipeline failed: \(error.localizedDescription)")
            finish(with: .failure)
        }
    }

    private func runCopyTextPipeline(_ payload: ClipboardImagePayload) async throws -> String {
        eventLog.log("OCR started (local)")
        let ocrResult = try await OCRService.extractText(from: payload.image)
        eventLog.log(String(format: "OCR finished — %.2fs, confidence=%.2f",
                            ocrResult.duration, ocrResult.averageConfidence))
        eventLog.logText("OCR raw", ocrResult.text)

        let finalText = TextNormalizer.normalize(ocrResult.text)
        eventLog.logText("After line-break normalize", finalText)
        return finalText
    }

    private func runExtractJSONPipeline(_ payload: ClipboardImagePayload) async throws -> String {
        let apiKeys = geminiSettings.allAPIKeys()
        guard !apiKeys.isEmpty else {
            throw GeminiClientError.missingAPIKey
        }

        let startIndex = geminiSettings.indexForNextRequest()
        let encoded = try ImageEncoder.encodePNG(from: payload.image)
        eventLog.log("Screenshot uploaded to Gemini — \(encoded.byteCount) bytes PNG, model=\(geminiSettings.selectedModel), key \(startIndex + 1)/\(apiKeys.count)")

        let geminiResult = try await GeminiClient.extractJSON(
            from: payload.image,
            prompt: geminiSettings.prompt,
            model: geminiSettings.selectedModel,
            apiKeys: apiKeys,
            startingIndex: startIndex
        )

        geminiSettings.markAPIKeyUsed(at: geminiResult.usedIndex)
        eventLog.log(String(format: "Gemini finished — %.2fs (key %d/%d)", geminiResult.result.duration, geminiResult.usedIndex + 1, apiKeys.count))
        eventLog.logText("Gemini raw output", geminiResult.result.output)

        if GeminiClient.isValidJSON(geminiResult.result.output) {
            eventLog.log("JSON validated")
        } else {
            eventLog.log("JSON invalid — copying raw Gemini output anyway")
        }

        return geminiResult.result.output
    }

    private func runExtractJSONPipeline(
        _ payload: ClipboardImagePayload,
        prompt: String
    ) async throws -> String {
        let apiKeys = geminiSettings.allAPIKeys()
        guard !apiKeys.isEmpty else {
            throw GeminiClientError.missingAPIKey
        }

        let startIndex = geminiSettings.indexForNextRequest()
        let encoded = try ImageEncoder.encodePNG(from: payload.image)
        eventLog.log("Screenshot uploaded to Gemini — \(encoded.byteCount) bytes PNG, model=\(geminiSettings.selectedModel), key \(startIndex + 1)/\(apiKeys.count)")

        let geminiResult = try await GeminiClient.extractJSON(
            from: payload.image,
            prompt: prompt,
            model: geminiSettings.selectedModel,
            apiKeys: apiKeys,
            startingIndex: startIndex
        )

        geminiSettings.markAPIKeyUsed(at: geminiResult.usedIndex)
        eventLog.log(String(format: "Gemini finished — %.2fs (key %d/%d)", geminiResult.result.duration, geminiResult.usedIndex + 1, apiKeys.count))
        eventLog.logText("Gemini raw output", geminiResult.result.output)

        if GeminiClient.isValidJSON(geminiResult.result.output) {
            eventLog.log("JSON validated")
        } else {
            eventLog.log("JSON invalid — copying raw Gemini output anyway")
        }

        return geminiResult.result.output
    }

    private func finish(with result: WorkflowState) {
        if captureSession == .burst {
            transition(to: result)

            resultResetTask?.cancel()
            resultResetTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Timeouts.burstResultFlash))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.captureSession == .burst else { return }
                    self.resumeBurstWaiting()
                }
            }
            return
        }

        transition(to: result)

        resultResetTask?.cancel()
        resultResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.state == result else { return }
                self.captureSession = .none
                self.transition(to: .idle)
            }
        }
    }

    private func beginWaiting(message: String) {
        waitingTimeoutTask?.cancel()
        let changeCount = ClipboardWatcher.currentChangeCount()
        transition(to: .waiting)
        eventLog.log("\(message) (clipboard count=\(changeCount))")
        clipboardWatcher.startMonitoring(from: changeCount)
    }

    private func resumeBurstWaiting() {
        guard captureSession == .burst else { return }
        beginWaiting(message: "Ready for next screenshot")
    }

    private func endSession(reason: String) {
        captureSession = .none
        isBurstSession = false
        waitingTimeoutTask?.cancel()
        burstTimeoutTask?.cancel()
        resultResetTask?.cancel()
        pipelineTask?.cancel()
        clipboardWatcher.stopMonitoring()
        eventLog.log(reason)
        transition(to: .idle)
    }

    private func scheduleSingleWaitingTimeout() {
        waitingTimeoutTask?.cancel()
        waitingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timeouts.waiting))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.state == .waiting, self.captureSession == .single else { return }
                self.endSession(reason: "Timed out — no screenshot in 10s")
            }
        }
    }

    private func scheduleBurstTimeout() {
        burstTimeoutTask?.cancel()
        burstTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timeouts.burst))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.captureSession == .burst else { return }
                self.endSession(reason: "1 Min session ended")
            }
        }
    }

    var statusLabel: String {
        if isBurstSession {
            switch state {
            case .waiting: return "Waiting for screenshot (1 min)"
            case .processing: return "Processing (1 min session)"
            default: return "\(state.label) (1 min session)"
            }
        }

        if state == .waiting {
            return "\(state.label) (\(currentPipelineMode.label))"
        }
        return state.label
    }

    private func transition(to newState: WorkflowState) {
        guard state != newState else { return }
        let previous = state
        state = newState
        eventLog.logStateTransition(from: previous, to: newState)
    }
}

enum LaunchAtLogin {
    static func isEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort; user can enable manually in System Settings.
        }
    }
}
