import Foundation
import Observation

@MainActor
@Observable
final class TodayMenuStore {
    static let storageKey = "todayMenuRecipeIDs"

    private(set) var recipeIDs: [UUID]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.storageKey) ?? []
        var seen = Set<UUID>()
        recipeIDs = stored.compactMap { value in
            guard let id = UUID(uuidString: value), seen.insert(id).inserted else { return nil }
            return id
        }
        if stored != recipeIDs.map(\.uuidString) {
            save()
        }
    }

    func contains(_ id: UUID) -> Bool {
        recipeIDs.contains(id)
    }

    func add(_ id: UUID) {
        guard !contains(id) else { return }
        recipeIDs.append(id)
        save()
    }

    func remove(_ id: UUID) {
        guard contains(id) else { return }
        recipeIDs.removeAll { $0 == id }
        save()
    }

    func clear() {
        recipeIDs = []
        save()
    }

    /// The UI supplies its displayed order. Ignore stale or incomplete reorder requests.
    func reorder(_ ids: [UUID]) {
        guard ids.count == recipeIDs.count, Set(ids) == Set(recipeIDs) else { return }
        recipeIDs = ids
        save()
    }

    /// Only prune after a successful fetch of all recipes, never from a filtered query.
    func reconcile(fetchAllRecipeIDs: () throws -> [UUID]) throws {
        let existing = Set(try fetchAllRecipeIDs())
        let remaining = recipeIDs.filter { existing.contains($0) }
        guard remaining != recipeIDs else { return }
        recipeIDs = remaining
        save()
    }

    private func save() {
        defaults.set(recipeIDs.map(\.uuidString), forKey: Self.storageKey)
    }
}
