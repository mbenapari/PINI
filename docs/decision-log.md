# PINI — Decision Log

| | |
|---|---|
| **Status** | Live document. ADR-0001 is accepted (locked). ADR-0003, ADR-0007 and ADR-0011, plus D-02, were **accepted 2026-10-12** by owner decision. The rest are drafts pending review. |
| **Doc #** | 08 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Format** | Nygard-style ADRs (context, decision, status, consequences), extended MADR-style with *options considered* and *revisit when* where there are live alternatives. Charter §14.2 requires problem, options, chosen direction, reasoning, trade-offs, and revisit conditions. |
| **Rules** | ADRs are never deleted. A superseded ADR is marked `Superseded by ADR-NNNN`. Resolved open questions are struck through with **resolved (date)**, not removed. |

---

## Index

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](#adr-0001--downstream-nodejs-distribution-on-bundled-v8) | Downstream Node.js distribution on bundled V8 | **Accepted (locked)** | charter |
| [0002](#adr-0002--upstream-source-management-verified-release-tarball--patch-series) | Upstream source management: verified release tarball + patch series | Proposed | 2026-10-12 |
| [0003](#adr-0003--nodejs-release-line-to-pin) | Node.js release line to pin | **Accepted** (D-03) | 2026-10-12 |
| [0004](#adr-0004--build-environment-and-toolchain) | Build environment and toolchain | Proposed | 2026-10-12 |
| [0005](#adr-0005--load-generator) | Load generator | Proposed | 2026-10-12 |
| [0006](#adr-0006--pointer-compression-evaluation) | Pointer-compression evaluation | Proposed | 2026-10-12 |
| [0007](#adr-0007--ci-and-benchmark-infrastructure) | CI and benchmark infrastructure | **Accepted** (D-04): OCI Always Free arm64 + GitHub Actions | 2026-10-12 |
| [0008](#adr-0008--pini-self-identification-mechanism) | PINI self-identification mechanism | Open | 2026-10-12 |
| [0009](#adr-0009--release-signing-and-provenance) | Release signing and provenance | Open | 2026-10-12 |
| [0010](#adr-0010--project-tooling-runtime-and-package-manager) | Project tooling runtime and package manager | Proposed | 2026-10-12 |
| [0011](#adr-0011--pini-license) | PINI license | **Accepted** (D-01): MIT + DCO | 2026-10-12 |

---

## ADR-0001 — Downstream Node.js distribution on bundled V8

**Status:** Accepted, locked (vision.md §6.1). **Decision:** PINI is a downstream distribution of Node.js, using the V8 bundled with that Node.js release. There is no new engine and no replacement GC. PINI owns build, configuration, defaults, diagnostics, patches, tests, benchmarks, and releases. **Consequences:** every PINI change must be a build flag, a runtime flag, tooling, or a small reviewed patch (architecture.md CD-1). **Revisit:** only with a written rationale and an impact assessment on completed work (charter §14.2).

---

## ADR-0002 — Upstream source management: verified release tarball + patch series

**Context.** Charter §15 leaves the mechanism open ("submodule, fetch-and-verify script, or similar") and forbids vendoring the full tree unless needed.

**Options considered.**

| Option | Pros | Cons |
|---|---|---|
| **A. Fetch official `.tar.xz` + verify `SHASUMS256.txt.asc` (gpgv, `nodejs/release-keys`) + SHA-256 lock; patches as files + series** | Builds exactly the artifact upstream signs. Small (~63 MB for v26.11.1 vs ~1.6 GB repo per GitHub API). Lock hash = build input. Patches are reviewable diffs (charter §5.3) | No upstream git history locally. V8's own tests absent from tarball (verified) |
| B. Git submodule of `nodejs/node` pinned to a tag | History available; `git am` natural | Large; submodule friction; tag→commit trust needs separate verification |
| C. Fork `nodejs/node`, PINI branch with patches as commits | Familiar | Patches hidden in history; rebase cost grows; charter prefers minimal visible divergence |
| D. Vendor tree in repo | Hermetic | Explicitly discouraged by charter §15 |

**Decision (proposed).** Option A. The fetch script (`tools/build/`) downloads into a scratch dir, verifies (doc 04 §2), extracts, runs `git init` + an initial commit in the scratch tree, and applies `patches/node/series` in order with `git apply --index` (or `git am` for mailbox-format patches), so patch application is checkable. For investigation work, maintainers may keep a local clone of `nodejs/node` at the matching tag. That clone is a workbench, never a build input.

**Consequences.** UP-AC-1/2 (doc 04). V8 tests for any future V8 patch come from a pinned V8 checkout matching `deps/v8` (doc 09 PR-6).

**Revisit when** the patch count makes series management painful (proposed trigger: more than 15 patches), or when upstream changes how tarballs are signed.

---

## ADR-0003 — Node.js release line to pin

**Context.** Charter §6.2: "an actively supported LTS line, pinned exactly". Verified schedule on 2026-10-12 (nodejs/Release `schedule.json`): 24.x Active LTS → Maintenance on **2026-10-20**, EOL **2028-04-30**. 26.x Current → Active LTS on **2026-10-28**, Maintenance 2027-10-20, EOL **2029-04-30**. 22.x Maintenance, EOL 2027-04-30. Upstream announced (2026-03-10) that from v27 there is one major per year and every major becomes LTS. v26 is the last line under the old model.

**Options considered.**

| | v26 LTS (first LTS-designated v26.x) | v24 LTS (latest, v24.21.0 today) |
|---|---|---|
| Support runway from today | ~30.5 months (EOL 2029-04-30) | ~18.5 months (EOL 2028-04-30) |
| Phase on pin | Active LTS until 2027-10-20 | Maintenance from 2026-10-20 (critical fixes and security only) |
| Bundled V8 | 14.6.x (14.6.202.34 in v26.11.1) | 13.6.233.17 |
| Allocation metric | `v8.getHeapStatistics().total_allocated_bytes` (documented) | not available |
| Heap profiling APIs | adds `v8.startHeapProfile()` (v26.1.0) | — |
| Build prereqs | GCC ≥ 13.2 / Clang ≥ 19.1; Python 3.10–3.14; Rust ≥ 1.86 for Temporal; `libatomic` at runtime | GCC ≥ 12.2; Python 3.9+ accepted by `configure`; no Rust |
| Ecosystem maturity | Newer; native prebuilds for ABI 147 may lag (*assumption*) | Mature, ABI 137 widely prebuilt (*assumption*) |
| Forced line migration before 1.0? | Unlikely | Likely (EOL 2028-04) |
| Available today as LTS? | No (16 days) | Yes |

**Status: Accepted 2026-10-12 (owner decision D-03).** v24 is a fallback only.

**Decision.** Pin **v26**, using the **first release that carries the LTS designation** (expected 2026-10-28 as a semver-minor; exact version unknown today). Phase 0 work and build dry-runs may use v26.11.1, but it is *not* the Phase 1 pin, because it is a Current release.

**Fallback.** If v26's LTS promotion slips, or Phase 1 hits a blocking defect specific to v26, pin the then-latest v24.x and plan the migration to the next LTS as Phase 2/3 work.

**Consequences.** Heavier toolchain (ADR-0004). Temporal must be explicitly enabled (architecture.md §6). Diagnostics may rely on `total_allocated_bytes`, but must degrade gracefully (doc 01 DG-AC-1).

**Revisit when** (a) v26 LTS has not shipped by 2026-11-30, (b) a v26-specific blocker appears, or (c) planning for the line migration starts (2027-10-20).

---

## ADR-0004 — Build environment and toolchain

**Context.** Reproducible builds (charter §8.3) and clean comparisons (architecture.md CD-5). Docker is not installed on the dev machine, and the dev machine is macOS.

**Decision (proposed).** Build inside an OCI image based on a **RHEL 8-compatible distribution** (glibc 2.28), with **Clang 20.1** and `gcc-toolset-14-libatomic-devel`. This is the configuration upstream uses for official v26 linux-x64/arm64 binaries (v26.11.1 `BUILDING.md`). Add Python 3.11+, a pinned Rust toolchain (≥ 1.86), GNU Make, and optionally ninja (`configure --ninja` verified) and ccache. The image is referenced by digest. It runs under Docker or Podman on a Linux host. *Exact base image (e.g. a specific RHEL 8 rebuild/UBI 8) and package availability of Clang 20.1 there: unverified; that is Phase 1 task P1-02.*

**Options considered.** Ubuntu LTS with distro GCC 13: simpler, but a newer glibc floor makes binaries incompatible with RHEL 8-class hosts, and the toolchain differs from upstream's. Nix (`shell.nix` exists upstream): hermetic, but a learning cost and a different toolchain from upstream releases.

**arm64 note (D-04).** The first build target is Linux arm64 on OCI Ampere A1. Upstream builds official linux-arm64 binaries with the same RHEL 8 + Clang 20.1 setup, so the toolchain decision is unchanged. The x64 build runs on GitHub Actions hosted runners using the same image definition.

**Consequences.** Build host memory: upstream says "at least 8GB of RAM is typically required when compiling with 4 parallel jobs". The dev Mac is not a build host of record.

**Revisit when** upstream changes its official toolchain (check at every line migration).

---

## ADR-0005 — Load generator

**Decision (proposed).** **oha** primary, **k6** fallback. Full rationale in benchmark-methodology.md §9: fixed-rate `-q` with `--latency-correction`, JSON output with schema, not Node-based. Rejected: autocannon, wrk, wrk2 (reasons there). **Revisit when** oha maintenance lapses (no release in 12 months), or when a workload needs scripted multi-step sessions (then use k6 for that workload only and record it).

---

## ADR-0006 — Pointer-compression evaluation

**Context.** Charter §6.3 lists it. Verified: official v24.21.0/v26.11.1 builds have `v8_enable_pointer_compression: 0`. The `configure` help says "[Experimental] Enable V8 pointer compression (limits max heap to 4GB and breaks ABI compatibility)". `--experimental-pointer-compression-shared-cage` additionally enables the V8 sandbox. V8 reported "up to 43%" heap reduction in Chrome (v8.dev, 2020), which is not evidence for Node server workloads.

**Decision (proposed).** Evaluate only in **Phase 4** as flavor `pini-exp-ptrcomp` (matrix row M4), not earlier. Measure W0–W5 plus the doc 03 §4 add-on set. It can never become the default flavor without a separate ADR that accepts: the 4 GiB heap cap, a separate artifact name, a compatibility event in release notes, and add-on evidence. The shared-cage/sandbox variant is a second, separate experiment.

**Revisit when** upstream Node changes the default, or Phase 4 results come in.

---

## ADR-0007 — CI and benchmark infrastructure

**Status: Accepted 2026-10-12 (owner decision D-04: there is no money budget).**

**Decision.**
- **arm64 build and benchmark host of record: Oracle Cloud Infrastructure (OCI) Always Free, Ampere A1.** The owner-supplied allocation is 4 OCPU / 24 GB in total.
  - **Chosen layout (accepted 2026-10-12, already provisioned by the owner): two VMs of 2 OCPU / 12 GB**, one as the system under test (SUT) and one as the load generator, in the same availability domain on a private network.
  - The single 4-OCPU VM option is not used. Builds run on one of the 2 OCPU / 12 GB VMs (preferably the load-generator VM, never during a benchmark session), with ccache.
  - **Linux arm64 is therefore the first build and benchmark target** (architecture.md CD-9).
- **x64 and CI: GitHub Actions hosted runners** (free tier).
  - T0 runs on every PR.
  - x64 `stock`/`pini` builds and T1 run where minutes allow.
  - **Caveat: private repositories have a limited monthly allowance of free Actions minutes** (*exact allowance per GitHub's current plan terms, not verified here*), and a Node build is long. Ration minutes: path filters, ccache, nightly instead of per-PR heavy jobs, T2 on the OCI VM.
  - x64 is not benchmarked for the record.
- The OCI VM may run a **self-hosted runner** for arm64 builds and T2 (doc 04 §6: only maintainer-approved refs).

**Caveats** (details in benchmark-methodology.md §4.1):
- Noise from shared hardware: n=20, interleaving, a same-session A/A run, compare only within one host.
- Oracle's idle-instance reclamation: treat VMs as disposable, script provisioning, copy results off the VM.
- Slow builds on 2–4 OCPU (≥ 8 GB RAM for `-j4` per upstream): use ccache, and never build and benchmark at the same time.
- Limited block-storage quota: prune old builds and images.
- These resource figures were supplied by the owner and not re-verified against Oracle's terms.

**Revisit (OCI is insufficient) when any of these happen:**
- The same-session A/A spread after n=20 is too wide for the effects experiments care about.
- A1 capacity is repeatedly unavailable.
- Reclamation disrupts work.
- The build does not fit in RAM or disk.
- Actions minutes cannot sustain T0/T1.

Then a budget request becomes D-04b.

---

## ADR-0008 — PINI self-identification mechanism

**Context.** Charter Phase 2: PINI "identifies itself". Charter §1: apps run unchanged. Verified mechanisms: `configure --tag=<x>` turns the version into `vX.Y.Z-<x>` (a semver **pre-release**, which sorts below `vX.Y.Z`). `--release-urlbase` changes `process.release.sourceUrl`/`headersUrl`. These are built as `<urlbase>v<version>/node-v<version>-headers.tar.gz` (`src/node_metadata.cc:210–214`, v26.11.1) and only exposed when `NODE_HAS_RELEASE_URLS` is defined (`src/node_process_object.cc`). `process.release.name` comes from the compile-time define `NODE_RELEASE` (default `"node"`, `src/node_version.h`; used at `src/node_metadata.cc:204`), so changing it would be a source patch.

**Options.** (A) Side-car `pini-manifest.json` plus memory report only, with no runtime change. (B) Add `process.versions.pini` via a small Node patch. (C) `--tag`. (D) Change `process.release.name`.

**Default in effect until decided:** A. Proposed for Phase 2 evaluation: A + B, with C and D rejected unless Phase 2 tests show tools handle them. B is the first downstream patch and goes through the full patch process (doc 04 §4).

**Needs:** Phase 2 test evidence: node-gyp header resolution, `engines` checks, popular version-sniffing libraries.

---

## ADR-0009 — Release signing and provenance

**Open.** Options: (A) GPG-signed `SHASUMS256.txt.asc` like upstream (offline-verifiable; key management burden). (B) Sigstore keyless signing plus build-provenance attestations from CI OIDC (no long-lived keys; online verification ecosystem). (C) Both. **Default assumption:** decide by the end of Phase 2. Internal artifacts before that carry checksums only. **Needs sign-off:** maintainer key custody (if A or C).

---

## ADR-0010 — Project tooling runtime and package manager

**Decision (proposed).** Tooling in `tools/` is ES-module Node.js running on a pinned **upstream** Node LTS, separate from the binary under test (architecture.md CD-7). Prefer zero external deps. Where needed, use pnpm (charter §6.2) installed standalone and pinned, with lockfiles committed. Workloads in `benchmarks/` have their own lockfiles. Python is used only where upstream requires it (`configure`, `tools/test.py`).

---

## ADR-0011 — PINI license

**Status: Accepted 2026-10-12 (owner decision D-01).** PINI's own code is **MIT**. Contributions require a **DCO sign-off** (`git commit -s`). Upstream Node.js is MIT with third-party licenses bundled in its `LICENSE`, and those notices ship with every PINI binary (release-process.md §5). The `LICENSE` file was added in P0-04 (2026-10-13).

---

## Open decisions needing business/product sign-off

Each item states the default in effect and what changes if the answer differs.

| ID | Question | Default assumed | If different |
|---|---|---|---|
| ~~D-01~~ | ~~PINI license and contribution terms (ADR-0011)~~ | | **resolved (2026-10-12):** MIT + DCO |
| ~~D-02~~ | ~~Private security contact for SECURITY.md~~ | | **resolved (2026-10-12):** afa.hamdu@gmail.com |
| ~~D-03~~ | ~~Pin v26 LTS (ADR-0003) vs v24~~ | | **resolved (2026-10-12):** first v26 LTS release (on/after 2026-10-28). v24 is fallback only |
| ~~D-04~~ | ~~Benchmark host and CI budget (ADR-0007)~~ | | **resolved (2026-10-12):** no budget. OCI Always Free Ampere A1 (arm64, 4 OCPU / 24 GB total) + free GitHub Actions for x64. Insufficiency triggers are in ADR-0007 |
| ~~D-05~~ | ~~Number of maintainers / reviewers~~ | | **resolved (2026-10-12):** solo developer. Reproduction = clean-VM rebuild + checksum comparison (BLD-AC-3, BM-AC-5). Patch review = self-review after a cooling-off period + code-reviewer agent pass + full test tier (security-policy.md §4) |
| ~~D-06~~ | ~~Security response targets (doc 04 §8)~~ | | **resolved (2026-10-12):** accepted as proposed. Triage within 2 business days; High/Critical release ≤ 7 days; others ≤ 30 days |
| ~~D-07~~ | ~~Public vs private repository / results~~ | | **resolved (2026-10-12):** private repo, private results. Revisit at Phase 6 |

## Open technical questions (non-blocking; defaults in place)

| ID | Question | Default | Owner doc |
|---|---|---|---|
| Q-01 | Exact v26 LTS version and its hash | fill on 2026-10-28+ | version-lock |
| ~~Q-02~~ | ~~Results storage location~~ | **resolved (2026-10-12)** with D-07: summary JSON in the private repo `results/`; raw series off-VM / private CI artifacts | doc 02 §7 |
| Q-03 | Does an upstream line migration bump PINI minor or major? | minor, major if a guaranteed API is removed | doc 07 §1 |
| Q-04 | Upstream version in artifact filename? | no, manifest only | doc 07 §5 |
| Q-05 | Memory report transport: reuse `process.report` or own signal? | compose from `process.report` | doc 01 §7.1 |
| Q-06 | Is GC `PerformanceEntry.duration` a main-thread pause? | treat as "GC callback duration" | doc 01 §6 |
| Q-07 | Which add-ons form the T3 sample set | picked in Phase 1 | doc 03 §4 |
| Q-08 | Container base image for artifacts | decided in Phase 6 | doc 06 §1 |
