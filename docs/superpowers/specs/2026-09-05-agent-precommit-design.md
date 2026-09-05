# Agent Guidance + Local Pre-commit Design

**Date:** 2026-09-05  
**Status:** Approved (user: decide freely; no CI)

## Goal

Give any AI agent a single `AGENTS.md` contract for LimitMeter, and enforce required quality checks locally on every git commit — no GitHub Actions.

## Decisions

| Decision | Choice |
|----------|--------|
| Agent file | `AGENTS.md` only (not CLAUDE.md) |
| Hook mechanism | Simple `.githooks/` + `core.hooksPath` |
| Checks | SwiftFormat (lint), SwiftLint, `swift test` |
| CI | None — all local |
| Shared entrypoint | `scripts/check.sh` (hook and humans/agents) |
| Hook enable | `scripts/setup-hooks.sh` |

## Layout

```
AGENTS.md                 # Agent/human project contract
scripts/check.sh          # format lint + lint + tests
scripts/setup-hooks.sh    # git config core.hooksPath .githooks
.githooks/pre-commit      # calls scripts/check.sh
.swiftformat              # format rules
.swiftlint.yml            # lint rules
README.md                 # short pointers to setup + check
```

## Check behavior

1. Fail if `swiftformat` or `swiftlint` is missing (required tools; document `brew install`).
2. `swiftformat . --lint` — do not auto-rewrite in the hook.
3. `swiftlint lint --strict` — fail on warnings/errors per config.
4. `swift test` via SwiftPM (`Package.swift`) — unit tests for LimitMeterCore.
5. Exit non-zero on any failure so the commit is blocked.

Out of scope for pre-commit: `xcodebuild` app build, XcodeGen regenerate, GitHub Actions.

## AGENTS.md contents (required sections)

- What LimitMeter is (macOS menu-bar, Claude + Codex usage)
- Repo map (LimitMeter / LimitMeterApp / LimitMeterTests / Package.swift / project.yml)
- Commands: run app, generate Xcode project, tests, `scripts/check.sh`, enable hooks
- Architecture sketch (UsageStore → clients → Keychain)
- Conventions: remaining %, no “resets” word, Keychain-only secrets, never commit credentials
- Agent rules: run checks before claiming done; do not skip hooks; regenerate Xcode project after `project.yml` edits

## Success criteria

1. Fresh clone: after `scripts/setup-hooks.sh` + brew tools, a bad format/lint/test commit fails.
2. Agents reading `AGENTS.md` can build, test, and check without other tribal knowledge.
3. No CI configuration added.
