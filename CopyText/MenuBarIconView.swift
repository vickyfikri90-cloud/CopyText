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
        // Force monochrome rendering (monochrome checkmark instead of multicolor).
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(foregroundColor)
    }

    private var iconName: String {
        // Keep `idle` identical across modes.
        // Differentiate Extract JSON only during `waiting` / `processing`.
        if state != .idle, pipelineMode == .extractJSON {
            return "sparkles"
        }
        if state != .idle, pipelineMode == .extractJSONThird {
            return "square.grid.2x2"
        }
        return state.iconName
    }

    private var foregroundColor: Color {
        switch state {
        case .success:
            return Color(nsColor: .systemGreen)
        case .failure:
            return Color(nsColor: .systemOrange)
        case .idle, .waiting, .processing:
            return Color(nsColor: .labelColor)
        }
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
            } else {
                Image(nsImage: frames[frameIndex % frames.count])
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
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
