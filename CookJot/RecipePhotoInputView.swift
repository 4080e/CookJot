import SwiftUI
import PhotosUI
import AVFoundation

struct RecipePhotoInputView: View {
    @Binding var photos: [Data]
    @Binding var isLoading: Bool
    @Binding var selection: [PhotosPickerItem]
    @Binding var showsLibrary: Bool
    @Binding var showsCamera: Bool
    let existingPhotos: [RecipePhoto]
    @State private var errorMessage: String?

    private var sortedExistingPhotos: [RecipePhoto] {
        existingPhotos.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Section("写真") {
            ForEach(Array(sortedExistingPhotos.enumerated()), id: \.element.id) { index, photo in
                SavedRecipePhotoRow(fileName: photo.fileName, number: index + 1)
            }
            ForEach(photos.indices, id: \.self) { index in
                HStack {
                    if let image = UIImage(data: photos[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityLabel("追加する写真")
                    }
                    Text("写真 \(existingPhotos.count + index + 1)")
                }
            }
            if isLoading {
                ProgressView("写真を読み込み中")
            }
            Menu("写真を追加") {
                Button("写真を撮る") {
                    Task { await openCamera() }
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                Button("写真ライブラリから選ぶ") {
                    showsLibrary = true
                }
            }
            .disabled(isLoading)
        }
        .task(id: selection) {
            guard !selection.isEmpty else { return }
            isLoading = true
            defer { isLoading = false }
            for item in selection {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                        errorMessage = "写真を読み込めませんでした。もう一度選択してください。"
                        continue
                    }
                    try Task.checkCancellation()
                    photos.append(data)
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = "写真を読み込めませんでした。もう一度選択してください。"
                }
            }
            selection = []
        }
        .alert("写真を追加できません", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if status == .notDetermined {
            allowed = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            allowed = status == .authorized
        }
        if allowed {
            showsCamera = true
        } else {
            errorMessage = "カメラへのアクセスが許可されていません。設定アプリでCookJotのカメラへのアクセスを許可してください。"
        }
    }
}

private struct SavedRecipePhotoRow: View {
    let fileName: String
    let number: Int
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityLabel("保存済みの写真")
            } else if didLoad {
                Image(systemName: "photo")
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(width: 72, height: 72)
            }
            VStack(alignment: .leading) {
                Text("写真 \(number)")
                if didLoad && image == nil {
                    Text("写真を読み込めませんでした")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

struct RecipeCameraView: UIViewControllerRepresentable {
    let onCapture: (Data?) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: RecipeCameraView
        init(parent: RecipeCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // カメラのUIImageを、リサイズせずPNGデータへ変換する。
            parent.onCapture((info[.originalImage] as? UIImage)?.pngData())
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
