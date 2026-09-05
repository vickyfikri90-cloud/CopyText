import SwiftUI

struct MenuBarIconView: View {
    let state: WorkflowState
    let pipelineMode: PipelineMode

    var body: some View {
        Group {
            if state == .processing {
                if pipelineMode == .extractJSON {
                    SVGSpinnerIcon(systemName: "sparkles")
                } else {
                    SVGSpinnerIcon(systemName: state.iconName)
                }
            } else {
                Image(systemName: iconName)
                    .imageScale(.medium)
            }
        }
        .symbolRenderingMode(state == .success ? .multicolor : .monochrome)
        .foregroundStyle(foregroundColor)
    }

    private var iconName: String {
        // Use conservative SF Symbol IDs to avoid "no-image" rendering.
        if pipelineMode == .extractJSON {
            return "sparkles"
        }
        return state.iconName
    }

    private var foregroundColor: Color {
        switch state {
        case .success: .green
        case .failure: .orange
        case .idle, .waiting, .processing: Color(nsColor: .labelColor)
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
