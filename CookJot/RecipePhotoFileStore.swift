import Foundation

struct RecipePhotoFileStore {
    let directoryURL: URL

    init(directoryURL: URL = URL.applicationSupportDirectory.appendingPathComponent("RecipePhotos", isDirectory: true)) {
        self.directoryURL = directoryURL
    }

    /// 元のデータを変換せず保存し、モデルに保持するファイル名を返す。
    func save(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = UUID().uuidString
        try data.write(to: fileURL(for: fileName), options: .atomic)
        return fileName
    }

    func load(fileName: String) throws -> Data {
        try Data(contentsOf: fileURL(for: fileName))
    }

    func delete(fileName: String) throws {
        try FileManager.default.removeItem(at: fileURL(for: fileName))
    }

    private func fileURL(for fileName: String) throws -> URL {
        guard !fileName.isEmpty,
              fileName != ".", fileName != "..",
              !fileName.contains("/"), !fileName.contains("\\") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }
}
