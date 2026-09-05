#!/usr/bin/env bash
# Point this clone at the repo-managed git hooks (required for contributors).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .git ]]; then
  echo "error: not a git repository: $ROOT" >&2
  exit 1
fi

if [[ ! -x .githooks/pre-commit ]]; then
  chmod +x .githooks/pre-commit
fi

git config core.hooksPath .githooks

hooks_path="$(git config --get core.hooksPath)"
if [[ "${hooks_path}" != ".githooks" ]]; then
  echo "error: failed to set core.hooksPath (got: ${hooks_path:-empty})" >&2
  exit 1
fi

echo "OK: core.hooksPath=.githooks"
echo "Pre-commit (required) runs: scripts/check.sh"
echo "  → swiftformat --lint, swiftlint --strict, swift test"
echo
echo "Install tools if needed: brew install swiftformat swiftlint"
echo "Manual gate anytime:     ./scripts/check.sh"
echo "See CONTRIBUTING.md for the full git workflow."
