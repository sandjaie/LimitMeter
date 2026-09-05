#!/usr/bin/env bash
# Install LimitMeter's Claude Code statusline cache writer (Approach B).
# Idempotent. Backs up ~/.claude/settings.json before editing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
WRITER_SRC="${ROOT}/scripts/claude-write-usage-cache.sh"
MINIMAL_SRC="${ROOT}/scripts/claude-minimal-statusline.sh"
WRITER_DST="${CLAUDE_DIR}/limitmeter-write-usage-cache.sh"
MINIMAL_DST="${CLAUDE_DIR}/limitmeter-minimal-statusline.sh"
MARKER="limitmeter-write-usage-cache"

if ! command -v jq >/dev/null; then
  echo "error: jq is required (brew install jq)" >&2
  exit 1
fi

mkdir -p "${CLAUDE_DIR}"
cp "${WRITER_SRC}" "${WRITER_DST}"
cp "${MINIMAL_SRC}" "${MINIMAL_DST}"
chmod +x "${WRITER_DST}" "${MINIMAL_DST}"

if [[ ! -f "${SETTINGS}" ]]; then
  cat >"${SETTINGS}" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "${WRITER_DST} | ${MINIMAL_DST}"
  }
}
EOF
  echo "OK: created ${SETTINGS} with LimitMeter statusLine"
  echo "Open Claude Code once so rate_limits populate ~/.claude/usage-cache.json"
  exit 0
fi

backup="${SETTINGS}.bak.limitmeter.$(date +%Y%m%d%H%M%S)"
cp "${SETTINGS}" "${backup}"
echo "Backup: ${backup}"

existing="$(jq -r '.statusLine.command // empty' "${SETTINGS}")"

if [[ -n "${existing}" && "${existing}" == *"${MARKER}"* ]]; then
  echo "OK: statusLine already wraps LimitMeter cache writer"
  echo "Writer: ${WRITER_DST}"
  exit 0
fi

if [[ -n "${existing}" ]]; then
  # Wrap existing command: writer | original
  new_cmd="${WRITER_DST} | ${existing}"
else
  new_cmd="${WRITER_DST} | ${MINIMAL_DST}"
fi

tmp="$(mktemp)"
jq --arg cmd "${new_cmd}" '
  .statusLine = ((.statusLine // {}) + {type: "command", command: $cmd})
' "${SETTINGS}" >"${tmp}"
mv "${tmp}" "${SETTINGS}"

echo "OK: statusLine.command = ${new_cmd}"
echo "Open Claude Code (and send one message if needed) so rate_limits appear."
echo "Cache file: ${CLAUDE_DIR}/usage-cache.json"
