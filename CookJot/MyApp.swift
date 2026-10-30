import SwiftUI
import SwiftData
import OSLog

@main
struct CookJotApp: App {
    @State private var todayMenu = TodayMenuStore()

    var body: some Scene {
        WindowGroup {
            CookJotRootView()
                .environment(todayMenu)
                .tint(Color("AccentColor"))
        }
        .modelContainer(for: [Recipe.self, RecipePhoto.self])
    }
}

private struct CookJotRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TodayMenuStore.self) private var todayMenu

    var body: some View {
        ContentView()
            .task {
                RecipePhotoCleanup.runOnce(context: modelContext)
                reconcileMenu()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reconcileMenu() }
            }
    }

    private func reconcileMenu() {
        do {
            try todayMenu.reconcile {
                try modelContext.fetch(FetchDescriptor<Recipe>()).map(\.id)
            }
        } catch {
            Logger(subsystem: "CookJot", category: "TodayMenu")
                .error("メニューの参照確認を中止しました：\(error.localizedDescription, privacy: .public)")
        }
    }
}
