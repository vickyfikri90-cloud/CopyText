import Combine
import Foundation

struct GeminiModelOption: Identifiable, Hashable {
    let id: String
    let label: String
}

private struct StoredAPIKeys: Codable, Equatable {
    var primary: String?
    var fallbacks: [String]
}

@MainActor
final class GeminiSettings: ObservableObject {
    private static let apiKeysBundleAccount = "gemini-api-keys"
    private static let legacyPrimaryAccount = "gemini-api-key"
    private static let legacyFallbackAccountPrefix = "gemini-api-key-fallback-"
    private static let legacyFallbackCountKey = "geminiFallbackCount"

    static let defaultPrompt = "Extract the data in json format"
    static let defaultThirdPrompt = "Extract the data in json format (third call)"
    static let defaultModelID = "gemini-3.5-flash-lite"

    static let availableModels: [GeminiModelOption] = [
        GeminiModelOption(id: "gemini-3.5-flash-lite", label: "Gemini 3.5 Flash Lite"),
        GeminiModelOption(id: "gemini-3.5-flash", label: "Gemini 3.5 Flash"),
        GeminiModelOption(id: "gemini-3.6-flash", label: "Gemini 3.6 Flash"),
        GeminiModelOption(id: "gemini-3.7-flash", label: "Gemini 3.7 Flash"),
        GeminiModelOption(id: "gemini-3.8-flash", label: "Gemini 3.8 Flash"),
        GeminiModelOption(id: "gemini-3.1-flash-lite", label: "Gemini 3.1 Flash Lite"),
        GeminiModelOption(id: "gemini-flash-latest", label: "Gemini Flash Latest (auto)")
    ]

    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: Keys.model) }
    }

    @Published var prompt: String {
        didSet { UserDefaults.standard.set(prompt, forKey: Keys.prompt) }
    }

    @Published var thirdPrompt: String {
        didSet { UserDefaults.standard.set(thirdPrompt, forKey: Keys.thirdPrompt) }
    }

    @Published var isThirdCallEnabled: Bool {
        didSet { UserDefaults.standard.set(isThirdCallEnabled, forKey: Keys.thirdCallEnabled) }
    }

    @Published private(set) var hasAPIKey: Bool = false
    @Published private(set) var fallbackAPIKeyCount: Int = 0

    private var cachedAPIKeys: StoredAPIKeys?
    private var didLoadAPIKeys = false

    private enum Keys {
        static let model = "geminiSelectedModel"
        static let prompt = "geminiPrompt"
        static let thirdPrompt = "geminiThirdPrompt"
        static let thirdCallEnabled = "geminiThirdCallEnabled"
        static let lastUsedAPIKeyIndex = "geminiLastUsedAPIKeyIndex"
        static let lastUsedAPIKeyPoolCount = "geminiLastUsedAPIKeyPoolCount"
    }

    init() {
        let savedModel = UserDefaults.standard.string(forKey: Keys.model)
        if let savedModel, Self.availableModels.contains(where: { $0.id == savedModel }) {
            selectedModel = savedModel
        } else {
            selectedModel = Self.defaultModelID
        }

        prompt = UserDefaults.standard.string(forKey: Keys.prompt)
            ?? Self.defaultPrompt

        thirdPrompt = UserDefaults.standard.string(forKey: Keys.thirdPrompt)
            ?? Self.defaultThirdPrompt

        isThirdCallEnabled = UserDefaults.standard.bool(forKey: Keys.thirdCallEnabled)
        _ = storedAPIKeys()
        refreshAPIKeyStatus()
    }

    func refreshAPIKeyStatus() {
        let stored = storedAPIKeys()
        hasAPIKey = stored.primary.map { !$0.isEmpty } ?? false
        fallbackAPIKeyCount = stored.fallbacks.count
    }

    func saveAPIKey(_ key: String) throws {
        var stored = storedAPIKeys()
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        stored.primary = trimmed.isEmpty ? nil : trimmed
        try persist(stored)
    }

    func loadAPIKey() -> String? {
        storedAPIKeys().primary
    }

    func loadFallbackAPIKeys() -> [String] {
        storedAPIKeys().fallbacks
    }

    /// Primary key first, then fallback keys — the rolling pool.
    func allAPIKeys() -> [String] {
        let stored = storedAPIKeys()
        var keys: [String] = []
        if let primary = stored.primary?.trimmingCharacters(in: .whitespacesAndNewlines), !primary.isEmpty {
            keys.append(primary)
        }
        keys.append(contentsOf: stored.fallbacks)
        return keys
    }

    /// Index of the next key to try (round-robin). Resets when the pool size changes.
    func indexForNextRequest() -> Int {
        let keys = allAPIKeys()
        guard !keys.isEmpty else { return 0 }

        let savedCount = UserDefaults.standard.integer(forKey: Keys.lastUsedAPIKeyPoolCount)
        if savedCount != keys.count {
            return 0
        }

        guard UserDefaults.standard.object(forKey: Keys.lastUsedAPIKeyIndex) != nil else {
            return 0
        }

        let lastUsed = UserDefaults.standard.integer(forKey: Keys.lastUsedAPIKeyIndex)
        return (lastUsed + 1) % keys.count
    }

    func markAPIKeyUsed(at index: Int) {
        let keys = allAPIKeys()
        guard !keys.isEmpty else { return }
        let clamped = ((index % keys.count) + keys.count) % keys.count
        UserDefaults.standard.set(clamped, forKey: Keys.lastUsedAPIKeyIndex)
        UserDefaults.standard.set(keys.count, forKey: Keys.lastUsedAPIKeyPoolCount)
    }

    /// Replace all fallback keys with the provided list.
    func saveFallbackAPIKeys(_ keys: [String]) throws {
        var stored = storedAPIKeys()
        var cleaned = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        cleaned = Array(cleaned.prefix(30))
        stored.fallbacks = cleaned
        try persist(stored)
    }

    // MARK: - Storage (file + one-time Keychain migration)

    private func storedAPIKeys() -> StoredAPIKeys {
        if didLoadAPIKeys, let cachedAPIKeys {
            return cachedAPIKeys
        }

        let stored: StoredAPIKeys
        if APIKeysFileStore.usesFileStorage {
            stored = decodeStoredAPIKeys(from: APIKeysFileStore.load()) ?? StoredAPIKeys(primary: nil, fallbacks: [])
        } else {
            stored = migrateFromKeychainIfNeeded()
        }

        cachedAPIKeys = stored
        didLoadAPIKeys = true
        return stored
    }

    private func persist(_ stored: StoredAPIKeys) throws {
        if stored.primary == nil, stored.fallbacks.isEmpty {
            try APIKeysFileStore.delete()
        } else {
            let data = try JSONEncoder().encode(stored)
            try APIKeysFileStore.save(data)
        }

        APIKeysFileStore.markUsingFileStorage()
        purgeKeychainCopies()

        cachedAPIKeys = stored
        didLoadAPIKeys = true
        refreshAPIKeyStatus()
    }

    private func migrateFromKeychainIfNeeded() -> StoredAPIKeys {
        if let bundleRaw = KeychainStore.load(account: Self.apiKeysBundleAccount),
           let stored = decodeStoredAPIKeys(from: bundleRaw.data(using: .utf8)) {
            writeToFileAndFinishMigration(stored)
            return stored
        }

        var primary = KeychainStore.load(account: Self.legacyPrimaryAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if primary?.isEmpty == true { primary = nil }

        var fallbacks: [String] = []
        let legacyCount = UserDefaults.standard.integer(forKey: Self.legacyFallbackCountKey)
        if legacyCount > 0 {
            for idx in 1...legacyCount {
                let account = Self.legacyFallbackAccountPrefix + "\(idx)"
                if let key = KeychainStore.load(account: account)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !key.isEmpty {
                    fallbacks.append(key)
                }
            }
        }

        let stored = StoredAPIKeys(primary: primary, fallbacks: fallbacks)
        writeToFileAndFinishMigration(stored)
        return stored
    }

    private func writeToFileAndFinishMigration(_ stored: StoredAPIKeys) {
        if stored.primary != nil || !stored.fallbacks.isEmpty,
           let data = try? JSONEncoder().encode(stored) {
            try? APIKeysFileStore.save(data)
        }
        APIKeysFileStore.markUsingFileStorage()
        purgeKeychainCopies()
    }

    private func purgeKeychainCopies() {
        try? KeychainStore.delete(account: Self.apiKeysBundleAccount)
        try? KeychainStore.delete(account: Self.legacyPrimaryAccount)

        let legacyCount = UserDefaults.standard.integer(forKey: Self.legacyFallbackCountKey)
        if legacyCount > 0 {
            for idx in 1...legacyCount {
                let account = Self.legacyFallbackAccountPrefix + "\(idx)"
                try? KeychainStore.delete(account: account)
            }
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyFallbackCountKey)
    }

    private func decodeStoredAPIKeys(from data: Data?) -> StoredAPIKeys? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(StoredAPIKeys.self, from: data)
    }
}

enum GeminiSettingsError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "Failed to encode API keys for storage."
        }
    }
}
