import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()
    private var statusBar: StatusBarController?
    private var devLogWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(
            controller: controller,
            openDevLog: { [weak self] in self?.showDevLog() },
            openExtractJSONSettings: { [weak self] in self?.showExtractJSONSettings() }
        )
    }

    func showDevLog() {
        if devLogWindow == nil {
            let hosting = NSHostingController(rootView: DevLogWindow(eventLog: controller.eventLog))
            let window = NSWindow(contentViewController: hosting)
            window.title = "CopyText Log"
            window.setContentSize(NSSize(width: 520, height: 400))
            window.center()
            devLogWindow = window
        }
        devLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showExtractJSONSettings() {
        settingsWindow?.close()
        settingsWindow = nil

        let hosting = NSHostingController(
            rootView: ExtractJSONSettingsView(settings: controller.geminiSettings)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Extract JSON Settings"
        window.setContentSize(NSSize(width: 480, height: 540))
        window.center()
        settingsWindow = window

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
