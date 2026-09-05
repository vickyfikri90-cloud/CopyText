import Foundation

enum PipelineMode: String {
    case copyText
    case extractJSON

    var label: String {
        switch self {
        case .copyText: "CopyText"
        case .extractJSON: "Extract JSON"
        }
    }

    var waitingMessage: String {
        switch self {
        case .copyText: "Single-click — waiting for screenshot (local OCR)"
        case .extractJSON: "Double-click — waiting for screenshot (Gemini cloud)"
        }
    }
}
