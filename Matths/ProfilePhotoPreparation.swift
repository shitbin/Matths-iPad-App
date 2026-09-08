import UIKit

enum ProfilePhotoPreparation {
    /// The iPad picker may return the uncropped original. Normalize orientation,
    /// center crop and bound upload size before sending to the 5 MB endpoint.
    static func jpeg(from image: UIImage) -> Data? {
        let size = image.size
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let side: CGFloat = 512
        let scale = side / min(size.width, size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let output = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let width = size.width * scale
            let height = size.height * scale
            image.draw(in: CGRect(x: (side - width) / 2, y: (side - height) / 2,
                                  width: width, height: height))
        }
        return output.jpegData(compressionQuality: 0.82)
    }
}
