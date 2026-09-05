# Agent Guidance + Local Pre-commit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `AGENTS.md` and a local pre-commit gate (SwiftFormat, SwiftLint, `swift test`) with no GitHub Actions.

**Architecture:** One shared `scripts/check.sh` entrypoint; `.githooks/pre-commit` delegates to it; `scripts/setup-hooks.sh` sets `core.hooksPath`; style configs live at repo root; `AGENTS.md` is the agent contract.

**Tech Stack:** Bash, SwiftFormat, SwiftLint, SwiftPM (`swift test`), git `core.hooksPath`

## Global Constraints

- macOS 14+ / Swift 5.9+ package layout already in repo
- No GitHub Actions or cloud CI
- Pre-commit must fail closed if format/lint tools are missing
- Do not auto-format inside the hook (lint-only); document how to fix
- Do not commit unless the user asks

---

### Task 1: Style configs + check script + hooks

**Files:**
- Create: `.swiftformat`
- Create: `.swiftlint.yml`
- Create: `scripts/check.sh`
- Create: `scripts/setup-hooks.sh`
- Create: `.githooks/pre-commit`

**Interfaces:**
- Produces: executable `scripts/check.sh` that exits 0 only when format lint, SwiftLint, and `swift test` all pass; `scripts/setup-hooks.sh` that runs `git config core.hooksPath .githooks`

- [ ] **Step 1: Add `.swiftformat`**

```
--swiftversion 5.9
--indent 4
--maxwidth 120
--exclude .build,DerivedData
```

- [ ] **Step 2: Add `.swiftlint.yml`**

Moderate defaults: exclude `.build`, `DerivedData`, `.superpowers`; disable noisy rules (`trailing_whitespace` handled by format, `todo`); set `line_length` warning 120 / error 200; `strict` via CLI flag in check script.

- [ ] **Step 3: Add `scripts/check.sh`**

Require `swiftformat` and `swiftlint` on PATH; run `swiftformat . --lint`, `swiftlint lint --strict`, `swift test`; `set -euo pipefail`.

- [ ] **Step 4: Add `scripts/setup-hooks.sh` and `.githooks/pre-commit`**

`setup-hooks.sh`: `git config core.hooksPath .githooks` from repo root.  
`pre-commit`: `exec "$(git rev-parse --show-toplevel)/scripts/check.sh"`.  
`chmod +x` all three scripts.

- [ ] **Step 5: Verify**

Run: `brew list swiftformat swiftlint 2>/dev/null; ./scripts/check.sh`  
Expected: tools present (or clear install message); check passes or reports real violations to fix before claiming done.

---

### Task 2: AGENTS.md + README pointers

**Files:**
- Create: `AGENTS.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: check/setup script paths from Task 1
- Produces: agent-readable project contract

- [ ] **Step 1: Write `AGENTS.md`** covering product summary, directory map, commands (Xcode, xcodegen, `swift test`, `./scripts/check.sh`, `./scripts/setup-hooks.sh`), architecture, auth/Keychain rules, display copy rules, agent do/don't.

- [ ] **Step 2: Add README section** “Local checks” with brew install, setup-hooks, and `./scripts/check.sh`.

- [ ] **Step 3: Run `./scripts/check.sh` and fix any format/lint issues introduced or revealed until exit 0.**
