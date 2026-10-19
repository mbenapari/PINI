# PINI — Progress

| | |
|---|---|
| **Doc #** | 10 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Current phase** | **Phase 0: Foundation, in progress** |
| **Last updated** | 2026-10-18 |
| **Plan reference** | Task IDs refer to [project-plan.md](project-plan.md) Part B |

---

## Status at a glance

| Phase | State | Exit criterion met? |
|---|---|---|
| 0 Foundation | In progress | No |
| 1 Upstream baseline | Not started (waiting on the v26 LTS release, ≥ 2026-10-28, and OCI A1 provisioning) | — |
| 2–8 | Not started | — |

## Done

- 2026-10-12: Charter `docs/vision.md` rewritten (owner).
- 2026-10-12: Full pre-code doc set drafted: architecture, memory-strategy, benchmark-methodology, compatibility-matrix, security-policy, test-strategy, deployment, release-process, decision-log, project-plan, progress, context, `upstream/version-lock.md`, root README/SECURITY/CONTRIBUTING stubs. **Approved 2026-10-12 (P0-01 done).**
- 2026-10-12: Upstream facts verified and recorded (release schedule, V8 versions, toolchains, configure flags, tarball contents/hash for v26.11.1). Ledger in architecture.md §9 and version-lock.md §2.

- 2026-10-12: **Owner decisions accepted and applied across the docs:**
  - **D-01:** MIT + DCO.
  - **D-03:** first v26 LTS release; v24 fallback only.
  - **D-04:** no budget. OCI Always Free Ampere A1 (arm64, 4 OCPU / 24 GB total) is the build and benchmark host, so arm64 comes first. x64 builds and tests run on free GitHub Actions, with limited private-repo minutes.
  - **D-05:** solo developer. Reproduction = clean-VM rebuild + checksum comparison. Patch review = cooling-off self-review + code-reviewer agent + full test tier.
  - **D-06:** accepted as proposed.
  - **D-07:** private repo and private results. **Amended 2026-10-13:** repo public (free plans cannot protect private branches).
  - **D-02:** security contact <afa.hamdu@gmail.com>.
  - **OCI:** A1 capacity confirmed. The owner has provisioned two 2 OCPU / 12 GB VMs (SUT + load generator).

## In progress

- **P0-10 (started 2026-10-18 13:33 UTC):** `stock` build of v26.11.1 **finished** on vm2 at `-j2` (exit 0, ended 18:06 UTC), in a container limited to 10 GB RAM / 2 CPUs. State and logs are in `/srv/pini/out/p0-10/` on vm2. Check with `tools/build/dryrun-status.sh <ssh-alias> 2`. Done so far: tarball SHA-256 matches the value recorded in `version-lock.md`; `SHASUMS256.txt.sig` has a good `gpgv` signature from `5BE8A3F6C8A5C01D106C0AD820B1A390B168D356` (key from `nodejs/release-keys` at `481637f8…`, fingerprint also in the v26.11.1 README); candidate image `tools/build/Dockerfile.builder` (AlmaLinux 8) built in 146 s. **Deviation:** AlmaLinux 8 offers Clang 21.1.8 only, not upstream's 20.1 (CD-5). Packages found: gcc-toolset-14 libatomic, Python 3.12, Rust 1.92. `session.sh begin` was run on vm2; run `end` when finished. **Result (-j2):** `make` 16,333 s (4 h 32 min), configure 3 s; container peak RAM 3.76 GiB (`memory.peak` 4,039,204,864 B; PR-2 at -j2 answered); source tree after build 2.4 GB; `out/Release/node` 150 MB; the produced binary runs and reports node 26.11.1 / V8 14.6.202.34-node.37. Toolchain: Clang/LLD 21.1.8, GCC 14.2.1 (gcc-toolset-14), Python 3.12.15, Rust/Cargo 1.92.0, glibc 2.28 (el8). PR-1 answered with the Clang 21.1.8 deviation above. **Result (-j4):** run 2026-10-18 18:47–23:37 UTC, exit 0; `make` 17,387 s (4 h 50 min), configure 2 s; container peak RAM 4.97 GiB; `out/Release/node` 150 MB. Slower than -j2 (4 h 32 min) and about 1.2 GiB higher peak, because the VM has 2 cores and the container is `--cpus 2`, so -j4 oversubscribes rather than adds parallelism. Single run each. To do: PR-4 network-off rerun, then `session.sh end`. Also done 2026-10-18: P0-09 (`tools/provision/`: `facts.sh` read-only host report, idempotent `setup.sh sut|loadgen`, `session.sh begin|end` to quiet services for benchmark sessions; vm2 = SUT and build host, vm1 = load generator with the owner's nginx; both on Ubuntu 24.04.5 / kernel 7.0.0-1013-oracle, cgroup v2 + `memory.peak` + `smaps_rollup` present, so PR-8 is resolved; both VMs had a ~115-day hung `apt-get update` blocking security updates, fixed). Done 2026-10-14: P0-08 (T0 `dependency-review` job using `actions/dependency-review-action` v5.0.0, fails on moderate+ advisories, PR-only; SEC-AC-3), P0-06 (`.github/workflows/t0.yml`: markdownlint, offline internal link + anchor check with lychee, action SHA-pin check; all required on `main` with `dco`). Done 2026-10-13: P0-05 (public repo github.com/mbenapari/PINI; `main` protected: PR required, `dco` check required and strict, no force-push or deletion), P0-04 (MIT `LICENSE`; DCO check `tools/ci/check-dco.sh` + `.github/workflows/dco.yml`, verified on existing history and against an unsigned commit), P0-02 (`git init` on `main`, charter §15 skeleton, `.gitignore`, `artifacts/README.md`, `CHANGELOG.md`; commit 02d5e01) and P0-03 (README layout table, SECURITY report contents, CONTRIBUTING changelog/results rules, section anchors).

## Blockers / waiting on

| Item | Waiting on | Blocks |
|---|---|---|
| v26 LTS release (expected 2026-10-28) | Upstream | P1-01 |

## Next (in order)

1. ~~P0-02 `git init` + skeleton~~ (done 2026-10-13); ~~P0-04 MIT `LICENSE`~~ (done 2026-10-13); ~~P0-05 repo~~ (done 2026-10-13, public); ~~P0-06 T0 CI~~ (done 2026-10-14); ~~P0-08 dependency scanning~~ (done 2026-10-14).
2. P0-11: dev-machine hygiene (update Node, install gpg). Owner runs it locally.
3. ~~P0-09: script provisioning of the two existing VMs~~ (done 2026-10-18).
4. P0-10: riskiest-first arm64 build dry run of v26.11.1 on A1.
5. P0-12: OCI noise probe (A/A on the two-VM layout).

## Measurements

No benchmark has been run, and no memory claim exists. Build-only measurement (P0-10, OCI A1 2 OCPU / 12 GB, `stock`, v26.11.1, container limited to 10 GB / 2 CPUs): `-j2` took 4 h 32 min with a 3.76 GiB peak; `-j4` took 4 h 50 min with a 4.97 GiB peak. Single run, so no variance is known.
