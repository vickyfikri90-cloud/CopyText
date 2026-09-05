import Foundation

enum PipelineMode: String {
    case copyText
    case extractJSON
    case extractJSONThird

    var label: String {
        switch self {
        case .copyText: "CopyText"
        case .extractJSON: "Extract JSON"
        case .extractJSONThird: "Extract JSON (Third)"
        }
    }

    var waitingMessage: String {
        switch self {
        case .copyText: "Single-click — waiting for screenshot (local OCR)"
        case .extractJSON: "Double-click — waiting for screenshot (Gemini cloud)"
        case .extractJSONThird: "Third-click — waiting for screenshot (Gemini cloud)"
        }
    }
}
