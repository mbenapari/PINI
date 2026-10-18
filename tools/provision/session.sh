#!/usr/bin/env bash
# Quiet a VM for a benchmark session and restore it afterwards
# (benchmark-methodology.md §4.1 "no unrelated services"; P0-09).
#
# begin: stops the noisy units below that are currently active, and records
#        which ones in /run/pini-session-stopped.
# end:   starts exactly the recorded units again.
# Units are stopped, never disabled or masked, so a reboot also restores them.
#
# Usage: ssh <host> 'sudo bash -s -- begin' < tools/provision/session.sh
#        ssh <host> 'sudo bash -s -- end'   < tools/provision/session.sh
set -euo pipefail

state=/run/pini-session-stopped
units="nginx.service unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer
unified-monitoring-agent.service ModemManager.service snapd.service snapd.socket"

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)" >&2; exit 2; }

case "${1:-}" in
  begin)
    [ -e "$state" ] && { echo "session already begun (see $state); run end first" >&2; exit 1; }
    stopped=""
    for u in $units; do
      if systemctl is-active --quiet "$u"; then
        systemctl stop "$u"
        stopped="$stopped $u"
      fi
    done
    echo "$stopped" > "$state"
    echo "[session] stopped:${stopped:- nothing}"
    echo "[session] loadavg: $(cat /proc/loadavg)"
    ;;
  end)
    [ -e "$state" ] || { echo "no session in progress" >&2; exit 1; }
    for u in $(cat "$state"); do
      systemctl start "$u" || echo "warning: failed to start $u" >&2
    done
    echo "[session] restarted: $(cat "$state")"
    rm -f "$state"
    ;;
  *)
    echo "usage: session.sh begin|end" >&2; exit 2 ;;
esac
