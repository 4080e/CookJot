import Foundation
import SwiftData

@main
@MainActor
struct TodayMenuChecks {
    static func main() throws {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let c = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--restore" {
            let restored = TodayMenuStore(defaults: UserDefaults(suiteName: CommandLine.arguments[2])!)
            precondition(restored.recipeIDs == [c, a, b], "Order must survive a new process")
            return
        }

        var checks = 0
        func expect(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }

        let suite = "CookJot.TodayMenuTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TodayMenuStore(defaults: defaults)
        expect(store.recipeIDs.isEmpty, "Initially empty")
        store.add(a)
        store.add(b)
        store.add(a)
        expect(store.recipeIDs == [a, b], "Duplicate add preserves insertion order")
        expect(store.contains(a) && !store.contains(c), "Membership")
        store.remove(c)
        expect(store.recipeIDs == [a, b], "Unknown removal is harmless")
        store.remove(a)
        expect(store.recipeIDs == [b], "Individual removal")
        store.add(a)
        expect(store.recipeIDs == [b, a], "Re-added item is last")
        store.add(c)
        store.reorder([c, a, b])
        expect(store.recipeIDs == [c, a, b], "Reorder")
        expect(defaults.stringArray(forKey: TodayMenuStore.storageKey) == [c, a, b].map(\.uuidString), "Immediate persistence")
        store.reorder([a, b])
        store.reorder([a, a, b])
        store.reorder([a, b, UUID()])
        expect(store.recipeIDs == [c, a, b], "Reject incomplete, duplicate, or stale reorder")
        expect(TodayMenuStore(defaults: defaults).recipeIDs == [c, a, b], "Restore from defaults")

        // Check disk persistence from a separate process, with an isolated defaults suite.
        expect(defaults.synchronize(), "Flush test defaults")
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = ["--restore", suite]
        try child.run()
        child.waitUntilExit()
        expect(child.terminationStatus == 0, "Restore across process restart")

        enum FetchFailure: Error { case failed }
        do {
            try store.reconcile { throw FetchFailure.failed }
            preconditionFailure("Expected fetch failure")
        } catch FetchFailure.failed { }
        expect(store.recipeIDs == [c, a, b], "Fetch failure never clears IDs")
        expect(defaults.stringArray(forKey: TodayMenuStore.storageKey) == [c, a, b].map(\.uuidString), "Fetch failure leaves saved IDs intact")
        try store.reconcile { [a, c] }
        expect(store.recipeIDs == [c, a], "Remove missing IDs while retaining order")
        try store.reconcile { [] }
        expect(store.recipeIDs.isEmpty, "Successful empty fetch clears obsolete IDs")
        defaults.set([a.uuidString, "invalid", a.uuidString, b.uuidString.lowercased()], forKey: TodayMenuStore.storageKey)
        let cleaned = TodayMenuStore(defaults: defaults)
        expect(cleaned.recipeIDs == [a, b], "Normalize malformed and duplicate persisted IDs")
        expect(defaults.stringArray(forKey: TodayMenuStore.storageKey) == [a, b].map(\.uuidString), "Persist normalization")
        cleaned.clear()
        expect(TodayMenuStore(defaults: defaults).recipeIDs.isEmpty, "Clear is persisted")

