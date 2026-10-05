#!/usr/bin/env python3
"""Run the PasteButton's actual disabled expression against regression cases.

Usage: python3 Tests/run-paste-button-checks.py
This checks the source predicate; native PasteButton behavior needs device QA.
"""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "CookJot/RecipeImportView.swift").read_text()
match = re.search(
    r"PasteButton\(payloadType: String\.self\).*?\.disabled\(([^\n]+)\)",
    source,
    re.DOTALL,
)
assert match, "PasteButton disabled expression missing"
expression = match.group(1)
swift = r'''import Foundation
func isDisabled(_ text: String) -> Bool {
    return EXPRESSION
}
let cases: [(String, Bool)] = [
    ("", false),
    (" ", false),
    ("\t\r\n  ", false),
    ("\u{3000}\n", false),
    ("a", true),
    ("塩", true),
    ("  玉ねぎ 1個\n", true),
    ("・", true),
    ("🥕", true),
    ("【材料】", true)
]
for (text, expected) in cases {
    precondition(isDisabled(text) == expected, "Unexpected state: \(text.debugDescription)")
}
// Empty -> pasted -> manually edited -> cleared -> whitespace only.
for (text, expected) in [("", false), ("塩 大さじ1", true), ("塩 小さじ1", true), ("", false), (" \n", false)] {
    precondition(isDisabled(text) == expected)
}
print("PASS: 10 input cases and 5 editing states")
'''.replace("EXPRESSION", expression)
with tempfile.TemporaryDirectory(prefix="CookJotPasteChecks-") as directory:
    path = Path(directory) / "main.swift"
    path.write_text(swift)
    subprocess.run(["swift", "-module-cache-path", str(Path(directory) / "ModuleCache"), str(path)], check=True)
