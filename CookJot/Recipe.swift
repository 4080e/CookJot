import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID
    var title: String
    var ingredients: String
    var instructions: String
    var memo: String
    var sourceURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        ingredients: String = "",
        instructions: String = "",
        memo: String = "",
        sourceURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.memo = memo
        self.sourceURL = sourceURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
