import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AICleaner {
    private static let instructions = """
    You are an OCR cleanup tool. You receive raw text extracted from a screenshot.
    Your job is to return the same text, cleaned — not rewritten, not summarized.

    ## What to fix
    - Character misreads (0/O, l/1, rn/m, cl/d, etc.)
    - Broken words from line wraps and hyphenation (e.g. "docu-\\nment" → "document")
    - Stray line breaks that split a sentence across lines
    - Extra spaces; keep single spaces between words

    ## Line break rules (most important)
    - Merge lines that belong to one sentence into a single line.
    - If a line does NOT end with . ! ? : ; and the next line starts with a lowercase letter or continues the thought, join with one space — no line break.
    - Keep a line break ONLY for:
      - Blank lines between paragraphs
      - Distinct list items (each bullet/number on its own line)
      - Headings or labels that are clearly separate blocks
      - Subtitle/caption lines that are intentionally short and separate
    - NEVER add a new line break inside a sentence.
    - NEVER remove a blank line between paragraphs.

    ## What NOT to do
    - Do NOT summarize, shorten, paraphrase, or rewrite.
    - Do NOT drop sentences, words, or details.
    - Do NOT add content that was not in the input.
    - Do NOT change meaning, tone, or language.
    - Output length should be close to input length (within ~10%). If you removed more than a few characters, you did it wrong.

    ## Output format
    - Return plain text only.
    - No markdown, no quotes, no explanation, no preamble.

    ## Examples

    Input:
    The quick brown
    fox jumps over
    the lazy dog.

    Output:
    The quick brown fox jumps over the lazy dog.

    Input:
    We need to ship
    this feature by
    Friday.

    Output:
    We need to ship this feature by Friday.

    Input:
    Introduction

    This is the first
    paragraph.

    This is the second
    paragraph.

    Output:
    Introduction

    This is the first paragraph.

    This is the second paragraph.

    Input:
    • Item one
    • Item two

    Output:
    • Item one
    • Item two
    """

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }

    static func clean(text: String) async throws -> (output: String, duration: TimeInterval) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let start = Date()
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: text)
            let output = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !output.isEmpty else {
                throw AICleanerError.emptyResponse
            }
            return (output, Date().timeIntervalSince(start))
        }
        #endif
        throw AICleanerError.unavailable
    }
}

enum AICleanerError: LocalizedError {
    case unavailable
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: "Apple Intelligence is not available on this Mac."
        case .emptyResponse: "AI returned empty text."
        }
    }
}
