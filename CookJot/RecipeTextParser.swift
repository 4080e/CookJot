import Foundation

struct ImportedRecipe {
    var title = ""
    var ingredients = ""
    var instructions = ""
    var memo = ""
    var sourceURL = ""
}

enum RecipeTextParser {
    private enum Section: Int {
        case ingredients, instructions, memo
    }

    static func parse(_ text: String) -> ImportedRecipe {
        var result = ImportedRecipe()
        var hasTitle = false
        var section = Section.instructions
        var contents = [[String]](repeating: [], count: 3)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let links = detector?.matches(in: line, range: NSRange(line.startIndex..., in: line))
                .filter { match in
                    guard let range = Range(match.range, in: line) else { return false }
                    let value = line[range].lowercased()
                    return value.hasPrefix("http://") || value.hasPrefix("https://")
                } ?? []
            if result.sourceURL.isEmpty, let match = links.first,
               let range = Range(match.range, in: line) {
                result.sourceURL = String(line[range])
            }

            if !hasTitle {
                guard !trimmed.isEmpty else { continue }
                result.title = line
                hasTitle = true
                continue
            }

            if let match = links.first, links.count == 1,
               let range = Range(match.range, in: line),
               String(line[range]) == trimmed {
                continue
            }
            if let heading = headingSection(trimmed) {
                section = heading
                if heading == .memo {
                    contents[section.rawValue].append(line)
                } else if let range = trimmed.range(
                    of: #"（[^（）]+）|\([^()]+\)"#,
                    options: .regularExpression
                ) {
                    contents[section.rawValue].append(String(trimmed[range]))
                }
            } else {
                contents[section.rawValue].append(line)
            }
        }

        result.ingredients = contents[Section.ingredients.rawValue].joined(separator: "\n")
        result.instructions = contents[Section.instructions.rawValue].joined(separator: "\n")
        result.memo = contents[Section.memo.rawValue].joined(separator: "\n")
        return result
    }

    private static func headingSection(_ line: String) -> Section? {
        let decoration = CharacterSet(charactersIn: " \t　【】■●＜＞<>：:")
        let heading = line.trimmingCharacters(in: decoration)
        if matchesHeading(heading, words: ["材料", "材料・調味料"]) {
            return .ingredients
        }
        if matchesHeading(heading, words: ["作り方", "作りかた", "手順", "調理手順"]) {
            return .instructions
        }
        let memoWords = ["下準備", "ポイント", "コツ", "アレンジ", "保存", "保存方法", "代用", "補足", "注意点"]
        if matchesHeading(heading, words: memoWords, allowsCompound: true) {
            return .memo
        }
        return nil
    }

    private static func matchesHeading(_ heading: String, words: [String], allowsCompound: Bool = false) -> Bool {
        let word = "(?:" + words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")"
        let compound = allowsCompound ? "(?:\\s*・\\s*\(word))*" : ""
        // 補足は括弧書き、または数量＋単位に限定し、本文の前方一致を避ける。
        let supplement = #"(?:\s*(?:（[^（）]+）|\([^()]+\)|[0-9０-９]+(?:人分|行|分|項目|つ)))?"#
        let pattern = "^" + word + compound + supplement + "$"
        return heading.range(of: pattern, options: .regularExpression) != nil
    }
}
