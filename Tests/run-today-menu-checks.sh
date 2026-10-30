#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /private/tmp/CookJotTodayMenuChecks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun swiftc -module-cache-path "$test_dir/ModuleCache" \
    "$root_dir/CookJot/TodayMenuStore.swift" \
    "$root_dir/CookJot/IdleTimerController.swift" \
    "$root_dir/CookJot/Recipe.swift" \
    "$root_dir/CookJot/RecipePhoto.swift" \
    "$root_dir/CookJot/RecipePhotoFileStore.swift" \
    "$root_dir/CookJot/RecipePhotoDeletion.swift" \
    "$root_dir/Tests/TodayMenuChecks.swift" \
    -o "$test_dir/TodayMenuChecks"
"$test_dir/TodayMenuChecks"
