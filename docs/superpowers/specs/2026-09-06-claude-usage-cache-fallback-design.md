# Claude local usage-cache fallback (A + B)

**Date:** 2026-09-06  
**Status:** Approved (user: A and B)

## Goal

When Anthropic’s OAuth usage API returns **429** (or is unreachable), LimitMeter should still show Claude 5hr/7D from a **local cache** fed by Claude Code’s statusline — the same `rate_limits` numbers the statusline already receives (not JSONL token estimates).

## Non-goals

- Do **not** estimate subscription limits from `~/.claude/projects/**/*.jsonl` or `stats-cache.json`.
- Do **not** replace the live OAuth/cookie API as the primary source when it succeeds.
- Codex is out of scope for this change.

## Approach A — Read cache on API failure

**File:** `~/.claude/usage-cache.json` (home-relative)

```json
{
  "five_hour_pct": 32,
  "five_hour_reset": 1738857600,
  "seven_day_pct": 5,
  "seven_day_reset": 1739200000,
  "updated_at": 1738800000
}
```

- `*_pct` = **used** percent 0–100 (or `null` if that window was absent).
- `*_reset` = Unix epoch seconds (or `null`).
- `updated_at` = Unix epoch when the statusline last wrote the file.

**Freshness:** accept if `updated_at` is within the last **6 hours** and at least one of `five_hour_pct` / `seven_day_pct` is non-null.

**Conversion:** `remaining = 100 - used` (same as live API path).

**When to use:** Claude live fetch fails with rate-limit, 5xx, transport/offline, or timeout — **not** on 401/403 (`needsAuth`). Prefer cache over empty/`preservingLastKnown` alone when cache is fresh.

**UI:** `ProviderUsage.dataSource = .localCache` → caption *“From Claude Code cache”* (secondary). Menu bar still shows remaining % normally.

## Approach B — Tiny statusline helper

Ship:

| Script | Role |
|--------|------|
| `scripts/claude-write-usage-cache.sh` | Read statusline JSON on stdin → write `usage-cache.json` → pass JSON through on stdout |
| `scripts/install-claude-usage-cache.sh` | Install writer to `~/.claude/limitmeter-write-usage-cache.sh` and wrap `statusLine.command` in `~/.claude/settings.json` |

Wrap pattern:

```text
~/.claude/limitmeter-write-usage-cache.sh | <existing command>
```

- Backup `settings.json` before edit.
- Idempotent: skip if command already contains `limitmeter-write-usage-cache`.
- If no `statusLine` exists, set command to writer only plus a minimal one-line printer of 5hr/7D remaining (so stock users get something).

Writer field mapping (from stdin `rate_limits`):

- `five_hour.used_percentage` → `five_hour_pct`
- `five_hour.resets_at` → `five_hour_reset`
- same for `seven_day`
- `updated_at` = now

Only rewrite the cache when at least one window is present (match existing statusline behavior).

## Architecture touchpoints

```
ClaudeUsageClient.fetch
  → live OAuth/cookie
  → on retriable failure: ClaudeUsageCache.load()
  → ProviderUsage(.ok, dataSource: .localCache) or original error
```

New types: `UsageDataSource` on `ProviderUsage`; `ClaudeUsageCache` in `LimitMeter/Auth/` or `Providers/`.

## Testing

- Unit tests for cache parse, used→remaining, freshness reject, null windows.
- No network tests required for B (shell script smoke optional).

## Docs

- `docs/architecture.md` — fallback + install script
- `README.md` — short “Claude Code cache” setup for rate limits
