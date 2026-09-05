import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let controller: AppController
    private let openDevLog: () -> Void
    private let openExtractJSONSettings: () -> Void
    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<MenuBarIconView>?
    private var cancellables = Set<AnyCancellable>()
    private var lastClickTimestamp: TimeInterval = 0
    private var pendingSingleClick: DispatchWorkItem?
    private var pendingThirdClick: DispatchWorkItem?
    private var clickCountInWindow: Int = 0

    private enum ClickTiming {
        static let doubleClickWindow: TimeInterval = 0.35
    }

    init(
        controller: AppController,
        openDevLog: @escaping () -> Void,
        openExtractJSONSettings: @escaping () -> Void
    ) {
        self.controller = controller
        self.openDevLog = openDevLog
        self.openExtractJSONSettings = openExtractJSONSettings
        super.init()
        setupStatusItem()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        let hosting = NSHostingView(rootView: MenuBarIconView(state: controller.state, pipelineMode: controller.currentPipelineMode))
        hosting.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hosting.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hosting.widthAnchor.constraint(equalToConstant: 22),
            hosting.heightAnchor.constraint(equalToConstant: 22)
        ])
        hostingView = hosting

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observeState() {
        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.hostingView?.rootView = MenuBarIconView(state: state, pipelineMode: self.controller.currentPipelineMode)
            }
            .store(in: &cancellables)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu(on: sender)
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        // Only treat as a double-click if we already have a previous click timestamp.
        // This avoids mis-detecting the very first click right after app launch.
        if lastClickTimestamp > 0, now - lastClickTimestamp < ClickTiming.doubleClickWindow {
            pendingSingleClick?.cancel()
            pendingSingleClick = nil
            lastClickTimestamp = 0
            clickCountInWindow = min(clickCountInWindow + 1, 3)

            // 2nd click => extractJSON
            if clickCountInWindow == 2 {
                controller.handleIconClick(mode: .extractJSON)
            }
            // 3rd click => optional extractJSONThird
            if clickCountInWindow == 3 {
                if controller.geminiSettings.isThirdCallEnabled {
                    controller.handleIconClick(mode: .extractJSONThird)
                } else {
                    controller.handleIconClick(mode: .extractJSON)
                }
            }

            // Reset after handling 2nd or 3rd click immediately.
            clickCountInWindow = 0
            lastClickTimestamp = 0
            return
        }

        lastClickTimestamp = now
        clickCountInWindow = 1
        let clickTime = now
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.lastClickTimestamp == clickTime else { return }
            self.lastClickTimestamp = 0
            let mode: PipelineMode = .copyText
            self.controller.handleIconClick(mode: mode)
            self.clickCountInWindow = 0
        }
        pendingSingleClick = task
        DispatchQueue.main.asyncAfter(deadline: .now() + ClickTiming.doubleClickWindow, execute: task)
    }

    private func showMenu(on button: NSStatusBarButton) {
        let menu = NSMenu()

        let burstItem = NSMenuItem(
            title: "Start for 1 Min",
            action: #selector(startForOneMinute),
            keyEquivalent: ""
        )
        burstItem.target = self
        burstItem.isEnabled = controller.state.canStart
        menu.addItem(burstItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Extract JSON Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let devItem = NSMenuItem(
            title: "Dev Mode",
            action: #selector(toggleDevMode),
            keyEquivalent: ""
        )
        devItem.target = self
        devItem.state = controller.devModeEnabled ? .on : .off
        menu.addItem(devItem)

        if controller.devModeEnabled {
            let logItem = NSMenuItem(title: "Show Log", action: #selector(showLog), keyEquivalent: "")
            logItem.target = self
            menu.addItem(logItem)
        }

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = controller.launchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let hintItem = NSMenuItem(
            title: "Single-click: CopyText · Double-click: Extract JSON",
            action: nil,
            keyEquivalent: ""
        )
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        let statusItem = NSMenuItem(title: "Status: \(controller.statusLabel)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let buildItem = NSMenuItem(title: "Last update: \(BuildInfo.compiledAt)", action: nil, keyEquivalent: "")
        buildItem.isEnabled = false
        menu.addItem(buildItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit CopyText", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func startForOneMinute() {
        controller.startForOneMinute()
    }

    @objc private func openSettings() {
        openExtractJSONSettings()
    }

    @objc private func toggleDevMode() {
        controller.toggleDevMode()
    }

    @objc private func toggleLaunchAtLogin() {
        controller.toggleLaunchAtLogin()
    }

    @objc private func showLog() {
        openDevLog()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
