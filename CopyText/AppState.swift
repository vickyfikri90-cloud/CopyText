import Foundation

enum WorkflowState: Equatable {
    case idle
    case waiting
    case processing
    case success
    case failure

    var label: String {
        switch self {
        case .idle: "Idle"
        case .waiting: "Waiting for screenshot"
        case .processing: "Processing"
        case .success: "Success"
        case .failure: "Failure"
        }
    }

    var iconName: String {
        switch self {
        case .idle: "circle.hexagongrid.circle.fill"
        case .waiting: "viewfinder"
        case .processing: "circle.hexagonpath.fill"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var canStart: Bool {
        self == .idle
    }

    var canCancel: Bool {
        self == .waiting
    }
}
