import Foundation
import SwiftUI
import SwiftData
import PhotosUI

struct RecipeEditorView: View {
    private let recipe: Recipe?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var memo = ""
    @State private var sourceURL = ""
    @State private var isShowingSaveError = false
    @State private var isShowingImport = false
    @State private var pendingPhotos: [Data] = []
    @State private var isLoadingPhotos = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var cameraCaptureFailed = false
    @State private var isShowingCameraError = false

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _ingredients = State(initialValue: recipe?.ingredients ?? "")
        _instructions = State(initialValue: recipe?.instructions ?? "")
        _memo = State(initialValue: recipe?.memo ?? "")
        _sourceURL = State(initialValue: recipe?.sourceURL ?? "")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if recipe == nil {
                    Section {
                        Button("かんたん取込") {
                            isShowingImport = true
                        }
                    }
                }
                Section("レシピ名") {
                    TextField("レシピ名", text: $title)
                }
                Section("材料") {
                    TextField("材料", text: $ingredients, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("作り方") {
                    TextField("作り方", text: $instructions, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("メモ") {
                    TextField("メモ", text: $memo, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("参考リンク") {
                    TextField("URL（任意）", text: $sourceURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                RecipePhotoInputView(
                    photos: $pendingPhotos,
                    isLoading: $isLoadingPhotos,
                    selection: $photoSelection,
                    showsLibrary: $isShowingPhotoLibrary,
                    showsCamera: $isShowingCamera,
                    existingPhotos: recipe?.photos ?? []
                )
            }
            .navigationTitle(recipe == nil ? "新規レシピ" : "レシピを編集")
            .sheet(isPresented: $isShowingImport) {
                RecipeImportView { imported in
                    title = imported.title
                    ingredients = imported.ingredients
                    instructions = imported.instructions
                    memo = imported.memo
                    sourceURL = imported.sourceURL
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: saveRecipe)
                        .disabled(trimmedTitle.isEmpty || isLoadingPhotos)
                }
            }
            .alert("保存できませんでした", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("入力内容を保持しています。もう一度保存してください。")
            }
        }
        // MenuやFormの行ではなく、編集中存続するビューをPickerの表示元にする。
        .photosPicker(
            isPresented: $isShowingPhotoLibrary,
            selection: $photoSelection,
            selectionBehavior: .ordered,
            matching: .images
        )
        .fullScreenCover(isPresented: $isShowingCamera, onDismiss: {
            isShowingCameraError = cameraCaptureFailed
            cameraCaptureFailed = false
        }) {
            RecipeCameraView(onCapture: { data in
                if let data {
                    pendingPhotos.append(data)
                } else {
                    cameraCaptureFailed = true
                }
                isShowingCamera = false
            }, onCancel: {
                isShowingCamera = false
            })
            .ignoresSafeArea()
        }
        .alert("写真を追加できません", isPresented: $isShowingCameraError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("撮影した写真を読み込めませんでした。")
        }
    }

    private func saveRecipe() {
        guard !trimmedTitle.isEmpty, !isLoadingPhotos else { return }

        let fileStore = RecipePhotoFileStore()
        var savedFileNames: [String] = []
        do {
            for data in pendingPhotos {
                savedFileNames.append(try fileStore.save(data))
            }
        } catch {
            for fileName in savedFileNames {
                try? fileStore.delete(fileName: fileName)
            }
            isShowingSaveError = true
            return
        }

        let now = Date()
        let link = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Recipe
        if let recipe {
            target = recipe
        } else {
            target = Recipe(title: trimmedTitle, createdAt: now, updatedAt: now)
            modelContext.insert(target)
        }
        target.title = trimmedTitle
        target.ingredients = ingredients
        target.instructions = instructions
        target.memo = memo
        target.sourceURL = link.isEmpty ? nil : link
        target.updatedAt = now

        let nextOrder = (target.photos.map(\.sortOrder).max() ?? -1) + 1
        for (index, fileName) in savedFileNames.enumerated() {
            let photo = RecipePhoto(fileName: fileName, sortOrder: nextOrder + index, createdAt: now, recipe: target)
            modelContext.insert(photo)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            for fileName in savedFileNames {
                try? fileStore.delete(fileName: fileName)
            }
            isShowingSaveError = true
        }
    }
}

#Preview {
    RecipeEditorView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
