import SwiftUI

struct MenuBarIconView: View {
    let state: WorkflowState
    let pipelineMode: PipelineMode

    var body: some View {
        Group {
            if state == .processing {
                if pipelineMode == .extractJSON {
                    SVGSpinnerIcon(systemName: "sparkles")
                } else if pipelineMode == .extractJSONThird {
                    SVGSpinnerIcon(systemName: "square.grid.2x2")
                } else {
                    SVGSpinnerIcon(systemName: state.iconName)
                }
            } else {
                Image(systemName: iconName)
                    .imageScale(.medium)
            }
        }
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(Color(nsColor: .labelColor))
    }

    private var iconName: String {
        // Keep `idle` identical across modes.
        // Differentiate Extract JSON only during `waiting` / `processing`.
        // IMPORTANT: success/failure must always use the workflow state's icon
        // (e.g. checkmark/exclamation) and rely on monochrome rendering.
        if state == .waiting, pipelineMode == .extractJSON {
            return "sparkles"
        }
        if state == .waiting, pipelineMode == .extractJSONThird {
            return "square.grid.2x2"
        }
        return state.iconName
    }
}

private struct SVGSpinnerIcon: View {
    @State private var frameIndex = 0
    @State private var timer: Timer?

    private let frames = SpinnerFrames.images
    private let frameInterval: TimeInterval = 0.08
    private let fallbackSystemName: String

    init(systemName: String) {
        self.fallbackSystemName = systemName
    }

    var body: some View {
        Group {
            if frames.isEmpty {
                Image(systemName: fallbackSystemName)
                    .imageScale(.medium)
                    .symbolRenderingMode(.monochrome)
            } else {
                Image(nsImage: frames[frameIndex % frames.count])
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .onAppear { startLoop() }
        .onDisappear { stopLoop() }
    }

    private func startLoop() {
        guard !frames.isEmpty else { return }
        stopLoop()
        frameIndex = 0
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            frameIndex = (frameIndex + 1) % frames.count
        }
    }

    private func stopLoop() {
        timer?.invalidate()
        timer = nil
    }
}
