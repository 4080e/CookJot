import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var isShowingNewRecipe = false
    @State private var isShowingDeleteError = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(recipes) { recipe in
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
                }
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView("レシピがありません", systemImage: "book.closed")
                }
            }
            .navigationTitle("CookJot")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新規レシピ", systemImage: "plus") {
                        isShowingNewRecipe = true
                    }
                }
            }
            .sheet(isPresented: $isShowingNewRecipe) {
                RecipeEditorView()
            }
            .alert("削除できませんでした", isPresented: $isShowingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("もう一度削除してください。")
            }
        }
    }

    private func deleteRecipe(_ recipe: Recipe) {
        modelContext.delete(recipe)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            isShowingDeleteError = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
