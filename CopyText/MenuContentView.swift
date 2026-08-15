import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Start") {
                controller.start()
            }
            .disabled(!controller.state.canStart)

            if controller.state.canCancel {
                Button("Cancel") {
                    controller.cancel()
                }
            }

            Divider()

            if controller.aiModeAvailable {
                Toggle("AI Mode", isOn: Binding(
                    get: { controller.aiModeEnabled },
                    set: { _ in controller.toggleAIMode() }
                ))
            }

            Toggle("Dev Mode", isOn: Binding(
                get: { controller.devModeEnabled },
                set: { _ in controller.toggleDevMode() }
            ))

            if controller.devModeEnabled {
                Button("Show Log") {
                    openWindow(id: "dev-log")
                }
            }

            Toggle("Launch at Login", isOn: Binding(
                get: { controller.launchAtLoginEnabled },
                set: { _ in controller.toggleLaunchAtLogin() }
            ))

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text(statusLine)
                Text("Last update: \(BuildInfo.compiledAt)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            Button("Quit CopyText") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var statusLine: String {
        "Status: \(controller.state.label)"
    }
}
