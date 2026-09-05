import Combine
import Foundation

struct GeminiModelOption: Identifiable, Hashable {
    let id: String
    let label: String
}

@MainActor
final class GeminiSettings: ObservableObject {
    static let apiKeyAccount = "gemini-api-key"
    static let fallbackAPIKeyAccountPrefix = "gemini-api-key-fallback-"
    static let fallbackCountKey = "geminiFallbackCount"
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

    private enum Keys {
        static let model = "geminiSelectedModel"
        static let prompt = "geminiPrompt"
        static let thirdPrompt = "geminiThirdPrompt"
        static let thirdCallEnabled = "geminiThirdCallEnabled"
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
        refreshAPIKeyStatus()
    }

    func refreshAPIKeyStatus() {
        hasAPIKey = KeychainStore.load(account: Self.apiKeyAccount) != nil
        fallbackAPIKeyCount = loadFallbackAPIKeys().count
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try KeychainStore.delete(account: Self.apiKeyAccount)
            refreshAPIKeyStatus()
            return
        }
        try KeychainStore.save(account: Self.apiKeyAccount, value: trimmed)
        refreshAPIKeyStatus()
    }

    func loadAPIKey() -> String? {
        KeychainStore.load(account: Self.apiKeyAccount)
    }

    func loadFallbackAPIKeys() -> [String] {
        let count = UserDefaults.standard.integer(forKey: Self.fallbackCountKey)
        guard count > 0 else { return [] }
        var keys: [String] = []
        keys.reserveCapacity(count)
        for idx in 1...count {
            let account = Self.fallbackAPIKeyAccountPrefix + "\(idx)"
            if let key = KeychainStore.load(account: account),
               !key.isEmpty {
                keys.append(key)
            }
        }
        return keys
    }

    /// Replace all fallback keys with the provided list.
    func saveFallbackAPIKeys(_ keys: [String]) throws {
        // Delete old keys (best-effort).
        let oldCount = UserDefaults.standard.integer(forKey: Self.fallbackCountKey)
        if oldCount > 0 {
            for idx in 1...oldCount {
                let account = Self.fallbackAPIKeyAccountPrefix + "\(idx)"
                try? KeychainStore.delete(account: account)
            }
        }

        // Save new keys.
        var cleaned: [String] = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        cleaned = Array(cleaned.prefix(30)) // hard cap to prevent abuse

        if cleaned.isEmpty {
            UserDefaults.standard.set(0, forKey: Self.fallbackCountKey)
            refreshAPIKeyStatus()
            return
        }

        for (offset, key) in cleaned.enumerated() {
            let idx = offset + 1
            let account = Self.fallbackAPIKeyAccountPrefix + "\(idx)"
            try KeychainStore.save(account: account, value: key)
        }

        UserDefaults.standard.set(cleaned.count, forKey: Self.fallbackCountKey)
        refreshAPIKeyStatus()
    }
}
