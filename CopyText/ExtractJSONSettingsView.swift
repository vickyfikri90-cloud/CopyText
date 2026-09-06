import SwiftUI

private enum ExtractJSONSettingsCopy {
    static let geminiAPIKeysURL = URL(string: "https://aistudio.google.com/u/1/api-keys")!
    static let fallbackKeysHelp = "Extra API keys used in rotation. Each request starts with the next key; if it fails, the app tries the rest."
    static let thirdCallHelp = "Double-click to start Extract JSON, then click once more while waiting to switch to a separate prompt."
}

struct ExtractJSONSettingsView: View {
    @ObservedObject var settings: GeminiSettings
    @State private var apiKeyDraft = ""
    @State private var fallbackDraft = ""
    @State private var showFallbackEditor = false

    var body: some View {
        Form {
            apiKeySection
            fallbackSection
            modelSection
            promptSection
            thirdCallSection
            if settings.isThirdCallEnabled {
                thirdCallPromptSection
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 540)
        .onAppear(perform: loadDrafts)
    }

    // MARK: - Sections

    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paste Gemini API key")
                    .foregroundStyle(.secondary)
                SecureField("", text: $apiKeyDraft)
            }

            HStack {
                Button(isAPIKeySaved ? "Saved" : "Save Key") {
                    saveAPIKey()
                }
                .buttonStyle(.bordered)
                .disabled(trimmedAPIKey.isEmpty || isAPIKeySaved)

                Spacer()

                Link("Get my API", destination: ExtractJSONSettingsCopy.geminiAPIKeysURL)
            }
        } header: {
            Text("API Key")
        }
    }

    private var fallbackSection: some View {
        Section {
            HStack(spacing: 4) {
                Text("Fallback API Keys")
                    .font(.headline)
                SettingsHelpIcon(text: ExtractJSONSettingsCopy.fallbackKeysHelp)
                Spacer()
            }

            if showFallbackEditor {
                TextEditor(text: $fallbackDraft)
                    .frame(minHeight: 80, maxHeight: 140)

                Text("Paste one key per line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(isFallbackSaved ? "Saved" : "Save Fallbacks") {
                    saveFallbackKeys()
                }
                .buttonStyle(.bordered)
                .disabled(trimmedFallback.isEmpty || isFallbackSaved)
            } else {
                Button("+ Add fallback keys") {
                    showFallbackEditor = true
                }
                .buttonStyle(.link)
            }
        }
    }

    private var modelSection: some View {
        Section {
            Picker("", selection: $settings.selectedModel) {
                ForEach(GeminiSettings.availableModels) { model in
                    Text(model.label).tag(model.id)
                }
            }
            .labelsHidden()
        } header: {
            Text("Model")
        }
    }

    private var promptSection: some View {
        Section {
            TextEditor(text: $settings.prompt)
                .frame(minHeight: 80, maxHeight: 120)
        } header: {
            Text("Prompt")
        }
    }

    private var thirdCallSection: some View {
        Section {
            HStack {
                HStack(spacing: 4) {
                    Text("Enable third call mode")
                    SettingsHelpIcon(text: ExtractJSONSettingsCopy.thirdCallHelp)
                }
                Spacer()
                Toggle("", isOn: $settings.isThirdCallEnabled)
                    .labelsHidden()
            }
        }
    }

    private var thirdCallPromptSection: some View {
        Section {
            TextEditor(text: $settings.thirdPrompt)
                .frame(minHeight: 80, maxHeight: 120)
        } header: {
            Text("Third call prompt")
        }
    }

    // MARK: - State

    private var trimmedAPIKey: String {
        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedFallback: String {
        fallbackDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAPIKeySaved: Bool {
        let saved = settings.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmedAPIKey.isEmpty && trimmedAPIKey == saved
    }

    private var isFallbackSaved: Bool {
        let saved = settings.loadFallbackAPIKeys().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFallback == saved
    }

    private func loadDrafts() {
        apiKeyDraft = settings.loadAPIKey() ?? ""
        fallbackDraft = settings.loadFallbackAPIKeys().joined(separator: "\n")
        showFallbackEditor = settings.fallbackAPIKeyCount > 0
    }

    private func saveAPIKey() {
        try? settings.saveAPIKey(apiKeyDraft)
    }

    private func saveFallbackKeys() {
        let keys = fallbackDraft
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
        try? settings.saveFallbackAPIKeys(keys)
    }
}

// MARK: - Help icon (hover tooltip + click popover fallback)

private struct SettingsHelpIcon: View {
    let text: String
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .onHover { showHelp = $0 }
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(12)
        }
    }
}

#Preview {
    ExtractJSONSettingsView(settings: GeminiSettings())
}
