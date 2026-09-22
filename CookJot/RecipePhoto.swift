import Foundation
import SwiftData

@Model
final class RecipePhoto {
    var id: UUID
    var fileName: String
    var sortOrder: Int
    var stepNumber: Int?
    var createdAt: Date
    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        fileName: String,
        sortOrder: Int,
        stepNumber: Int? = nil,
        createdAt: Date = Date(),
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.sortOrder = sortOrder
        self.stepNumber = stepNumber
        self.createdAt = createdAt
        self.recipe = recipe
    }
}
