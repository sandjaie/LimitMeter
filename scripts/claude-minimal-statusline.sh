#!/usr/bin/env bash
# Minimal statusline printer (used when no existing statusLine.command).
# Expects Claude Code statusline JSON on stdin.
set -euo pipefail

input="$(cat)"
five="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')"
seven="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')"

out=""
if [[ -n "$five" ]]; then
  left="$(awk -v u="$five" 'BEGIN { printf "%d", 100 - u }')"
  out="5hr: ${left}% left"
fi
if [[ -n "$seven" ]]; then
  left="$(awk -v u="$seven" 'BEGIN { printf "%d", 100 - u }')"
  if [[ -n "$out" ]]; then
    out="${out} · 7D: ${left}% left"
  else
    out="7D: ${left}% left"
  fi
fi

if [[ -n "$out" ]]; then
  printf '%s\n' "$out"
else
  printf '%s\n' "LimitMeter cache ready"
fi
