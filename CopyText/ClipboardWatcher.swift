import AppKit

struct ClipboardImagePayload {
    let image: NSImage
    let format: String
    let byteCount: Int
}

final class ClipboardWatcher {
    var onImageDetected: ((ClipboardImagePayload) -> Void)?
    var onChangeIgnored: ((Int, String) -> Void)?

    private var timer: Timer?
    private var baselineChangeCount = 0

    func startMonitoring(from changeCount: Int) {
        stopMonitoring()
        baselineChangeCount = changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != baselineChangeCount else { return }

        if let payload = Self.readImage(from: pasteboard) {
            stopMonitoring()
            onImageDetected?(payload)
        } else {
            onChangeIgnored?(currentCount, Self.describeClipboard(pasteboard))
        }
    }

    static func currentChangeCount() -> Int {
        NSPasteboard.general.changeCount
    }

    private static func readImage(from pasteboard: NSPasteboard) -> ClipboardImagePayload? {
        let types: [(NSPasteboard.PasteboardType, String)] = [
            (.png, "PNG"),
            (.tiff, "TIFF")
        ]

        for (type, label) in types {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data) {
                return ClipboardImagePayload(image: image, format: label, byteCount: data.count)
            }
        }
        return nil
    }

    private static func describeClipboard(_ pasteboard: NSPasteboard) -> String {
        let types = pasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "none"
        return "non-image clipboard (\(types))"
    }
}

enum ClipboardWriter {
    static func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
