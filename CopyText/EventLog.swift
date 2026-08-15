import Foundation
import os

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String

    var formattedLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] \(message)"
    }
}

@MainActor
final class EventLog: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let logger = Logger(subsystem: "com.vicky.copytext", category: "events")
    private let fileURL: URL
    private let maxFileBytes = 512_000

    init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/CopyText", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        fileURL = logsDir.appendingPathComponent("copytext.log")
    }

    func log(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        entries.append(entry)
        logger.info("\(message, privacy: .public)")
        appendToFile(entry.formattedLine)
    }

    func logStateTransition(from: WorkflowState, to: WorkflowState) {
        log("State: \(from.label) → \(to.label)")
    }

    func logText(_ label: String, _ text: String) {
        let body = text.isEmpty ? "(empty)" : text
        log("--- \(label) ---\n\(body)\n--- end ---")
    }

    func clear() {
        entries.removeAll()
        log("Log cleared")
    }

    var allText: String {
        entries.map(\.formattedLine).joined(separator: "\n")
    }

    private func appendToFile(_ line: String) {
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: fileURL)
        }
        rotateIfNeeded()
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int,
              size > maxFileBytes else { return }

        let rotated = fileURL.deletingPathExtension().appendingPathExtension("old.log")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: fileURL, to: rotated)
    }
}
