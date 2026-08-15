import AppKit

enum SpinnerFrames {
    static let frameCount = 12
    private static var cached: [NSImage]?

    static var images: [NSImage] {
        if let cached { return cached }

        let loaded: [NSImage] = (1...frameCount).compactMap { index in
            let name = String(format: "%02d", index)
            guard let url = Bundle.main.url(
                forResource: name,
                withExtension: "svg",
                subdirectory: "spinner_loading"
            ), let image = NSImage(contentsOf: url) else {
                return nil
            }
            image.isTemplate = true
            return image
        }

        cached = loaded
        return loaded
    }
}
