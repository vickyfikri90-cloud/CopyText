import AppKit
import Foundation

enum GeminiClient {
    struct Result {
        let output: String
        let duration: TimeInterval
    }

    static func extractJSON(
        from image: NSImage,
        prompt: String,
        model: String,
        apiKey: String,
        fallbackAPIKeys: [String]
    ) async throws -> Result {
        let encoded = try ImageEncoder.encodePNG(from: image)
        let start = Date()

        // Try primary first; if rate-limited, retry once with fallback key.
        do {
            return try await attemptExtractJSON(
                from: image,
                prompt: prompt,
                model: model,
                encoded: encoded,
                apiKey: apiKey,
                start: start
            )
        } catch {
            guard shouldRetryWithFallback(error: error), !fallbackAPIKeys.isEmpty else {
                throw error
            }

            // Try each fallback key sequentially until one succeeds.
            var lastError: Error = error
            for fb in fallbackAPIKeys {
                do {
                    return try await attemptExtractJSON(
                        from: image,
                        prompt: prompt,
                        model: model,
                        encoded: encoded,
                        apiKey: fb,
                        start: start
                    )
                } catch {
                    lastError = error
                }
            }
            throw lastError
        }
        // Unreachable
        // return Result(output: "", duration: Date().timeIntervalSince(start))
    }

    static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private static func stripCodeFences(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            result = result.replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
            result = result.replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldRetryWithFallback(error: Error) -> Bool {
        // Retry on rate-limit or auth/quota-related HTTP errors.
        if case GeminiClientError.httpError(let code) = error {
            return code == 429 || code == 403 || code == 401
        }
        return false
    }

    private static func attemptExtractJSON(
        from image: NSImage,
        prompt: String,
        model: String,
        encoded: ImageEncoder.EncodedImage,
        apiKey: String,
        start: Date
    ) async throws -> Result {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GenerateContentRequest(
                contents: [
                    Content(parts: [
                        Part(text: prompt),
                        Part(inlineData: InlineData(mimeType: encoded.mimeType, data: encoded.base64))
                    ])
                ]
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                throw GeminiClientError.apiError(apiError.error.message)
            }
            throw GeminiClientError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw GeminiClientError.emptyResponse
        }

        return Result(output: stripCodeFences(from: text), duration: Date().timeIntervalSince(start))
    }
}

enum GeminiClientError: LocalizedError {
    case missingAPIKey
    case emptyResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Extract JSON requires a Gemini API key — open Settings."
        case .emptyResponse: "Gemini returned empty text."
        case .httpError(let code): "Gemini request failed (HTTP \(code))."
        case .apiError(let message): "Gemini error: \(message)"
        }
    }
}

private struct GenerateContentRequest: Encodable {
    let contents: [Content]
}

private struct Content: Encodable {
    let parts: [Part]
}

private struct Part: Encodable {
    let text: String?
    let inlineData: InlineData?

    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    init(inlineData: InlineData) {
        self.text = nil
        self.inlineData = inlineData
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct InlineData: Encodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]?
}

private struct Candidate: Decodable {
    let content: ContentResponse?
}

private struct ContentResponse: Decodable {
    let parts: [PartResponse]?
}

private struct PartResponse: Decodable {
    let text: String?
}

private struct GeminiErrorResponse: Decodable {
    let error: GeminiErrorBody
}

private struct GeminiErrorBody: Decodable {
    let message: String
}
