import Foundation

@main
struct RecipeTextParserChecks {
    static func main() {
        var checks = 0

        func expect(_ actual: String, _ expected: String, _ label: String) {
            precondition(actual == expected,
                         "\(label): expected \(expected.debugDescription), got \(actual.debugDescription)")
            checks += 1
        }

        let cases: [(String, String, String)] = [
            ("leading newline", "\n本文", "本文"),
            ("leading newlines", "\n\n\n本文", "本文"),
            ("trailing newline", "本文\n", "本文"),
            ("trailing newlines", "本文\n\n\n", "本文"),
            ("both ends", "\n\n本文\n\n", "本文"),
            ("internal newlines and blank lines", "\n一行目\n\n二行目\n\n\n三行目\n", "一行目\n\n二行目\n\n\n三行目"),
            ("no newlines", "本文", "本文"),
            ("only newlines", "\n\n\n", ""),
            ("empty", "", ""),
            ("spaces and tabs", "\n \u{3000}\t本文\t\u{3000} \n", " \u{3000}\t本文\t\u{3000} "),
            ("only spaces and tabs", "\n \u{3000}\t\n", " \u{3000}\t"),
            ("whitespace stops trimming", "\n \n本文\n\t\n", " \n本文\n\t"),
        ]

        // Exercise the actual parser, including its existing CRLF/CR normalization.
        for newline in ["\n", "\r\n", "\r"] {
            for heading in ["材料", "作り方"] {
                for (label, input, expected) in cases {
                    let text = "料理名" + newline + heading + newline
                        + input.replacingOccurrences(of: "\n", with: newline)
                    let result = RecipeTextParser.parse(text)
                    expect(heading == "材料" ? result.ingredients : result.instructions,
                           expected, "\(heading) / \(newline.debugDescription) / \(label)")
                }
            }

            // Memo headings remain in the memo under the existing splitting rules.
            let memo = RecipeTextParser.parse(
                ["料理名", "ポイント", "", " \u{3000}\tコツ\t ", "", "補足本文", "", ""]
                    .joined(separator: newline)
            )
            expect(memo.memo, "ポイント\n\n \u{3000}\tコツ\t \n\n補足本文", "memo / \(newline.debugDescription)")
        }

        // Foundation newline characters are trimmed at the section edges only.
        for newline in ["\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}"] {
            let result = RecipeTextParser.parse(
                "料理名\n材料\n\(newline)卵\(newline)塩\(newline)\n作り方\n\(newline)混ぜる\(newline)\n\(newline)ポイント\n弱火\(newline)"
            )
            expect(result.ingredients, "卵\(newline)塩", "unicode ingredients")
            expect(result.instructions, "混ぜる", "unicode instructions")
            expect(result.memo, "ポイント\n弱火", "unicode memo")
        }

        let example = RecipeTextParser.parse("料理名\n\n材料\n卵　1個\nにんじん　1本\n\n作り方\n1. 卵を溶く\n2. にんじんを切る\n")
        expect(example.title, "料理名", "example title")
        expect(example.ingredients, "卵　1個\nにんじん　1本", "example ingredients")
        expect(example.instructions, "1. 卵を溶く\n2. にんじんを切る", "example instructions")
        expect(example.memo, "", "example memo")

        let regression = RecipeTextParser.parse("\n\t 料理名　 \n説明文\n【材料（2人分）】\n卵 1個\n■作りかた：\n材料を混ぜる\n焼く https://example.com/recipe\nhttps://example.com/source\n【ポイント・コツ】\n弱火にする\n【材料】\n塩 少々")
        expect(regression.title, "\t 料理名　 ", "title whitespace unchanged")
        expect(regression.ingredients, "（2人分）\n卵 1個\n塩 少々", "heading supplement and repeated sections")
        expect(regression.instructions, "説明文\n材料を混ぜる\n焼く https://example.com/recipe", "default section and inline URL")
        expect(regression.memo, "【ポイント・コツ】\n弱火にする", "compound memo heading retained")
        expect(regression.sourceURL, "https://example.com/recipe", "first URL extraction")

        let noHeadings = RecipeTextParser.parse("料理名\n本文\n\n続き")
        expect(noHeadings.instructions, "本文\n\n続き", "no headings")
        for input in ["", "\n\r\n\r", "料理名", "料理名\n材料\n\n作り方\n\n"] {
            let result = RecipeTextParser.parse(input)
            expect(result.ingredients, "", "empty ingredients")
            expect(result.instructions, "", "empty instructions")
            expect(result.memo, "", "empty memo")
        }

        print("PASS: \(checks) recipe parser checks")
    }
}
