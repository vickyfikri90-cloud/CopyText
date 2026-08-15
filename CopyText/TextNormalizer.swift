import Foundation

enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var output: [String] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            output.append(mergeLines(in: paragraphLines))
            paragraphLines = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                if output.last != "" {
                    output.append("")
                }
            } else {
                paragraphLines.append(trimmed)
            }
        }

        flushParagraph()

        return output
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mergeLines(in lines: [String]) -> String {
        guard !lines.isEmpty else { return "" }
        var buffer: [String] = [lines[0]]

        for line in lines.dropFirst() {
            let last = buffer.last ?? ""

            // New bullet/number only when the line starts with a list marker.
            if isListItemStart(line) {
                buffer.append(line)
                continue
            }

            if shouldMerge(lastLine: last, nextLine: line) {
                buffer[buffer.count - 1] = joinMerged(last: last, next: line)
            } else {
                buffer.append(line)
            }
        }

        return buffer.joined(separator: "\n")
    }

    private static func shouldMerge(lastLine: String, nextLine: String) -> Bool {
        let trimmedLast = lastLine.trimmingCharacters(in: .whitespaces)
        guard let lastChar = trimmedLast.last else { return false }

        if isWrapCharacter(lastChar) { return true }
        if lastChar == "," { return true }
        if ".!?".contains(lastChar) { return false }

        return true
    }

    private static func joinMerged(last: String, next: String) -> String {
        let trimmedLast = last.trimmingCharacters(in: .whitespaces)

        if last.hasSuffix(" -") || last.hasSuffix(" –") || last.hasSuffix(" —") {
            let withoutDash = String(trimmedLast.dropLast()).trimmingCharacters(in: .whitespaces)
            return withoutDash + " " + next
        }

        if trimmedLast.hasSuffix("-") || trimmedLast.hasSuffix("–") {
            return String(trimmedLast.dropLast()) + next
        }

        return trimmedLast + " " + next
    }

    private static func isWrapCharacter(_ character: Character) -> Bool {
        character == "-" || character == "–" || character == "—"
    }

    private static func isListItemStart(_ line: String) -> Bool {
        line.range(of: #"^(\u{2022}|\u{00B7}|[\-*•]|\d+[.)])\s"#, options: .regularExpression) != nil
    }
}
