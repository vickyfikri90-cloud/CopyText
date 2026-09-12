import Foundation

/// Temporarily sets macOS screenshot target to clipboard while CopyText is waiting for a capture.
enum ScreenshotCaptureSettings {
    private static let domain = "com.apple.screencapture" as CFString
    private static let targetKey = "target" as CFString

    private static var savedTarget: String?
    private static var targetKeyExisted = false
    private static var isActive = false

    static var isOverrideActive: Bool { isActive }

    @discardableResult
    static func activateClipboardTarget() -> Bool {
        guard !isActive else { return false }
        isActive = true

        targetKeyExisted = CFPreferencesCopyAppValue(targetKey, domain) != nil
        savedTarget = readTarget()

        guard savedTarget != "clipboard" else { return false }

        writeTarget("clipboard")
        synchronizeAndApply()
        return true
    }

    @discardableResult
    static func restoreIfNeeded() -> Bool {
        guard isActive else { return false }

        let previous = savedTarget
        let keyExisted = targetKeyExisted
        isActive = false
        savedTarget = nil
        targetKeyExisted = false

        if previous == "clipboard" {
            return false
        }

        if keyExisted, let value = previous {
            writeTarget(value)
        } else if keyExisted {
            writeTarget("file")
        } else {
            CFPreferencesSetAppValue(targetKey, nil, domain)
        }
        synchronizeAndApply()
        return true
    }

    private static func readTarget() -> String? {
        CFPreferencesCopyAppValue(targetKey, domain) as? String
    }

    private static func writeTarget(_ value: String) {
        CFPreferencesSetAppValue(targetKey, value as CFString, domain)
    }

    private static func synchronizeAndApply() {
        CFPreferencesAppSynchronize(domain)
        restartSystemUIServer()
    }

    private static func restartSystemUIServer() {
        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["SystemUIServer"]
            try? process.run()
        }
    }
}
