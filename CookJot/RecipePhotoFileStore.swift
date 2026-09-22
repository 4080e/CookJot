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

    /// 参照名を取得できた場合だけ呼ぶ。サブディレクトリやリンクは削除しない。
    func removeUnreferencedFiles(referencedNames: Set<String>) throws -> [String] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }

        var failures: [String] = []
        for file in files {
            guard !referencedNames.contains(file.lastPathComponent) else { continue }
            do {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                try delete(fileName: file.lastPathComponent)
            } catch {
                failures.append("\(file.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        return failures
    }

    /// 削除処理に失敗した場合に、元のファイル名で復元する。
    func restore(_ data: Data, fileName: String) throws {
        let url = try fileURL(for: fileName)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
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
