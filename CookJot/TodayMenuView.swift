import SwiftUI
import SwiftData
import UIKit

struct TodayMenuView: View {
    @Environment(TodayMenuStore.self) private var todayMenu
    @Query private var recipes: [Recipe]
    @State private var expandedIDs = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @State private var isShowingClearConfirmation = false
    @State private var selectedPhoto: MenuPhotoSelection?

    private var menuRecipes: [Recipe] {
        todayMenu.recipeIDs.compactMap { id in recipes.first { $0.id == id } }
    }

    var body: some View {
        List {
            ForEach(menuRecipes, id: \.id) { recipe in
                // Keep the disclosure and its contents in one movable List row.
                VStack(alignment: .leading) {
                    DisclosureGroup(isExpanded: expansion(for: recipe.id)) {
                        // Explicit gating prevents collapsed groups from loading photos.
                        if expandedIDs.contains(recipe.id) && !editMode.isEditing {
                            recipeContents(recipe)
                        }
                    } label: {
                        Text(recipe.title)
                            .foregroundStyle(.primary)
                    }
                    .disabled(editMode.isEditing)
                }
                // List animates the cell height; keep its contents anchored at the top.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .swipeActions(allowsFullSwipe: false) {
                    Button("メニューから解除", systemImage: "minus.circle") {
                        todayMenu.remove(recipe.id)
                    }
                }
            }
            .onMove(perform: moveRecipes)
            .onDelete { offsets in
                let ids = menuRecipes.map(\.id)
                for offset in offsets { todayMenu.remove(ids[offset]) }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .overlay {
            if menuRecipes.isEmpty {
                ContentUnavailableView {
                    Label("今日のメニューはありません", systemImage: "fork.knife")
                } description: {
                    Text("レシピ一覧で右にスワイプして追加できます。")
                }
            }
        }
        .navigationTitle("今日のメニュー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "完了" : "編集") {
                    // Collapse and enter editing in the same transaction. Mixing a
                    // resizing disclosure row with animated editing loses List controls.
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        expandedIDs.removeAll()
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
                .disabled(menuRecipes.isEmpty)

                Menu {
                    Button("全件クリア", systemImage: "minus.circle", role: .destructive) {
                        isShowingClearConfirmation = true
                    }
                    .disabled(menuRecipes.isEmpty)
                } label: {
                    Label("メニューの操作", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("今日のメニューを全件クリアしますか？", isPresented: $isShowingClearConfirmation, titleVisibility: .visible) {
            Button("全件クリア", role: .destructive) { todayMenu.clear() }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("保存済みのレシピは削除されません。")
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                ZoomableRecipePhoto(image: photo.image)
                    .navigationTitle("写真")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { selectedPhoto = nil }
                        }
                    }
            }
            .keepAwake()
        }
        .onChange(of: menuRecipes.map(\.id)) { _, ids in
            expandedIDs.formIntersection(ids)
            if let selectedPhoto, !ids.contains(selectedPhoto.recipeID) {
                self.selectedPhoto = nil
            }
            if ids.isEmpty { editMode = .inactive }
        }
        .keepAwake()
    }

    private func expansion(for id: UUID) -> Binding<Bool> {
        Binding {
            expandedIDs.contains(id)
        } set: { expanded, incomingTransaction in
            var transaction = incomingTransaction
            if expanded {
                // Normalize opening from the label and the standard disclosure button.
                // Keep the indicator's animation from animating the entire List row.
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            withTransaction(transaction) {
                if expanded && !editMode.isEditing {
                    expandedIDs.insert(id)
                } else {
                    expandedIDs.remove(id)
                }
            }
        }
    }

    private func moveRecipes(from offsets: IndexSet, to destination: Int) {
        var ids = menuRecipes.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        todayMenu.reorder(ids)
    }

    private func recipeContents(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                heading("材料")
                if !recipe.ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bodyText(recipe.ingredients)
                }
            }
            textBlock("作り方", content: recipe.instructions)
            textBlock("メモ", content: recipe.memo)

            if !recipe.photos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    heading("写真")
                    ForEach(recipe.photos.sorted { $0.sortOrder < $1.sortOrder }) { photo in
                        RecipeDetailPhotoView(fileName: photo.fileName) { image in
                            selectedPhoto = MenuPhotoSelection(recipeID: recipe.id, image: image)
                        }
                    }
                }
            }

            if let source = recipe.sourceURL,
               !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    heading("参考リンク")
                    if let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme != nil {
                        Link(destination: url) {
                            Text(source)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        bodyText(source)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func textBlock(_ title: String, content: String) -> some View {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                heading(title)
                bodyText(content)
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(Color("AccentColor"))
            .accessibilityAddTraits(.isHeader)
    }

    private func bodyText(_ content: String) -> some View {
        Text(content)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

private struct MenuPhotoSelection: Identifiable {
    let id = UUID()
    let recipeID: UUID
    let image: UIImage
}
