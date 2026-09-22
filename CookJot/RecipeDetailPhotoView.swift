import SwiftUI
import UIKit

struct RecipeDetailPhotoView: View {
    let fileName: String
    let onSelect: (UIImage) -> Void
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let image {
                Button {
                    onSelect(image)
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("レシピの写真")
                .accessibilityHint("タップして拡大表示")
            } else if didLoad {
                Label("写真を読み込めませんでした", systemImage: "photo")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView("写真を読み込み中")
                    .frame(maxWidth: .infinity)
            }
        }
        .task(id: fileName) {
            image = nil
            didLoad = false
            if let data = try? RecipePhotoFileStore().load(fileName: fileName) {
                image = UIImage(data: data)
            }
            didLoad = true
        }
    }
}
