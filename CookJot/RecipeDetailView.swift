import Foundation
import SwiftUI
import UIKit

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var isVisible = false
    @State private var isShowingEditor = false
    @State private var selectedPhoto: DetailPhotoSelection?
    @State private var isShowingCartJotError = false

    var body: some View {
        List {
            Section {
                if hasIngredients {
                    Text(recipe.ingredients)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } header: {
                HStack {
                    Text("材料")
                        .foregroundStyle(Color("AccentColor"))
                    Spacer()
                    Button(action: sendIngredientsToCartJot) {
                        Image(systemName: "cart")
                    }
                    .accessibilityLabel("CartJotへ送る")
                    .disabled(!hasIngredients)
                }
            }
            recipeSection("作り方", content: recipe.instructions)
            recipeSection("メモ", content: recipe.memo)

            if let source = recipe.sourceURL,
               !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    if let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme != nil {
                        Link(destination: url) {
                            Text(source)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(source)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("参考リンク")
                        .foregroundStyle(Color("AccentColor"))
                }
            }
            if !recipe.photos.isEmpty {
                Section {
                    ForEach(recipe.photos.sorted { $0.sortOrder < $1.sortOrder }) { photo in
                        RecipeDetailPhotoView(fileName: photo.fileName) { image in
                            selectedPhoto = DetailPhotoSelection(image: image)
                        }
                    }
                } header: {
                    Text("写真")
                        .foregroundStyle(Color("AccentColor"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") {
                    isShowingEditor = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            RecipeEditorView(recipe: recipe)
        }
        .alert("CartJotを開けませんでした", isPresented: $isShowingCartJotError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("CartJotがインストールされていることを確認してください。")
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                ZoomableRecipePhoto(image: photo.image)
                    .navigationTitle("写真")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") {
                                selectedPhoto = nil
                            }
                        }
                    }
            }
        }
        .onAppear {
            isVisible = true
            updateIdleTimer()
        }
        .onDisappear {
            isVisible = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, _ in
            updateIdleTimer()
        }
        .onChange(of: isShowingEditor) { _, _ in
            updateIdleTimer()
        }
    }

    private var hasIngredients: Bool {
        !recipe.ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendIngredientsToCartJot() {
        guard hasIngredients else { return }

        var components = URLComponents()
        components.scheme = "cartjot"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "text", value: recipe.ingredients)]

        guard let url = components.url else {
            isShowingCartJotError = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                isShowingCartJotError = true
            }
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isVisible && !isShowingEditor && scenePhase == .active
    }

    @ViewBuilder
    private func recipeSection(_ title: String, content: String) -> some View {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Section {
                Text(content)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } header: {
                Text(title)
                    .foregroundStyle(Color("AccentColor"))
            }
        }
    }
}

private struct DetailPhotoSelection: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ZoomableRecipePhoto: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation: CGSize = .zero

    private var currentScale: CGFloat {
        clampedScale(scale * magnification)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(currentScale)
            .offset(currentScale > 1 ? CGSize(
                width: offset.width + translation.width,
                height: offset.height + translation.height
            ) : .zero)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .updating($magnification) { value, state, _ in
                        state = value.magnification
                    }
                    .simultaneously(with:
                        DragGesture()
                            .updating($translation) { value, state, _ in
                                state = value.translation
                            }
                    )
                    .onEnded { value in
                        scale = clampedScale(scale * (value.first?.magnification ?? 1))
                        if scale > 1 {
                            offset.width += value.second?.translation.width ?? 0
                            offset.height += value.second?.translation.height ?? 0
                        } else {
                            offset = .zero
                        }
                    }
            )
            .padding()
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), 5)
    }
}
