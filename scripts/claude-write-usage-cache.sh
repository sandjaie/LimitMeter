#!/usr/bin/env bash
# Read Claude Code statusline JSON on stdin, merge rate_limits into
# ~/.claude/usage-cache.json, then pass the JSON through on stdout.
#
# Merge rules: never overwrite a known window with null/empty from a partial
# statusline tick (Claude often omits five_hour until the first reply).
# Drop a retained window once its reset timestamp is in the past.
#
# Wire into settings.json statusLine.command, e.g.:
#   ~/.claude/limitmeter-write-usage-cache.sh | ~/.claude/statusline-command.sh
#
# Requires: jq
set -euo pipefail

input="$(cat)"
cache="${HOME}/.claude/usage-cache.json"
mkdir -p "$(dirname "$cache")"

five_hour="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')"
five_hour_reset="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')"
seven_day="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')"
seven_day_reset="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')"
now_ts="$(date +%s)"

if [[ -n "$five_hour" || -n "$seven_day" || -f "$cache" ]]; then
  existing="{}"
  if [[ -f "$cache" ]]; then
    existing="$(cat "$cache" 2>/dev/null || echo '{}')"
  fi
  tmp="${cache}.tmp.$$"
  jq -n \
    --argjson existing "${existing}" \
    --argjson fh "${five_hour:-null}" \
    --argjson fhr "${five_hour_reset:-null}" \
    --argjson sd "${seven_day:-null}" \
    --argjson sdr "${seven_day_reset:-null}" \
    --argjson up "$now_ts" \
    '
    def keep($new; $new_reset; $old; $old_reset):
      if $new != null then
        {pct: $new, reset: $new_reset}
      elif ($old != null) and (($old_reset == null) or ($old_reset > $up)) then
        {pct: $old, reset: $old_reset}
      else
        {pct: null, reset: null}
      end;

    (keep($fh; $fhr; $existing.five_hour_pct; $existing.five_hour_reset)) as $five
    | (keep($sd; $sdr; $existing.seven_day_pct; $existing.seven_day_reset)) as $seven
    | select(($five.pct != null) or ($seven.pct != null))
    | {
        five_hour_pct: $five.pct,
        five_hour_reset: $five.reset,
        seven_day_pct: $seven.pct,
        seven_day_reset: $seven.reset,
        updated_at: $up
      }
    ' >"$tmp" 2>/dev/null && mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi

printf '%s' "$input"
