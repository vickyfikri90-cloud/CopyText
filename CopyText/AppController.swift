import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var state: WorkflowState = .idle
    @Published private(set) var isBurstSession = false
    @Published var aiModeEnabled: Bool {
        didSet { UserDefaults.standard.set(aiModeEnabled, forKey: Keys.aiMode) }
    }
    @Published var devModeEnabled: Bool {
        didSet { UserDefaults.standard.set(devModeEnabled, forKey: Keys.devMode) }
    }
    @Published var launchAtLoginEnabled: Bool {
        didSet { LaunchAtLogin.setEnabled(launchAtLoginEnabled) }
    }

    let eventLog = EventLog()
    let aiModeAvailable: Bool

    private let clipboardWatcher = ClipboardWatcher()
    private var resultResetTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    private var waitingTimeoutTask: Task<Void, Never>?
    private var burstTimeoutTask: Task<Void, Never>?

    private enum CaptureSession {
        case none
        case single
        case burst
    }

    private var captureSession: CaptureSession = .none

    private enum Keys {
        static let aiMode = "aiModeEnabled"
        static let devMode = "devModeEnabled"
    }

    private enum Timeouts {
        static let waiting: TimeInterval = 10
        static let burst: TimeInterval = 60
        static let burstResultFlash: TimeInterval = 0.8
    }

    init() {
        aiModeEnabled = UserDefaults.standard.bool(forKey: Keys.aiMode)
        devModeEnabled = UserDefaults.standard.bool(forKey: Keys.devMode)
        launchAtLoginEnabled = LaunchAtLogin.isEnabled()
        aiModeAvailable = AICleaner.isAvailable

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
        eventLog.log("AI Mode available: \(aiModeAvailable)")
    }

    func toggleFromIconClick() {
        switch state {
        case .idle:
            start()
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

    func start() {
        guard state.canStart else {
            eventLog.log("Start ignored — state is \(state.label)")
            return
        }

        captureSession = .single
        beginWaiting(message: "Icon clicked — waiting for screenshot")
        scheduleSingleWaitingTimeout()
    }

    func startForOneMinute() {
        guard state.canStart else {
            eventLog.log("Start for 1 Min ignored — state is \(state.label)")
            return
        }

        captureSession = .burst
        isBurstSession = true
        beginWaiting(message: "Start for 1 Min — waiting for screenshots")
        scheduleBurstTimeout()
    }

    func cancel(reason: String = "Cancel clicked") {
        guard state.canCancel || isBurstSession else { return }
        endSession(reason: reason)
    }

    func toggleAIMode() {
        guard aiModeAvailable else { return }
        aiModeEnabled.toggle()
        eventLog.log("AI Mode \(aiModeEnabled ? "enabled" : "disabled")")
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
            eventLog.log("OCR started")
            let ocrResult = try await OCRService.extractText(from: payload.image)
            eventLog.log(String(format: "OCR finished — %.2fs, confidence=%.2f",
                                ocrResult.duration, ocrResult.averageConfidence))
            eventLog.logText("OCR raw", ocrResult.text)

            var finalText = TextNormalizer.normalize(ocrResult.text)
            eventLog.logText("After line-break normalize", finalText)

            if aiModeEnabled && aiModeAvailable {
                let preAIText = finalText
                eventLog.log("AI cleanup started")
                do {
                    let aiResult = try await AICleaner.clean(text: finalText)
                    eventLog.logText("AI raw output", aiResult.output)
                    let aiNormalized = TextNormalizer.normalize(aiResult.output)
                    let minimumLength = Int(Double(preAIText.count) * 0.85)

                    if aiNormalized.count < minimumLength {
                        eventLog.log("AI output too short — using normalized OCR")
                        eventLog.logText("AI rejected, kept", preAIText)
                    } else {
                        finalText = aiNormalized
                        eventLog.log(String(format: "AI cleanup finished — %.2fs", aiResult.duration))
                        eventLog.logText("After AI normalize", finalText)
                    }
                } catch {
                    eventLog.log("AI cleanup failed — using normalized OCR: \(error.localizedDescription)")
                }
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
