# tools/provision

Scripted setup of the OCI Always Free A1 VMs (P0-09; ADR-0004, ADR-0007). The VMs are disposable, because Oracle may reclaim idle Always Free compute ([benchmark-methodology.md §4.1](../../docs/benchmark-methodology.md#41-environment-control-benchmark-host-adr-0007)). These scripts rebuild a usable host from a fresh image.

All scripts are run from the dev machine over SSH. Nothing in this repo stores host addresses, user names, or keys: the repo is public. Keep those in your own `~/.ssh/config`.

| Script | Changes the host? | Purpose |
|---|---|---|
| `facts.sh` | No | Host report: OS, CPU, memory, swap/THP, disk, cgroup v2, `memory.peak`, `smaps_rollup`, tools, running services. Prints no IPs or names |
| `setup.sh sut\|loadgen` | Yes, idempotent | Base tools; uses the existing Docker, else installs Podman; creates `/srv/pini/{src,out,ccache,results,images}`; writes `/etc/pini-role` and `/etc/pini-runtime` |
| `session.sh begin\|end` | Yes, temporary | Stops noisy services for a benchmark session and restarts exactly those afterwards |

## Layout

Two VMs, 2 OCPU / 12 GB each, same availability domain, private network (layout accepted 2026-10-12):

| Role | VM | Notes |
|---|---|---|
| `sut` | vm2 | Runs the server under test. Also the build host; never benchmark while building |
| `loadgen` | vm1 | Runs the load generator. Also hosts the owner's nginx apps, stopped during sessions |

## Fresh VM

```sh
ssh <host> 'sudo bash -s -- sut' < tools/provision/setup.sh   # or loadgen
ssh <host> 'bash -s' < tools/provision/facts.sh
```

## Benchmark session

Run `begin` on **both** VMs before a session and `end` on both after it:

```sh
ssh <host> 'sudo bash -s -- begin' < tools/provision/session.sh
# ... run the session; copy results off the VM ...
ssh <host> 'sudo bash -s -- end' < tools/provision/session.sh
```

`begin` stops whichever of these are active: `nginx`, `unattended-upgrades` and the apt timers, `unified-monitoring-agent`, `ModemManager`, `snapd`. Units are stopped, never disabled, so a reboot also restores them. The Oracle Cloud agent is left running, because it is needed to manage the instance.

## Host facts (recorded 2026-10-18)

Both VMs: aarch64, 2 × Neoverse-N1, 12 GB RAM, no swap, THP `madvise`, 100 GB boot volume (ext4 on `/`), `cpufreq` not exposed, Ubuntu 24.04.

| | vm2 (`sut`) | vm1 (`loadgen`) |
|---|---|---|
| OS / kernel | Ubuntu 24.04.5 / 7.0.0-1013-oracle | Ubuntu 24.04.5 / 7.0.0-1013-oracle |
| Docker | 29.9.1 | not recorded since upgrade (29.4.1 before) |
| cgroup v2, `memory.peak`, `smaps_rollup` | present (re-checked on 7.0) | present (checked on 6.17) |
| `perf_event_paranoid` | 4 (unprivileged `perf` blocked; samplers do not need it) | 4 |

Every benchmark result records the kernel and runtime versions itself (doc 02 §4.1), so this table is a snapshot, not the record.

## Known issues found during provisioning

- Both VMs had an `apt-get -qq -y update` hung for about 115 days. It held the apt lock, so `unattended-upgrades` never ran and neither VM got security updates in that time. Fixed 2026-10-17/18 by killing it, letting the upgrades run, `apt-get upgrade`, and rebooting. If `setup.sh` waits on a lock holder for a long time, check its age with `ps -o pid,etime,cmd -p <pid>`.
- Ubuntu's `unattended-upgrade-shutdown --wait-for-signal` daemon always runs and has the same short name as an active upgrade. Check lock holders with `fuser`, not process names.
