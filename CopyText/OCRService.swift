import AppKit
import Vision

struct OCRResult {
    let text: String
    let characterCount: Int
    let averageConfidence: Float
    let duration: TimeInterval
}

enum OCRError: LocalizedError {
    case invalidImage
    case noText
    case visionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not read image from clipboard."
        case .noText: "No text found in screenshot."
        case .visionFailed(let message): "OCR failed: \(message)"
        }
    }
}

enum OCRService {
    private static let lineYThreshold: CGFloat = 0.02

    static func extractText(from image: NSImage) async throws -> OCRResult {
        let start = Date()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let observations: [VNRecognizedTextObservation] = try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                continuation.resume(returning: request.results ?? [])
            } catch {
                continuation.resume(throwing: OCRError.visionFailed(error.localizedDescription))
            }
        }

        guard !observations.isEmpty else {
            throw OCRError.noText
        }

        let sorted = observations.sorted { lhs, rhs in
            let lBox = lhs.boundingBox
            let rBox = rhs.boundingBox
            if abs(lBox.midY - rBox.midY) > lineYThreshold {
                return lBox.midY > rBox.midY
            }
            return lBox.minX < rBox.minX
        }

        let visualLines = groupIntoVisualLines(sorted)
        var confidences: [Float] = []

        let lines: [String] = visualLines.compactMap { group in
            let parts = group.compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                confidences.append(candidate.confidence)
                return candidate.string
            }
            let line = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return line.isEmpty ? nil : line
        }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OCRError.noText }

        let averageConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
        let duration = Date().timeIntervalSince(start)

        return OCRResult(
            text: text,
            characterCount: text.count,
            averageConfidence: averageConfidence,
            duration: duration
        )
    }

    /// Joins Vision observations that sit on the same visual row before line-break normalization.
    private static func groupIntoVisualLines(_ observations: [VNRecognizedTextObservation]) -> [[VNRecognizedTextObservation]] {
        var groups: [[VNRecognizedTextObservation]] = []
        var current: [VNRecognizedTextObservation] = []

        for observation in observations {
            if let last = current.last,
               abs(last.boundingBox.midY - observation.boundingBox.midY) > lineYThreshold {
                groups.append(current)
                current = [observation]
            } else {
                current.append(observation)
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return groups
    }
}
