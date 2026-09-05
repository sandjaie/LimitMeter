# Contributing to LimitMeter

Thanks for helping improve LimitMeter. This doc covers the **git workflow**, **required local hooks**, and how to land a change safely.

## Prerequisites

- macOS 14+
- Xcode Command Line Tools (or full Xcode) so `swift` works
- Homebrew tools used by the quality gate:

```bash
brew install swiftformat swiftlint
```

## One-time setup (required)

After cloning:

```bash
git clone https://github.com/sandjaie/LimitMeter.git
cd LimitMeter
./scripts/setup-hooks.sh
```

That points this clone at `.githooks/` via `core.hooksPath`. **Do not skip this.** Commits are expected to run the same gate as `./scripts/check.sh`.

Verify:

```bash
git config --get core.hooksPath   # should print: .githooks
./scripts/check.sh                # format + lint + tests
```

## Git workflow

We use a simple **GitHub Flow** on `main`.

### Branches

| Kind | Name pattern | Example |
|------|--------------|---------|
| Feature | `feature/<short-topic>` | `feature/codex-7d-window` |
| Fix | `fix/<short-topic>` | `fix/menubar-color` |
| Docs / chore | `docs/…` or `chore/…` | `docs/contributing` |

1. Start from an up-to-date `main`:

   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/my-change
   ```

2. Make a focused change (prefer small PRs over mixed refactors).
3. Push and open a pull request into `main`.
4. Keep the branch green locally (`./scripts/check.sh`) before requesting review.

### Commits

- Prefer short, imperative subjects: `Fix Codex 7D empty state`, `Add package-app script`.
- One logical change per commit when practical.
- **Never** use `git commit --no-verify` unless a maintainer explicitly asks. The pre-commit hook is required.
- **Never** commit session cookies, tokens, org/account IDs, Keychain dumps, or live credential files. Test fixtures must be sanitized.

### Pull requests

PRs should include:

- **What** changed and **why**
- How you verified (`./scripts/check.sh`, manual popover/menu bar check if UI)
- Screenshots for visible UI changes
- Notes on product copy/color rules if those were touched (see below)

Default merge target: **`main`**. Prefer squash merge for a clean history unless the PR is intentionally multi-commit.

## Required pre-commit gate

Every commit runs [`.githooks/pre-commit`](.githooks/pre-commit), which executes [`scripts/check.sh`](scripts/check.sh):

1. **SwiftFormat** — `swiftformat . --lint` (does not auto-rewrite in the hook)
2. **SwiftLint** — `swiftlint lint --strict`
3. **Tests** — `swift test` (SwiftPM)

If tools are missing, the hook **fails closed** with an install hint. Fix locally, then commit again:

```bash
swiftformat .
swiftlint lint --strict --config .swiftlint.yml
swift test
# or simply:
./scripts/check.sh
```

Re-enable hooks on a machine where `core.hooksPath` was reset:

```bash
./scripts/setup-hooks.sh
```

## Product rules (do not break)

- Show **remaining** percent (`remaining = 100 - used` when the API reports utilization).
- Menu bar shape: `5hr: 62% · 2h 14m | 7D: 81% · 4d 3h` — **never** the word “resets” in the menu bar.
- Colors on remaining: ≥40 green, 15..<40 amber, <15 red; auth/unknown → secondary gray.
- Default menu-bar provider: Claude (user-selectable).
- One provider failing must not blank the other.

More agent/maintainer detail: [`AGENTS.md`](AGENTS.md).

## Build & run while developing

```bash
swift build
swift test
./scripts/package-app.sh
open .build/LimitMeter.app
```

Prefer SwiftPM over `xcodebuild` unless you are changing Xcode-specific project settings. Optional Xcode path:

```bash
xcodegen generate
open LimitMeter.xcodeproj
```

After editing `project.yml`, regenerate the Xcode project if you use it.

## Scope

v1 is a personal macOS menu-bar app. Out of scope unless agreed in the PR: Anthropic/OpenAI org billing dashboards, browser-extension bridges, push notifications, non-macOS platforms, and adding cloud CI unless maintainers ask for it.

## Questions

Open an issue or draft PR with your proposal. Design history lives under [`docs/superpowers/`](docs/superpowers/).
