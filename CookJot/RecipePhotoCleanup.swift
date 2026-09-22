import SwiftData
import OSLog

@MainActor
enum RecipePhotoCleanup {
    private static var hasRun = false
    private static let logger = Logger(subsystem: "CookJot", category: "RecipePhotoCleanup")

    static func runOnce(context: ModelContext) {
        guard !hasRun else { return }
        hasRun = true

        // fetchから削除までawaitを挟まず、写真保存処理と同じMainActor上で実行する。
        do {
            let photos = try context.fetch(FetchDescriptor<RecipePhoto>())
            let referencedNames = Set(photos.map(\.fileName))
            let failures = try RecipePhotoFileStore().removeUnreferencedFiles(referencedNames: referencedNames)
            for failure in failures {
                logger.error("孤立画像の削除に失敗しました：\(failure, privacy: .public)")
            }
        } catch {
            logger.error("写真クリーンアップを中止しました：\(error.localizedDescription, privacy: .public)")
        }
    }
}
