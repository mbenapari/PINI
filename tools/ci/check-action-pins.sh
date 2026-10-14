#!/usr/bin/env bash
# Every third-party action in .github/workflows must be pinned to a full
# 40-char commit SHA (security-policy.md §6). Local ./ actions are exempt.
set -euo pipefail

dir="${1:-.github/workflows}"
bad=$(grep -HnE '^[[:space:]-]*uses:' "$dir"/*.y*ml \
  | grep -vE 'uses:[[:space:]]*["'\'']?\./' \
  | grep -vE 'uses:[[:space:]]*["'\'']?[^@[:space:]]+@[0-9a-f]{40}([[:space:]"'\''#]|$)' || true)

if [ -n "$bad" ]; then
  echo "$bad" | sed 's/^/::error::not pinned to a commit SHA: /'
  exit 1
fi
echo "Action pins: all third-party actions are pinned by SHA."
