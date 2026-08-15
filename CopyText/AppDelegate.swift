import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()
    private var statusBar: StatusBarController?
    private var devLogWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(controller: controller) { [weak self] in
            self?.showDevLog()
        }
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
}
