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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var jumps = TodayMenuJumpController()

    private var menuRecipes: [Recipe] {
        todayMenu.recipeIDs.compactMap { id in recipes.first { $0.id == id } }
    }

    var body: some View {
        ScrollViewReader { proxy in
            menuList
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    // List already lays out inside the visible safe area.
                    jumps.updateViewport($0)
                }
                .onScrollGeometryChange(for: TodayMenuJumpController.ScrollMetrics.self) {
                    .init(offset: $0.contentOffset.y, contentHeight: $0.contentSize.height,
                          containerHeight: $0.containerSize.height, topInset: $0.contentInsets.top,
                          bottomInset: $0.contentInsets.bottom)
                } action: { _, value in
                    if !editMode.isEditing { jumps.updateScroll(value) }
                }
                .onScrollPhaseChange { _, phase in
                    guard !editMode.isEditing else { return }
                    switch phase {
                    case .idle: jumps.updatePhase(.idle)
                    case .tracking, .interacting: jumps.updatePhase(.userInteraction)
                    default: jumps.updatePhase(.moving)
                    }
                }
                .contentMargins(.bottom, editMode.isEditing ? 0 : jumps.margin(lastExpanded:
                    menuRecipes.last.map { expandedIDs.contains($0.id) } ?? false), for: .scrollContent)
                .overlay(alignment: .bottomTrailing) {
                    if menuRecipes.count > 1 && !editMode.isEditing && selectedPhoto == nil {
                        jumpButtons(proxy: proxy)
                    }
                }
                .onAppear {
                    jumps.updateOrder(menuRecipes.map(\.id))
                    jumps.updatePhase(.idle)
                    jumps.layoutChanged()
                }
                .onDisappear { jumps.cancel() }
                .onChange(of: expandedIDs) { _, _ in jumps.layoutChanged() }
                .onChange(of: editMode.isEditing) { _, _ in
                    jumps.updatePhase(.idle)
                    jumps.layoutChanged()
                }
                .onChange(of: selectedPhoto?.id) { _, _ in jumps.cancel() }
                .onChange(of: dynamicTypeSize) { _, _ in jumps.contentChanged() }
                .onChange(of: menuRecipes.map(\.updatedAt)) { _, _ in jumps.contentChanged() }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { jumps.cancel() }
                    else {
                        jumps.updatePhase(.idle)
                        jumps.layoutChanged()
                    }
                }
        }
    }

    private func jumpButtons(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            jumpButton(.previous, symbol: "arrowtriangle.up.fill", label: "前のレシピ", proxy: proxy)
            jumpButton(.next, symbol: "arrowtriangle.down.fill", label: "次のレシピ", proxy: proxy)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { jumps.updateControlsHeight($0) }
        .padding(.trailing, 12)
        .padding(.bottom, 12)
    }

    private func jumpButton(_ direction: TodayMenuJumpController.Direction, symbol: String,
                            label: String, proxy: ScrollViewProxy) -> some View {
        let disabled = jumps.isJumping || jumps.phase != .idle || jumps.neighbor(direction) == nil
        return Button {
            jumps.jump(direction, reduceMotion: reduceMotion) { id, animated in
                if animated {
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .top) }
                } else {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { proxy.scrollTo(id, anchor: .top) }
                }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("AccentColor"))
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityHint("レシピカードの先頭へ移動します")
        .accessibilityIdentifier(direction == .previous ? "today-menu.jump.previous" : "today-menu.jump.next")
    }

    private var menuList: some View {
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
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 11) // 3pt line + 8pt gap
                            .padding(.trailing, 8)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color("AccentColor"))
                                    .frame(width: 3)
                                    .allowsHitTesting(false)
                            }
                            .padding(.vertical, 4)
                    }
                    .disabled(editMode.isEditing)
                }
                // List animates the cell height; keep its contents anchored at the top.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .id(recipe.id)
                .listRowBackground(TodayMenuRowBackground(id: recipe.id, epoch: jumps.epoch, jumps: jumps,
                                                        expanded: expandedIDs.contains(recipe.id), enabled: !editMode.isEditing))
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
        .listRowSpacing(4)
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
            jumps.updateOrder(ids)
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
