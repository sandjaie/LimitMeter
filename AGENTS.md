# AGENTS.md — LimitMeter

Guidance for any AI coding agent working in this repository.

## What this is

Native **macOS menu-bar** app (`LSUIElement`) that shows **Claude** and **Codex** subscription usage: 5-hour and 7-day **remaining** % plus reset countdowns. Popover stacks both providers. No Dock icon; no notifications in v1.

## Repo map

| Path | Role |
|------|------|
| `LimitMeter/` | Core library: models, networking, providers, credentials, formatting, store |
| `LimitMeterApp/` | App target: `MenuBarExtra`, SwiftUI views |
| `LimitMeterTests/` | Unit tests + JSON fixtures |
| `Package.swift` | SwiftPM package (preferred build/test path) |
| `project.yml` | XcodeGen spec (optional Xcode project) |
| `scripts/check.sh` | Required local quality gate (pre-commit) |
| `scripts/setup-hooks.sh` | Enable repo git hooks (required once per clone) |
| `CONTRIBUTING.md` | Git workflow, hooks, PR expectations |
| `.githooks/` | Repo-managed hooks (`core.hooksPath`) |
| `docs/architecture.md` | Architecture, settings, poll/auth/error reference |
| `docs/superpowers/` | Design specs and implementation plans |

## Commands

```bash
# Build / run (SwiftPM — preferred)
swift build
swift run LimitMeter
swift test

# Required quality gate (same as pre-commit)
./scripts/check.sh

# Enable required git hooks once per clone
./scripts/setup-hooks.sh

# Optional Xcode path
xcodegen generate
open LimitMeter.xcodeproj
```

**Tools required for checks:** `swiftformat`, `swiftlint`, `swift`  
Install: `brew install swiftformat swiftlint`  
Human workflow: [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Architecture

```
MenuBarExtra → PopoverView / MenuBarLabelView
       ↓
   UsageStore (@Observable)
       ↓
 ClaudeUsageClient | CodexUsageClient
       ↓
 CredentialStore + SignInView
```

- One provider failing must not blank the other.
- Secrets live in Application Support (`~/Library/Application Support/LimitMeter/`), not the app Keychain.
- Prefer undocumented usage endpoints that match each product’s settings page over local token-log estimates.

Architecture deep-dive: [`docs/architecture.md`](docs/architecture.md).

## Product rules (do not break)

- Display **remaining** percent (if API gives utilization used: `remaining = 100 - used`).
- Menu bar copy shape: `5hr: 62% · 2h 14m | 7D: 81% · 4d 3h` — **never** the word “resets”.
- Color thresholds on remaining: ≥40 green, 15..<40 amber, <15 red; auth/unknown → secondary gray.
- Default menu-bar provider: Claude (user-selectable).
- Never commit session cookies, tokens, org/account IDs, or real Keychain dumps. Fixtures must be sanitized.

## Agent workflow

1. Prefer SwiftPM (`swift test` / `swift build`) over `xcodebuild` unless the task is Xcode-specific.
2. After editing `project.yml`, run `xcodegen generate` if the `.xcodeproj` is in use.
3. Before claiming work complete, run `./scripts/check.sh` and fix failures.
4. Ensure hooks are enabled (`./scripts/setup-hooks.sh`). Do not bypass git hooks (`--no-verify`) unless the human explicitly asks.
5. Follow [`CONTRIBUTING.md`](CONTRIBUTING.md) for branches, commits, and PRs (GitHub Flow on `main`).
6. Keep changes scoped; do not add cloud CI / GitHub Actions unless asked.
7. Design history lives under `docs/superpowers/` — update specs/plans when changing product behavior.

## Out of scope (v1)

Anthropic/OpenAI API org billing dashboards, browser-extension bridges, push notifications, non-macOS platforms.
