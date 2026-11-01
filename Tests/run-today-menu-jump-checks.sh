#!/bin/sh
set -eu
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d /private/tmp/CookJotJumpChecks.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun swiftc -module-cache-path "$test_dir/ModuleCache" \
    "$root_dir/CookJot/TodayMenuJumpController.swift" \
    "$root_dir/Tests/TodayMenuJumpChecks.swift" -o "$test_dir/JumpChecks"
"$test_dir/JumpChecks"
