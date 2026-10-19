#!/usr/bin/env bash
# Report P0-10 dry-run progress. Run from the dev machine. Usage: dryrun-status.sh <ssh-alias> [jobs]
set -euo pipefail
HOST="${1:?ssh alias of the build VM}"; JOBS="${2:-2}"
ssh -o BatchMode=yes "$HOST" bash -s -- "$JOBS" <<'REMOTE'
J=$1; O=/srv/pini/out/p0-10
echo "== status-j$J"; cat $O/status-j$J 2>/dev/null || echo "(none)"
echo "== now $(date -u +%FT%TZ)"
echo "== container"; docker ps -a --filter name=pini-p0-10-j$J --format '{{.Names}} {{.Status}}'
echo "== peak RAM (GiB so far)"; awk '{printf "%.2f\n",$1/2^30}' $O/memory.peak-j$J 2>/dev/null || echo n/a
echo "== load / mem"; uptime; free -m | sed -n 2p; df -h /srv | tail -1
echo "== timing"; cat $O/work-j$J/timing.txt 2>/dev/null || echo "(not yet)"
echo "== log tail"; tail -n 8 $O/build-j$J.log 2>/dev/null
REMOTE
