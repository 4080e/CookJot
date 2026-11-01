// Compiled only into the temporary UI-test application, never into CookJot.
import SwiftUI
import SwiftData
import UIKit

@main
struct TodayMenuJumpTestApp: App {
    private let container: ModelContainer
    private let store: TodayMenuStore

    init() {
        let scenario = ProcessInfo.processInfo.environment["JUMP_UI_SCENARIO"] ?? "long"
        container = try! ModelContainer(for: Recipe.self, RecipePhoto.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let defaults = UserDefaults(suiteName: "MenuJumpUI.\(UUID().uuidString)")!
        store = TodayMenuStore(defaults: defaults)
        let count = scenario == "empty" ? 0 : (scenario == "single" ? 1 : 3)
        let ids = (1...3).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        for index in 0..<count {
            let title = ["Jump A", "Jump B", "Jump C"][index]
            let longFirst = scenario == "long" && index < 2
            let longLast = scenario == "long-last" && index == 2
            let recipe = Recipe(id: ids[index], title: title,
                                ingredients: longFirst ? (1...120).map { "材料\($0)　大さじ1" }.joined(separator: "\n") : "材料　1個",
                                instructions: longLast ? (1...100).map { "\($0). 混ぜて加熱する" }.joined(separator: "\n") : "調理する",
                                memo: "メモ\n\n空行を維持", sourceURL: index == 2 ? "https://example.com/cookjot-jump" : nil)
            if scenario == "photo" && index == 2 {
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 1200))
                let data = renderer.pngData { context in
                    UIColor.systemOrange.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 400, height: 1200))
                }
                let file = try! RecipePhotoFileStore().save(data)
                recipe.photos.append(RecipePhoto(fileName: file, sortOrder: 0))
            }
            container.mainContext.insert(recipe)
            store.add(recipe.id)
        }
        try! container.mainContext.save()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack { TodayMenuView() }
                .environment(store)
                .tint(Color("AccentColor"))
                .preferredColorScheme(ProcessInfo.processInfo.environment["JUMP_UI_DARK"] == "1" ? .dark : nil)
        }
        .modelContainer(container)
    }
}
