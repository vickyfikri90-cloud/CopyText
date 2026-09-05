import AppKit

enum ImageEncoder {
    struct EncodedImage {
        let base64: String
        let mimeType: String
        let byteCount: Int
    }

    static func encodePNG(from image: NSImage) throws -> EncodedImage {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            throw ImageEncoderError.conversionFailed
        }

        return EncodedImage(
            base64: pngData.base64EncodedString(),
            mimeType: "image/png",
            byteCount: pngData.count
        )
    }
}

enum ImageEncoderError: LocalizedError {
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .conversionFailed: "Could not convert screenshot to PNG."
        }
    }
}
