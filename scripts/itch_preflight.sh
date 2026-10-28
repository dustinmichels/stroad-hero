#!/usr/bin/env bash
# Fail fast if butler can't log in or can't reach the itch.io project.
# Without credentials butler would start an interactive login, hidden by the redirect below.
set -euo pipefail
[[ -n "${BUTLER_API_KEY:-}" || -f "$HOME/Library/Application Support/itch/butler_creds" ]] ||
  { echo "butler isn't logged in; run 'mise run itch-setup' or 'butler login' first" >&2; exit 1; }
butler status "$ITCH_TARGET" >/dev/null ||
  { echo "butler can't reach itch.io project $ITCH_TARGET" >&2; exit 1; }
