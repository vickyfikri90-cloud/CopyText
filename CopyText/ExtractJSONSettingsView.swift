import SwiftUI

struct ExtractJSONSettingsView: View {
    @ObservedObject var settings: GeminiSettings
    @State private var apiKeyInput = ""
    @State private var fallbackApiKeyInput = ""
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

            Section("Fallback API Key (optional)") {
                SecureField("Paste Gemini fallback API key", text: $fallbackApiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Fallback") {
                        saveFallbackAPIKey()
                    }
                    .disabled(fallbackApiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !settings.hasFallbackAPIKey)

                    if settings.hasFallbackAPIKey {
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

            Section("Usage") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Single-click icon → CopyText (local OCR)", systemImage: "1.circle")
                    Label("Double-click icon → Extract JSON (cloud)", systemImage: "2.circle")
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
            if let existing = settings.loadFallbackAPIKey() {
                fallbackApiKeyInput = existing
            }
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

    private func saveFallbackAPIKey() {
        do {
            try settings.saveFallbackAPIKey(fallbackApiKeyInput)
            saveMessage = settings.hasFallbackAPIKey ? "Fallback key saved to Keychain." : "Fallback key removed."
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
