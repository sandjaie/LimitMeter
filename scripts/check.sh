#!/usr/bin/env bash
# Local quality gate for LimitMeter (also used by .githooks/pre-commit).
# Required before every commit — see CONTRIBUTING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

missing=()
command -v swiftformat >/dev/null || missing+=("swiftformat")
command -v swiftlint >/dev/null || missing+=("swiftlint")
command -v swift >/dev/null || missing+=("swift")

if ((${#missing[@]})); then
  echo "error: missing required tools: ${missing[*]}" >&2
  echo "Install with: brew install swiftformat swiftlint" >&2
  echo "(swift comes from Xcode / Command Line Tools)" >&2
  echo "See CONTRIBUTING.md for setup." >&2
  exit 1
fi

echo "==> SwiftFormat (lint)"
swiftformat . --lint

echo "==> SwiftLint"
swiftlint lint --strict --config .swiftlint.yml

echo "==> swift test"
swift test

echo "OK: all checks passed."
