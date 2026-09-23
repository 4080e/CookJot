import SwiftUI
import SwiftData

@main
struct CookJotApp: App {
    var body: some Scene {
        WindowGroup {
            CookJotRootView()
                .tint(Color("AccentColor"))
        }
        .modelContainer(for: [Recipe.self, RecipePhoto.self])
    }
}

private struct CookJotRootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .task {
                RecipePhotoCleanup.runOnce(context: modelContext)
            }
    }
}
