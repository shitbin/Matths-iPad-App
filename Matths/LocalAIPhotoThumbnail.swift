import SwiftUI

/// Decode a bounded preview away from View.body/the main actor. The original
/// path is retained for analysis; preview downsampling never changes its bytes.
struct LocalAIPhotoThumbnail: View {
    let path: String
    @State private var image: UIImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if loaded {
                Label("첨부 사진을 다시 열 수 없습니다", systemImage: "photo.badge.exclamationmark")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: path) {
            image = nil
            loaded = false
            let path = path
            let preview = await Task.detached(priority: .utility) {
                PhotoDownsampler.image(fileURL: URL(fileURLWithPath: path), maxPixel: 440)
            }.value
            guard !Task.isCancelled else { return }
            image = preview
            loaded = true
        }
    }
}
