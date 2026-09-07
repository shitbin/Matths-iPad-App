import Foundation
import ImageIO
import UniformTypeIdentifiers

enum NativeServicePhotoPreparation {
    /// Decode at the destination resolution and re-encode pixels only. Original
    /// GPS/EXIF metadata is deliberately not copied into the community upload.
    static func prepareJPEG(_ data: Data, maximumPixelSize: Int = 4096) -> Data? {
        guard !data.isEmpty, data.count <= 40 * 1024 * 1024, (1...8192).contains(maximumPixelSize),
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
