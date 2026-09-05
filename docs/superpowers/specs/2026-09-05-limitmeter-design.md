# LimitMeter Design Spec

**Date:** 2026-09-05  
**Status:** Approved for implementation (user directed start)

## Goal

Native macOS menu-bar app that shows **Claude** and **Codex** subscription usage limits (5-hour and 7-day windows, remaining %, reset countdown) at a glance, with a popover for both providers’ key facts.

## Product decisions

| Decision | Choice |
|----------|--------|
| Platform | macOS only |
| Tech | Native Swift / SwiftUI |
| Chrome | Menu bar only (`LSUIElement`); no Dock icon |
| Detail UI | Popover attached to status item |
| Menu bar provider | User-selectable; **default Claude** |
| Menu bar copy | `[icon] 5hr: 62% · 2h 14m \| 7D: 81% · 4d 3h` (no “resets” word) |
| Popover layout | **A — Stacked providers** (Claude block, then Codex) |
| Alerts | Menu bar / value **color only** (green → amber → red); no notifications |
| Scope v1 | Claude.ai + ChatGPT/Codex **subscription** usage (same endpoints as settings pages) |
| Out of scope v1 | Anthropic/OpenAI **API org** billing dashboards; browser extension bridge; CLI-only auth as primary source |
| Auth | Session credentials via sign-in / Keychain; poll official usage-page backends for accuracy |
| Phasing under shell | (1) Menu bar + popover + mock data (2) Claude live (3) Codex live |

## Architecture

```
MenuBarExtra → PopoverView
       ↓
   UsageStore (@Observable)
       ↓
 ClaudeUsageClient | CodexUsageClient
       ↓
 KeychainSessionStore + SignIn flows
```

- **UI:** SwiftUI `MenuBarExtra` label = selected provider snapshot; popover = both providers stacked + “Show in menu bar” picker + Quit.
- **State:** Single `UsageStore` owns cached `ProviderUsage` snapshots, selected menu-bar provider, last error, refresh cadence.
- **Providers:** Isolated clients; failure in one does not blank the other.
- **Secrets:** Keychain only.

## Data model

```swift
enum ProviderID: String, CaseIterable { case claude, codex }

struct LimitWindow: Equatable {
  var remainingPercent: Double   // 0...100, display as “left”
  var resetsAt: Date
}

struct ProviderUsage: Equatable {
  var provider: ProviderID
  var planLabel: String?         // e.g. "Max", "Plus"
  var fiveHour: LimitWindow?
  var sevenDay: LimitWindow?
  var fetchedAt: Date
  var status: FetchStatus       // ok | needsAuth | error(String)
}
```

Display uses **remaining** percent (if API returns utilization used, convert: `remaining = 100 - used`).

## Menu bar formatting

- Selected provider icon (SF Symbol or asset tint).
- `5hr: {Int(remaining)}% · {relative short}` and `7D: …` separated by `|`.
- Relative time: `2h 14m`, `4d 3h`, `12m` — never the word “resets”.
- Missing window: show `—`.
- Color of the **percent values** (and optionally icon):  
  - remaining ≥ 40 → green  
  - 15..<40 → amber  
  - &lt; 15 → red  
  - unknown/auth → secondary gray

## Popover (layout A)

1. **Claude** header (icon + name + plan)  
2. Two tiles: 5hr left %, countdown; 7D left %, countdown  
3. **Codex** same structure  
4. Footer: `Show in menu bar: [Claude|Codex]` · Refresh · Quit  
5. Auth/error row per provider when `needsAuth` or `error`

## Data sources (accuracy-first)

### Claude

- Prefer the same org usage payload used by `claude.ai/settings/usage` (session-authenticated), typically including `five_hour` and `seven_day` (and additional buckets later if useful).
- Org id / session from Keychain after sign-in (ASWebAuthenticationSession or equivalent cookie/session capture).
- Poll ~240s while store is active; manual refresh in popover. On HTTP 429, back off to ~5 minutes.

### Codex / ChatGPT

- Prefer ChatGPT/Codex account usage surfaces that expose 5h + weekly remaining (session-authenticated), matching what `/status` and the web usage page show.
- Same Keychain + sign-in pattern, separate credential slot from Claude.

### Explicit non-goals for accuracy

- Do not invent limits from local JSONL token logs as the primary meter (under-counts vs server weighting).

## Error handling

- **401 / expired session:** mark provider `needsAuth`; keep last good snapshot grayed with “Sign in” affordance.
- **Network failure:** keep last snapshot; show subtle “Updated Xs ago” / retry.
- **Partial parse:** show windows that parsed; omit others as `—`.
- Never crash the status item on provider errors.

## Settings (minimal)

- Menu bar provider preference (`UserDefaults`).
- Sign in / Sign out per provider.
- No notification settings in v1.

## Testing

- Unit tests for: percent conversion (used → remaining), relative time formatting, color thresholds, menu bar string builder.
- Manual: signed-in Claude + Codex refresh; expired session path; provider switch in menu bar.

## Success criteria

1. App runs as menu-bar-only utility.  
2. Default menu bar shows Claude 5hr + 7D remaining % and countdowns without the word “resets”.  
3. Popover stacks Claude then Codex with icons and key facts.  
4. User can switch which provider the menu bar mirrors.  
5. Live data matches each product’s usage page within normal poll lag when signed in.
