#!/usr/bin/env bash
# Read Claude Code statusline JSON on stdin, persist rate_limits to
# ~/.claude/usage-cache.json, then pass the JSON through on stdout.
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

# Only write when at least one window is present (never clobber with blanks).
if [[ -n "$five_hour" || -n "$seven_day" ]]; then
  tmp="${cache}.tmp.$$"
  jq -n \
    --argjson fh "${five_hour:-null}" \
    --argjson fhr "${five_hour_reset:-null}" \
    --argjson sd "${seven_day:-null}" \
    --argjson sdr "${seven_day_reset:-null}" \
    --argjson up "$now_ts" \
    '{five_hour_pct:$fh, five_hour_reset:$fhr, seven_day_pct:$sd, seven_day_reset:$sdr, updated_at:$up}' \
    >"$tmp" 2>/dev/null && mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
fi

printf '%s' "$input"
