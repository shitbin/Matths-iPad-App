import UIKit

@main
struct ProfilePhotoPreparationCases {
    static func main() {
        for size in [CGSize(width: 1200, height: 800),
                     CGSize(width: 800, height: 1200),
                     CGSize(width: 512, height: 512)] {
            let original = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            for orientation in [UIImage.Orientation.up, .right, .leftMirrored] {
                let input = UIImage(cgImage: original.cgImage!, scale: 1, orientation: orientation)
                let data = ProfilePhotoPreparation.jpeg(from: input)!
                let decoded = UIImage(data: data)!
                precondition(decoded.size == CGSize(width: 512, height: 512))
                precondition(data.count < 5 * 1024 * 1024)
                precondition(decoded.imageOrientation == .up)
            }
        }
        precondition(ProfilePhotoPreparation.jpeg(from: UIImage()) == nil)
        print("Profile photo preparation: 9 size/orientation cases and invalid image passed")
    }
}
