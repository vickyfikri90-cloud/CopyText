import SwiftUI

struct ExtractJSONSettingsView: View {
    @ObservedObject var settings: GeminiSettings
    @State private var apiKeyInput = ""
    @State private var fallbackApiKeysInput = ""
    @State private var saveMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Extract JSON sends your screenshot to Google Gemini for cloud processing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("API Key") {
                SecureField("Paste Gemini API key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !settings.hasAPIKey)

                    if settings.hasAPIKey {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Fallback API Keys (optional)") {
                TextEditor(text: $fallbackApiKeysInput)
                    .frame(minHeight: 90, maxHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
                .accessibilityLabel("Fallback API Keys input")

                HStack {
                    Button("Save Fallbacks") { saveFallbackAPIKeys() }
                }

                if settings.fallbackAPIKeyCount > 0 {
                    Text("Saved \(settings.fallbackAPIKeyCount) key(s)")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Paste one key per line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                Picker("Gemini model", selection: $settings.selectedModel) {
                    ForEach(GeminiSettings.availableModels) { model in
                        Text(model.label).tag(model.id)
                    }
                }
            }

            Section("Prompt") {
                TextField("Prompt", text: $settings.prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            Section {
                Toggle("Enable third call mode", isOn: $settings.isThirdCallEnabled)
            }

            Section("Third call prompt") {
                TextField("Third call prompt", text: $settings.thirdPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }

            Section("Usage") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Single-click icon → CopyText (local OCR)", systemImage: "1.circle")
                    Label("Double-click icon → Extract JSON (cloud)", systemImage: "2.circle")
                    Label("While waiting: click once more → Third call", systemImage: "3.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 420)
        .onAppear {
            if let existing = settings.loadAPIKey() {
                apiKeyInput = existing
            }
            fallbackApiKeysInput = settings.loadFallbackAPIKeys().joined(separator: "\n")
        }
    }

    private func saveAPIKey() {
        do {
            try settings.saveAPIKey(apiKeyInput)
            saveMessage = settings.hasAPIKey ? "API key saved to Keychain." : "API key removed."
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private func saveFallbackAPIKeys() {
        do {
            let keys = fallbackApiKeysInput
                .split(whereSeparator: \.isNewline)
                .map { String($0) }
            try settings.saveFallbackAPIKeys(keys)
            saveMessage = settings.fallbackAPIKeyCount > 0 ? "Fallback keys saved to Keychain." : "Fallback keys removed."
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
