# LimitMeter v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native macOS menu-bar app that shows Claude (default) or Codex 5hr/7D remaining limits in the status item, with a stacked popover for both providers and session-backed live usage.

**Architecture:** SwiftUI `MenuBarExtra` + `UsageStore` + isolated `ClaudeUsageClient` / `CodexUsageClient` reading Keychain sessions and polling usage endpoints that back the official settings pages.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (menu bar), Foundation `URLSession`, Keychain (Security framework), XCTest

## Global Constraints

- macOS 14+ deployment target; menu-bar-only (`LSUIElement` / `MenuBarExtra` with `.menuBarExtraStyle(.window)` or default popover style)
- Menu bar string never includes the word `resets`
- Display **remaining** percent; convert from used/utilization if needed
- Color thresholds: remaining ≥40 green, 15..<40 amber, &lt;15 red
- No notifications in v1
- Popover layout A: Claude block then Codex block
- Default menu bar provider: Claude
- No API org billing dashboards in v1
- Secrets only in Keychain

## File structure

```
LimitMeter/
  LimitMeter.xcodeproj/
  LimitMeter/
    LimitMeterApp.swift
    Info.plist
    Models/UsageModels.swift
    Store/UsageStore.swift
    Formatting/UsageFormatting.swift
    Formatting/LimitColor.swift
    Views/MenuBarLabelView.swift
    Views/PopoverView.swift
    Views/ProviderBlockView.swift
    Views/SignInView.swift
    Networking/HTTPClient.swift
    Providers/UsageClient.swift
    Providers/ClaudeUsageClient.swift
    Providers/CodexUsageClient.swift
    Auth/KeychainStore.swift
    Auth/SessionCredential.swift
    Preview/MockUsage.swift
    Assets.xcassets/
  LimitMeterTests/
    UsageFormattingTests.swift
    LimitColorTests.swift
  docs/superpowers/specs/2026-09-05-limitmeter-design.md
  .gitignore
  README.md
```

---

### Task 1: Xcode project + menu bar shell

**Files:**
- Create: `.gitignore`, `README.md`, `LimitMeter.xcodeproj/project.pbxproj`, `LimitMeter/LimitMeterApp.swift`, `LimitMeter/Info.plist`, `LimitMeter/Assets.xcassets/Contents.json`, `LimitMeter/Views/MenuBarLabelView.swift`, `LimitMeter/Views/PopoverView.swift`, `LimitMeter/Preview/MockUsage.swift`, `LimitMeter/Models/UsageModels.swift`, `LimitMeter/Formatting/UsageFormatting.swift`, `LimitMeter/Formatting/LimitColor.swift`

**Interfaces:**
- Produces: `ProviderID`, `LimitWindow`, `ProviderUsage`, `FetchStatus`, `UsageFormatting.menuBarText(...)`, `LimitColor.forRemaining(_:)`, stub UI with mock data

- [ ] **Step 1: Add `.gitignore`**

```
.DS_Store
.build/
DerivedData/
*.xcuserstate
xcuserdata/
.superpowers/
```

- [ ] **Step 2: Create models + formatters (testable pure Swift)**

Implement `UsageModels.swift`, `UsageFormatting.swift`, `LimitColor.swift` per design (remaining %, relative time without “resets”, color thresholds).

- [ ] **Step 3: Add XCTest targets for formatters**

Create `LimitMeterTests/UsageFormattingTests.swift` and `LimitColorTests.swift` covering conversion, menu bar string (assert no substring `resets`), and thresholds.

- [ ] **Step 4: Scaffold app with MenuBarExtra**

`LimitMeterApp` uses `MenuBarExtra` with mock Claude snapshot in the label and stacked popover showing mock Claude + Codex. `Info.plist` sets `LSUIElement` = true. Bundle id `dev.limitmeter.app`.

- [ ] **Step 5: Build and run tests**

