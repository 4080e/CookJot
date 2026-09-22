import Foundation
import SwiftData

@MainActor
enum RecipePhotoDeletion {
    static func delete(_ photo: RecipePhoto, context: ModelContext) throws {
        try perform(photos: [photo], context: context) {
            context.delete(photo)
        }
    }

    static func delete(_ recipe: Recipe, context: ModelContext) throws {
        try perform(photos: recipe.photos, context: context) {
            context.delete(recipe)
        }
    }

    private static func perform(photos: [RecipePhoto], context: ModelContext, deleteRecords: () -> Void) throws {
        let store = RecipePhotoFileStore()
        var backups: [String: Data] = [:]
        var deletedNames: [String] = []
        var changedRecords = false
        var operation = "画像の読み込み"
        do {
            // 全画像を確保してから削除し、途中失敗時に元のファイル名で復元する。
            for name in Set(photos.map(\.fileName)) {
                operation = "画像の読み込み（\(name)）"
                do {
                    backups[name] = try store.load(fileName: name)
                } catch CocoaError.fileReadNoSuchFile {
                    // 既にないファイルは削除済みとして扱う。
                }
            }
            for name in backups.keys {
                operation = "画像の削除（\(name)）"
                try store.delete(fileName: name)
                deletedNames.append(name)
            }
            operation = "データベースへの削除の保存"
            changedRecords = true
            deleteRecords()
            try context.save()
        } catch {
            if changedRecords { context.rollback() }
            var failures: [String] = []
            for name in deletedNames {
                guard let data = backups[name] else { continue }
                do {
                    try store.restore(data, fileName: name)
                } catch {
                    failures.append("\(name)：\(error.localizedDescription)")
                }
            }
            let recovery = failures.isEmpty ? "" : "\n画像の復元にも失敗しました：\n" + failures.joined(separator: "\n")
            throw DeletionError(message: "\(operation)に失敗しました。\n\(error.localizedDescription)\(recovery)")
        }
    }

    private struct DeletionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
