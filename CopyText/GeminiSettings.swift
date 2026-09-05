import Combine
import Foundation

struct GeminiModelOption: Identifiable, Hashable {
    let id: String
    let label: String
}

@MainActor
final class GeminiSettings: ObservableObject {
    static let apiKeyAccount = "gemini-api-key"
    static let fallbackAPIKeyAccount = "gemini-api-key-fallback"
    static let defaultPrompt = "Extract the data in json format"
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

    @Published private(set) var hasAPIKey: Bool = false
    @Published private(set) var hasFallbackAPIKey: Bool = false

    private enum Keys {
        static let model = "geminiSelectedModel"
        static let prompt = "geminiPrompt"
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
        refreshAPIKeyStatus()
    }

    func refreshAPIKeyStatus() {
        hasAPIKey = KeychainStore.load(account: Self.apiKeyAccount) != nil
        hasFallbackAPIKey = KeychainStore.load(account: Self.fallbackAPIKeyAccount) != nil
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

    func saveFallbackAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try KeychainStore.delete(account: Self.fallbackAPIKeyAccount)
            refreshAPIKeyStatus()
            return
        }
        try KeychainStore.save(account: Self.fallbackAPIKeyAccount, value: trimmed)
        refreshAPIKeyStatus()
    }

    func loadAPIKey() -> String? {
        KeychainStore.load(account: Self.apiKeyAccount)
    }

    func loadFallbackAPIKey() -> String? {
        KeychainStore.load(account: Self.fallbackAPIKeyAccount)
    }
}
