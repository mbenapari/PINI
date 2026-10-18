#!/usr/bin/env bash
# Idempotent provisioning of an OCI A1 VM for PINI (P0-09; ADR-0004, ADR-0007).
# The VMs are disposable (idle reclamation, benchmark-methodology.md §4.1):
# running this on a fresh image must give a usable host. Safe to re-run.
#
# Builds run inside the pinned build container (ADR-0004), so the host only
# needs a container runtime and base tools. An existing Docker is used as is;
# otherwise Podman is installed. ccache lives in /srv/pini/ccache and is
# mounted into the container.
#
# Usage (from the dev machine):
#   ssh <host> 'sudo bash -s -- sut'     < tools/provision/setup.sh
#   ssh <host> 'sudo bash -s -- loadgen' < tools/provision/setup.sh
set -euo pipefail

role="${1:-}"
case "$role" in
  sut|loadgen) ;;
  *) echo "usage: setup.sh sut|loadgen" >&2; exit 2 ;;
esac
[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)" >&2; exit 2; }
[ "$(uname -m)" = aarch64 ] || echo "warning: expected aarch64, got $(uname -m)" >&2

log() { printf '[setup] %s\n' "$*"; }

# --- packages -------------------------------------------------------------
. /etc/os-release
# Common names only; distro-specific names (xz vs xz-utils, gnupg2 vs gnupg) below.
base_pkgs="git curl jq tar python3 sysstat"
if command -v docker >/dev/null 2>&1; then
  runtime=docker
  log "runtime: existing $(docker --version)"
else
  runtime=podman
  base_pkgs="$base_pkgs podman"
fi
case "${ID}" in
  ol|rhel|centos|rocky|almalinux|fedora)
    log "dnf: installing base tools on $PRETTY_NAME"
    dnf -y -q install $base_pkgs xz gnupg2 util-linux psmisc
    ;;
  ubuntu|debian)
    log "apt: installing base tools on $PRETTY_NAME"
    export DEBIAN_FRONTEND=noninteractive
    # A fresh or idle VM is often mid unattended-upgrades; wait, don't fail.
    # Check the lock holders, not process names: the always-running
    # unattended-upgrade-shutdown daemon would match a name check forever.
    locks="/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock"
    for _ in $(seq 120); do
      fuser $locks >/dev/null 2>&1 || break
      log "waiting for apt/dpkg lock holder: $(fuser $locks 2>/dev/null | tr -s ' ')"
      sleep 10
    done
    apt_opts="-q -o DPkg::Lock::Timeout=600"
    apt-get $apt_opts update
    apt-get $apt_opts -y install $base_pkgs xz-utils gnupg gpgv util-linux psmisc
    ;;
  *)
    echo "unsupported distro: ${ID}" >&2; exit 1 ;;
esac

# --- disk layout ----------------------------------------------------------
# One tree under /srv/pini. Owned by the invoking (non-root) user so builds and
# benchmarks run unprivileged.
owner="${SUDO_USER:-root}"
for d in src out ccache results images; do
  install -d -m 0755 -o "$owner" -g "$owner" "/srv/pini/$d"
done
log "layout: /srv/pini/{src,out,ccache,results,images} owned by $owner"

# Rootless podman storage on /srv so it shares the large filesystem.
# (Docker keeps its own data-root; it is left untouched.)
if [ "$runtime" = podman ] && [ "$owner" != root ]; then
  home="$(getent passwd "$owner" | cut -d: -f6)"
  conf="$home/.config/containers/storage.conf"
  if [ ! -e "$conf" ]; then
    install -d -o "$owner" -g "$owner" "$home/.config" "$home/.config/containers"
    printf '[storage]\ndriver = "overlay"\ngraphroot = "/srv/pini/images"\n' > "$conf"
    chown "$owner:$owner" "$conf"
    log "podman storage -> /srv/pini/images"
  fi
fi
if [ "$owner" != root ]; then
  # Let the user's containers and samplers outlive the SSH session.
  loginctl enable-linger "$owner" 2>/dev/null || true
  if [ "$runtime" = docker ] && ! id -nG "$owner" | grep -qw docker; then
    echo "note: $owner is not in the docker group; use sudo docker or add it (root-equivalent)" >&2
  fi
fi

# --- role -----------------------------------------------------------------
echo "$role" > /etc/pini-role
echo "$runtime" > /etc/pini-runtime
log "role: $role, runtime: $runtime"

# --- benchmark-relevant host settings (doc 02 §4.1) -------------------------
# Not changed here, only checked: swap and THP are recorded per result, and a
# setting is changed only by a documented benchmark-session step.
if [ "$(stat -fc %T /sys/fs/cgroup)" != cgroup2fs ]; then
  echo "warning: cgroup v2 not mounted; container-limited runs need it (PR-8)" >&2
fi

log "done. Verify with: ssh <host> 'bash -s' < tools/provision/facts.sh"