        let container = try ModelContainer(for: Recipe.self, RecipePhoto.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let updated = Date(timeIntervalSince1970: 100)
        let recipe = Recipe(title: "卵料理", ingredients: "\n卵　1個\n\n塩\t少々\n",
                            instructions: "混ぜる\n\n焼く", memo: " メモ \n\n続き", sourceURL: "https://example.com/recipe",
                            updatedAt: updated)
        let other = Recipe(title: "にんじん")
        context.insert(recipe)
        context.insert(other)
        try context.save()
        store.add(recipe.id)
        store.add(other.id)
        expect(recipe.updatedAt == updated && !context.hasChanges, "Menu registration never modifies the recipe")
        let searchResults = try context.fetch(FetchDescriptor<Recipe>()).filter { $0.title.contains("卵") }
        store.remove(searchResults[0].id)
        store.add(searchResults[0].id)
        expect(store.recipeIDs == [other.id, recipe.id], "Search result registration only changes menu order")
        expect(recipe.updatedAt == updated && !context.hasChanges, "Search operations do not alter recipes")
        try store.reconcile { try context.fetch(FetchDescriptor<Recipe>()).map(\.id) }
        expect(store.contains(other.id), "Reconciliation uses all recipes, not search results")
        let fetched = try context.fetch(FetchDescriptor<Recipe>()).first { $0.id == recipe.id }!
        expect(fetched.ingredients == "\n卵　1個\n\n塩\t少々\n", "Stored whitespace is preserved")
        recipe.title = "更新した料理名"
        recipe.instructions = "更新\n\nした手順"
        try context.save()
        expect(fetched.title == recipe.title && fetched.instructions == recipe.instructions, "Menu references live models")

        let deletedID = other.id
        try RecipePhotoDeletion.delete(other, context: context)
        store.remove(deletedID)
        expect(!store.contains(deletedID), "Successful deletion removes membership")
        expect(try context.fetch(FetchDescriptor<Recipe>()).allSatisfy { $0.id != deletedID }, "Recipe was deleted")
        let invalidPhoto = RecipePhoto(fileName: "../invalid", sortOrder: 0, recipe: recipe)
        context.insert(invalidPhoto)
        try context.save()
        expect(!recipe.photos.isEmpty, "Failure fixture has a photo")
        do {
            try RecipePhotoDeletion.delete(recipe, context: context)
            store.remove(recipe.id)
            preconditionFailure("Invalid photo name must fail deletion")
        } catch { }
        expect(store.contains(recipe.id), "Failed deletion preserves membership")
        expect(try context.fetch(FetchDescriptor<Recipe>()).contains { $0.id == recipe.id }, "Failed deletion preserves recipe")
        store.clear()
        expect(try context.fetchCount(FetchDescriptor<Recipe>()) == 1, "Menu clear never deletes recipes")

        var applied: [Bool] = []
        let timer = IdleTimerController { applied.append($0) }
        let detail = UUID(), menu = UUID(), photo = UUID()
        timer.updateRequest(detail, isVisible: true, isActive: true)
        expect(applied == [true], "Detail enables idle timer prevention")
        timer.updateRequest(detail, isVisible: true, isActive: true)
        expect(applied == [true], "Duplicate lifecycle events are idempotent")
        timer.updateRequest(menu, isVisible: true, isActive: true)
        timer.updateRequest(detail, isVisible: false, isActive: true)
        expect(timer.isIdleTimerDisabled && applied == [true], "Leaving detail cannot cancel menu request")
        timer.updateRequest(menu, isVisible: true, isActive: false)
        expect(!timer.isIdleTimerDisabled && applied.last == false, "Inactive/background releases request")
        timer.updateRequest(menu, isVisible: true, isActive: true)
        expect(timer.isIdleTimerDisabled, "Foreground menu resumes request")
        timer.updateRequest(menu, isVisible: true, isActive: true)
        expect(applied == [true, false, true], "Expansion and editing do not interrupt prevention")
        timer.updateRequest(photo, isVisible: true, isActive: true)
        timer.updateRequest(menu, isVisible: false, isActive: true)
        expect(timer.isIdleTimerDisabled, "Photo sheet owns its own request")
        timer.updateRequest(photo, isVisible: false, isActive: true)
        expect(!timer.isIdleTimerDisabled, "Last visible owner releases request")
        timer.updateRequest(detail, isVisible: true, isActive: true)
        timer.updateRequest(detail, isVisible: true, isActive: true, isEnabled: false)
        expect(!timer.isIdleTimerDisabled, "Existing detail editor suspends prevention")
        timer.updateRequest(detail, isVisible: true, isActive: true)
        expect(timer.isIdleTimerDisabled, "Closing editor resumes detail prevention")
        timer.updateRequest(menu, isVisible: false, isActive: false)
        expect(timer.isIdleTimerDisabled, "Hidden screen cannot clear active screen")
        timer.updateRequest(detail, isVisible: true, isActive: false)
        expect(!timer.isIdleTimerDisabled, "Background detail releases prevention")
        timer.updateRequest(detail, isVisible: false, isActive: true)
        expect(!timer.isIdleTimerDisabled, "Foreground does not activate a hidden screen")

        print("PASS: \(checks) menu persistence, SwiftData integration, deletion, and idle timer checks")
    }
}