Run: `xcodebuild -scheme LimitMeter -destination 'platform=macOS' test`  
Expected: BUILD SUCCEEDED, tests PASS

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: scaffold LimitMeter menu bar shell with mock usage"
```

---

### Task 2: UsageStore + provider selection persistence

**Files:**
- Create: `LimitMeter/Store/UsageStore.swift`
- Modify: `LimitMeterApp.swift`, `PopoverView.swift`, `MenuBarLabelView.swift`
- Test: `LimitMeterTests/UsageStoreTests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class UsageStore` with `claude`, `codex`, `menuBarProvider`, `refreshAll()`, `selectMenuBarProvider(_:)`
- Persists `menuBarProvider` in `UserDefaults` key `menuBarProvider`

- [ ] **Step 1: Implement UsageStore** with mock clients injectable via protocol `UsageClient`
- [ ] **Step 2: Wire store into App environment; popover picker updates menu bar**
- [ ] **Step 3: Unit test provider selection persistence**
- [ ] **Step 4: Commit** `feat: add UsageStore and menu bar provider preference`

---

### Task 3: Keychain session storage

**Files:**
- Create: `LimitMeter/Auth/SessionCredential.swift`, `LimitMeter/Auth/KeychainStore.swift`
- Test: `LimitMeterTests/KeychainStoreTests.swift` (use unique service name suffix in tests)

**Interfaces:**
- Produces: `struct SessionCredential: Codable` (`sessionToken` or cookie header value, `orgID` optional, `updatedAt`)
- `KeychainStore.save/load/delete(provider: ProviderID)`

- [ ] **Step 1: Implement Keychain wrappers**
- [ ] **Step 2: Tests save/load/delete**
- [ ] **Step 3: Commit** `feat: Keychain session storage for providers`

---

### Task 4: Claude live usage client

**Files:**
- Create: `LimitMeter/Networking/HTTPClient.swift`, `LimitMeter/Providers/UsageClient.swift`, `LimitMeter/Providers/ClaudeUsageClient.swift`, `LimitMeter/Views/SignInView.swift`
- Modify: `UsageStore.swift`, `PopoverView.swift`
- Test: `LimitMeterTests/ClaudeUsageParsingTests.swift` with fixture JSON

**Interfaces:**
- `ClaudeUsageClient.fetch(credential:) async throws -> ProviderUsage`
- Parses `five_hour` / `seven_day` utilization → remaining percent + `resets_at`
- On 401 → `FetchStatus.needsAuth`

- [ ] **Step 1: Fixture-based parser tests**
- [ ] **Step 2: Implement HTTP client + Claude client against `claude.ai` org usage endpoint shape**
- [ ] **Step 3: Sign-in UI that stores session into Keychain (paste-session or ASWebAuthenticationSession — pick what works in sandbox; prefer working accuracy)**
- [ ] **Step 4: Manual verify against logged-in account**
- [ ] **Step 5: Commit** `feat: Claude session usage polling`

---

### Task 5: Codex live usage client

**Files:**
- Create: `LimitMeter/Providers/CodexUsageClient.swift`
- Modify: `UsageStore.swift`, `SignInView.swift`
- Test: `LimitMeterTests/CodexUsageParsingTests.swift`

**Interfaces:**
- `CodexUsageClient.fetch(credential:) async throws -> ProviderUsage` with 5hr + weekly remaining

- [ ] **Step 1: Fixture parser tests for Codex/ChatGPT usage payload**
- [ ] **Step 2: Implement client + sign-in for ChatGPT/Codex session**
- [ ] **Step 3: Poll both providers on a 60s timer from UsageStore**
- [ ] **Step 4: Commit** `feat: Codex session usage polling`

---

### Task 6: Polish + README

**Files:**
- Modify: views for error/auth rows, relative “Updated …” footer
- Create/update: `README.md` (build, run, sign-in)

- [ ] **Step 1: Auth/error empty states in stacked popover**
- [ ] **Step 2: README with `xcodebuild` / open Xcode instructions**
- [ ] **Step 3: Full test run + commit** `docs: README and usage empty states`

---

## Spec coverage check

| Spec item | Task |
|-----------|------|
| Menu bar format without “resets” | 1 |
| Color thresholds | 1 |
| Stacked popover A | 1 |
| Provider switch | 2 |
| Keychain | 3 |
| Claude live | 4 |
| Codex live | 5 |
| No notifications | Global / no task adds them |
| Error/auth handling | 4–6 |
