import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var isShowingNewRecipe = false

    var body: some View {
        NavigationStack {
            List(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    Text(recipe.title)
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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
