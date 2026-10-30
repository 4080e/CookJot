#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /private/tmp/CookJotRecipeParserChecks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

xcrun swiftc -module-cache-path "$test_dir/ModuleCache" \
    "$root_dir/CookJot/RecipeTextParser.swift" \
    "$root_dir/Tests/RecipeTextParserChecks.swift" \
    -o "$test_dir/RecipeTextParserChecks"
"$test_dir/RecipeTextParserChecks"
