#!/usr/bin/env bash
# DCO check (ADR-0011): every non-merge commit in RANGE must carry a
# "Signed-off-by:" trailer whose email matches the commit author email.
# Usage: tools/ci/check-dco.sh <base>..<head>
set -euo pipefail

range="${1:?usage: check-dco.sh <base>..<head>}"
fail=0

for sha in $(git rev-list --no-merges "$range"); do
  author=$(git log -1 --format='%ae' "$sha")
  if ! git log -1 --format='%(trailers:key=Signed-off-by,valueonly)' "$sha" \
      | grep -qiF "<${author}>"; then
    echo "::error::$(git log -1 --format='%h %s' "$sha"): missing Signed-off-by for <${author}>"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "Fix with: git rebase --signoff <base>, then force-push."
  exit 1
fi
echo "DCO: all commits in $range are signed off."
