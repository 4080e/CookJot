import SwiftUI
import SwiftData

struct ContentView: View {
    private enum RecipeSortOrder: String {
        case updatedAt
        case name
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(TodayMenuStore.self) private var todayMenu
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @AppStorage("recipeSortOrder") private var sortOrder: RecipeSortOrder = .updatedAt
    @State private var isShowingNewRecipe = false
    @State private var isShowingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var searchText = ""
    @State private var isShowingTodayMenu = false
    @State private var menuPresentationID = UUID()

    private var menuCount: Int {
        recipes.filter { todayMenu.contains($0.id) }.count
    }

    private var filteredRecipes: [Recipe] {
        let filtered = recipes.filter { recipe in
            searchText.isEmpty
                || recipe.title.localizedCaseInsensitiveContains(searchText)
                || recipe.ingredients.localizedCaseInsensitiveContains(searchText)
                || recipe.instructions.localizedCaseInsensitiveContains(searchText)
                || recipe.memo.localizedCaseInsensitiveContains(searchText)
        }

        switch sortOrder {
        case .updatedAt:
            return filtered
        case .name:
            return filtered.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        Text(recipe.title)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            deleteRecipe(recipe)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if todayMenu.contains(recipe.id) {
                            Button("メニューから解除", systemImage: "minus.circle") {
                                todayMenu.remove(recipe.id)
                            }
                        } else {
                            Button("メニューに追加", systemImage: "fork.knife") {
                                todayMenu.add(recipe.id)
                            }
                            .tint(Color("AccentColor"))
                        }
                    }
                }
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("レシピがありません", systemImage: "book.closed")
                } else if filteredRecipes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("CookJot")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "レシピを検索")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        menuPresentationID = UUID()
                        isShowingTodayMenu = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "fork.knife")
                            Text(menuCount, format: .number)
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel("今日のメニュー")
                    .accessibilityValue("\(menuCount)件")

                    Menu {
                        Picker("並べ替え", selection: $sortOrder) {
                            Text("更新が新しい順").tag(RecipeSortOrder.updatedAt)
                            Text("名前順").tag(RecipeSortOrder.name)
                        }
                    } label: {
                        Label("並べ替え", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("並べ替え")

                    Button("新規レシピ", systemImage: "plus") {
                        isShowingNewRecipe = true
                    }
                }
            }
            .sheet(isPresented: $isShowingNewRecipe) {
                RecipeEditorView()
            }
            .navigationDestination(isPresented: $isShowingTodayMenu) {
                TodayMenuView()
                    .id(menuPresentationID)
            }
            .alert("削除できませんでした", isPresented: $isShowingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }

    private func deleteRecipe(_ recipe: Recipe) {
        let id = recipe.id
        do {
            try RecipePhotoDeletion.delete(recipe, context: modelContext)
            todayMenu.remove(id)
        } catch {
            deleteErrorMessage = error.localizedDescription
            isShowingDeleteError = true
        }
    }
}

#Preview {
    ContentView()
        .environment(TodayMenuStore(defaults: UserDefaults(suiteName: "CookJotPreview")!))
        .modelContainer(for: Recipe.self, inMemory: true)
}
