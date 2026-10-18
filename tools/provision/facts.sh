#!/usr/bin/env bash
# Read-only host report for an OCI A1 VM (P0-09; PR-8; benchmark-methodology.md §4.1).
# Changes nothing. Prints no IP addresses, hostnames or user names, so the
# output is safe to paste into an issue or a chat.
#
# Usage (from the dev machine):  ssh <host> 'bash -s' < tools/provision/facts.sh
set -uo pipefail

section() { printf '\n== %s ==\n' "$1"; }
val() { printf '%-22s %s\n' "$1" "$2"; }
readf() { [ -r "$1" ] && tr -d '\n' < "$1" || echo "n/a"; }

section "os"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  val distro "${ID:-?} ${VERSION_ID:-?} (${PRETTY_NAME:-?})"
fi
val kernel "$(uname -r)"
val arch "$(uname -m)"
val role "$(readf /etc/pini-role)"

section "cpu"
val nproc "$(nproc)"
lscpu 2>/dev/null | grep -E '^(Model name|Vendor ID|CPU\(s\)|Thread\(s\) per core|NUMA node\(s\)|L[123]d? cache)' || echo "lscpu n/a"
freq="$(ls /sys/devices/system/cpu/cpu0/cpufreq 2>/dev/null | tr '\n' ' ')"
val cpufreq "${freq:-not exposed}"

section "memory"
grep -E '^(MemTotal|SwapTotal):' /proc/meminfo
val swap_devices "$(swapon --noheadings --show=NAME,SIZE 2>/dev/null | tr '\n' ';' || true)"
val thp_enabled "$(readf /sys/kernel/mm/transparent_hugepage/enabled)"
val thp_defrag "$(readf /sys/kernel/mm/transparent_hugepage/defrag)"

section "disk"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null
df -h / /srv 2>/dev/null | sort -u

section "kernel features (PR-8)"
cgfs="$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo '?')"
val cgroup_fs "$cgfs $( [ "$cgfs" = cgroup2fs ] && echo '(v2 OK)' || echo '(NOT v2)')"
val cgroup_controllers "$(readf /sys/fs/cgroup/cgroup.controllers)"
# memory.peak is per-cgroup and only exists below the root (kernel >= 5.19).
peak="missing"; for f in /sys/fs/cgroup/*/memory.peak; do [ -e "$f" ] && peak="present" && break; done
val memory.peak "$peak"
val smaps_rollup "$( [ -r /proc/self/smaps_rollup ] && echo present || echo missing)"
val perf_event_paranoid "$(readf /proc/sys/kernel/perf_event_paranoid)"

section "tools"
for t in podman docker git gpg gpgv curl jq tar xz python3 sha256sum; do
  if command -v "$t" >/dev/null 2>&1; then
    val "$t" "$("$t" --version 2>&1 | head -n1)"
  else
    val "$t" "MISSING"
  fi
done

section "services"
val running_units "$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l | tr -d ' ')"
systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print "  " $1}'
val loadavg "$(readf /proc/loadavg)"
