import Foundation

/// Local file storage for API keys — avoids Keychain prompts on ad-hoc rebuilds.
enum APIKeysFileStore {
    private static let subdirectory = "CopyText"
    private static let fileName = "gemini-api-keys.json"
    private static let migratedKey = "geminiAPIKeysUseFileStorage"

    static var usesFileStorage: Bool {
        UserDefaults.standard.bool(forKey: migratedKey)
    }

    static func markUsingFileStorage() {
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    static func load() -> Data? {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func save(_ data: Data) throws {
        let directory = fileURL().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = fileURL()
        try data.write(to: url, options: [.atomic])

        var attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        attributes[.posixPermissions] = 0o600
        try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }

    static func delete() throws {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
