# PINI — Project Plan (risk, rollout, and pre-code implementation plan)

| | |
|---|---|
| **Status** | Approved 2026-10-12. Owner decisions D-01 to D-07 were accepted on 2026-10-12 and are applied. Living doc: update as tasks complete. Never rewrite history; strike through and annotate. |
| **Doc #** | 09 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Part A: definition of done, phase order with dependency reasoning, early technical prerequisites, risks, scope guard. Part B: ordered task breakdown per phase, traceability to acceptance criteria, go/no-go checklist |
| **Charter refs** | vision.md §5.6, §8, §9, §13, §14.4, §17 |
| **Decisions** | All sign-off items are in [decision-log.md](decision-log.md) (D-01..D-07, Q-01..Q-08). This doc references them but does not duplicate them |

---

# Part A — Risk, rollout, and scope

## 1. Definition of done (cross-cutting)

Charter §14.4 applies in full. Added for PINI:
1. **Docs stay in sync.** Any change to a flag, metric, schema, workload, or flavor updates the owning doc in the same PR (owner per architecture.md §0). The PR template has a checkbox for it.
2. **Verified, not assumed.** Any new claim about Node/V8 behavior cites the pinned source (`file:line` at the pinned tag) or a command output. Otherwise it is labelled *Assumption* (charter §14.3.5).
3. **`progress.md` updated** after meaningful work. New decisions go to `decision-log.md`.
4. **Results are reproducible.** Any number in a doc links to a `result.json` with a manifest (doc 02 §7).

## 2. Phase order and why

The charter phase order (§13) stands. What follows is the dependency reasoning, plus what must be de-risked before a phase can be estimated. Following the riskiest-assumption-first rule, the two biggest unknowns are "can we build Node 26 reproducibly on our infrastructure" and "is our benchmark host quiet enough to see anything". Both are probed in **Phase 0** (P0-10, P0-12), before Phase 1 is estimated.

| Phase | Depends on | Cannot be estimated until | Riskiest assumption probed |
|---|---|---|---|
| 0 Foundation | Doc set approved | — | Build feasibility on Linux (P0-10). Host variance (P0-12) |
| 1 Upstream baseline | Phase 0; v26 LTS released (≥ 2026-10-28); OCI A1 VMs provisioned (D-04) | P0-10 build time/RAM on A1 known; P0-12 OCI A/A CV known | OCI noise is low enough to see anything (D-04 insufficiency triggers) |
| 2 PINI distribution | Phase 1 build pipeline (P1-02..P1-06) | ADR-0008 test plan | `process.versions` transparency vs identity (ADR-0008) |
| 3 Diagnostics | Phase 1 samplers (P1-09, P1-10). Can overlap Phase 2 | GC-duration semantics (Q-06) | In-process sampler overhead acceptable (DG-AC-4) |
| 4 Config experiments | Phase 1 baseline + Phase 3 report; A/A thresholds (P4-01) | Baseline variance known | Effects are bigger than noise |
| 5 Targeted patches | Phase 4 identifies a bottleneck that config can't fix; solo review protocol (doc 04 §4, D-05) | A concrete bottleneck exists | — ("no patch warranted" is valid) |
| 6 Developer preview | Phases 2–4; signing (ADR-0009); security contact (D-02, resolved); revisit D-07 (currently private) | D-07 revisit | — |
| 7 Stable 1.0 | Phase 6 feedback | — | — |

**Exposure rings (rollout):** ring 0 = the solo maintainer only, private repo (D-05, D-07) (Phases 1–5, `development` channel). Ring 1 = invited evaluators (Phase 6, `experimental`/`release-candidate`). Ring 2 = public `stable` (Phase 7). Each ring widens only when the previous ring's exit criteria are met. For ring 1 that means: no open release-gate failures (doc 05 §6) and at least one external reproduction of a benchmark result.

## 3. Calendar anchors (external, verified 2026-10-12)

| Date | Event | Impact |
|---|---|---|
| 2026-10-20 | v24 enters Maintenance | Fallback line gets only critical/security fixes |
| 2026-10-28 | v26 → Active LTS; v27 alpha begins | Earliest Phase 1 pin date for the recommended line (Q-01) |
| 2026-11-30 | ADR-0003 revisit trigger if v26 LTS has not shipped | Switch to v24 fallback |
| 2027-04-30 | v22 EOL | none (not used) |
| 2027-10-20 | v26 enters Maintenance | Start line-migration planning (doc 07 §4) |
| 2028-04-30 | v24 EOL | Hard deadline if fallback chosen |
| 2029-04-30 | v26 EOL | Migration complete ≥ 3 months before (doc 07 §4) |

## 4. Technical prerequisites to verify early

| ID | Unknown | How to verify | Blocks |
|---|---|---|---|
| PR-1 | Can a RHEL 8-compatible image provide Clang 20.1 + gcc-toolset-14-libatomic-devel + Python ≥ 3.10 + rustc ≥ 1.86? | Build the image (P0-10/P1-02) | ADR-0004 |
| PR-2 | Build wall time and peak RAM for v26 `stock` at -j4/-j8 | Dry-run build (P0-10) | CI design, Phase 1 estimate |
| PR-3 | Do hosted CI runners finish a v26 build within job limits (with ccache)? | One CI attempt (P1-06) | ADR-0007 |
| PR-4 | Does the build need network after fetch (Temporal crates are vendored in `deps/crates`)? | Build with network disabled after fetch | doc 04 §3.2 |
| PR-5 | Benchmark host run-to-run CV on W1 | 10× W1 on M0 (P0-12) | Phase 1 estimate, ADR-0007 |
| PR-6 | V8 test suite source for any future V8 patch | Identify the V8 git commit matching `deps/v8` | Phase 5 (only if a V8 patch is ever proposed) |
| PR-7 | Linux allocator in our build (glibc malloc?) | `ldd` + symbol inspection of our binary | H7 framing |
| PR-8 | `smaps_rollup`, cgroup v2 `memory.peak` available on host kernel | Inspect host | doc 02 §5 |
| PR-9 | GC `PerformanceEntry.duration` semantics | Read pinned `src/node_perf.cc` + experiment | Q-06, doc 01 §6 |
| PR-10 | node-gyp/`engines` behavior with `--tag` and custom `--release-urlbase` | Phase 2 test | ADR-0008 |

## 5. Risks (additions to charter §17)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Solo maintainer (D-05, accepted): no independent human reproduction or review | Certain | Blind spots in build docs and patches | Clean-VM rebuild + checksum comparison (BLD-AC-3, BM-AC-5). Cooling-off self-review + code-reviewer agent + full test tier (doc 04 §4). Bus factor of 1 remains an accepted risk |
| OCI Always Free limits (D-04): noisy shared hardware, idle reclamation, slow builds, disk quota; limited private-repo Actions minutes | High | Inconclusive results, lost VMs, CI stalls | n=20 + same-session A/A; scripted, disposable VMs; ccache; ration Actions minutes; insufficiency triggers in ADR-0007 |
| v26 early-LTS defects | Medium | Rework of baseline | ADR-0003 fallback + revisit trigger |
| Toolchain mismatch with upstream skews comparisons | Medium | False attributions | M0 row (architecture.md CD-5); BLD-AC-2 |
| Benchmark noise exceeds effect sizes | **High** (shared OCI hardware) | Inconclusive Phase 4 | Same-host-only comparisons; interleaving; n=20+ tuned from CV; honest "inconclusive"; D-04 revisit trigger |
| Temporal/Rust toolchain silently absent | Medium | Build differs from upstream | BLD-AC-4 explicit flag |
| Diagnostics sampler perturbs results | Medium | Wrong conclusions | Out-of-process first; overhead measured (DG-AC-4) |
| Local dev Node is behind security releases (24.14.1; security releases 24.17.0 and 24.18.1 since) | Certain | Dev-only exposure | P0-11 |

## 6. Explicitly out of scope (first milestone)

Charter §8.2 applies in full: replacement GC, new compiler/language, new package ecosystem or module semantics, required app code changes, custom framework, new add-on ABI, guaranteed compatibility with every native module, speculative V8 changes, universal RAM-reduction claims, multi-platform matrix before Linux is stable. Added: Windows/macOS artifacts; musl/Alpine artifacts; version-manager integration; any change to `process.version`/`process.release` before ADR-0008.

## 7. Not yet covered / deferred (backlog, so nothing is lost)

- Workload specs for database-backed API, background worker, container-limited service, and high concurrency (doc 02 §2.7).
- `docs/diagnostics-guide.md` (Phase 3), `docs/experiments/` (Phase 4), `docs/security-log.md` (first upstream security event).
- Issue templates, examples (`examples/basic-node-api`, `express-api`, `worker`): Phase 6.
- Container image variants: Phase 6 (Q-08).
- arm64 benchmark host: after x64.
- Upstream contribution workflow for general fixes (charter §16).
- Charter §16 "future directions": none scheduled.

---

# Part B — Implementation plan (pre-code)

Legend: complexity **S/M/L**, risk **lo/med/hi**. "Implements" cites the spec section or acceptance criterion.

## 8. Phase 0: Foundation (in progress)

| ID | Task | Implements | Depends on | Cx/Risk |
|---|---|---|---|---|
| P0-01 | Review and approve this doc set (D-01..D-07 resolved 2026-10-12) | all docs; decision-log | — | S/lo |
| P0-02 | **(done 2026-10-13)** `git init`; create the charter §15 skeleton (dirs, `.gitignore` incl. `artifacts/` and `out/`, `artifacts/README.md`, `CHANGELOG.md`) | architecture.md §3; charter §15 | P0-01 | S/lo |
| P0-03 | **(done 2026-10-13)** Finalize root README/SECURITY/CONTRIBUTING stubs (SECURITY contact: afa.hamdu@gmail.com) | SEC-AC-6 (partial); charter §13 Phase 0 | P0-01, D-02 | S/lo |
| P0-04 | Add MIT `LICENSE`; DCO check in CI (D-01 accepted) | ADR-0011 | — | S/lo |
| P0-05 | Create the **private** GitHub repo with protected main and required checks (D-07) | doc 04 §6 | P0-02 | S/lo |
| P0-06 | CI T0 workflow: markdown lint, internal link check, actions pinned by SHA | TST-AC-1; doc 04 §6 | P0-05 | S/lo |
| P0-07 | ~~Decide ADR-0003/ADR-0007~~ **resolved 2026-10-12.** OCI A1 capacity is confirmed: two 2 OCPU / 12 GB VMs are provisioned **(done 2026-10-12)** | ADR-0007 | — | S/lo |
| P0-08 | Pick a dependency-scanning tool and wire it into T0 | SEC-AC-3 | P0-06 | S/lo |
| P0-09 | **Scripted** provisioning of the OCI A1 VM(s) (disposable, because of reclamation): OS, Podman/Docker, ccache, disk layout, optional self-hosted runner | ADR-0004, ADR-0007 | P0-07 | M/med |
| P0-10 | **Riskiest-first dry run on OCI A1 (arm64):** manually fetch v26.11.1, verify with `gpgv` + SHA-256, build `stock` in a candidate image at -j2/-j4; record wall time, peak RAM, disk used, toolchain versions | PR-1, PR-2, PR-4; UP-AC (manual) | P0-09 | M/**hi** |
| P0-11 | Update dev-machine Node to the current v24 or v26 release (24.14.1 is behind two security releases); install `gpg`; Python ≥ 3.10 if local v26 configure is ever wanted | context.md §4 | — | S/lo |
| P0-12 | OCI noise probe: 20× W1-equivalent on M0 (official linux-arm64 binary), A/A, on the two-VM layout; compute CV | PR-5; doc 02 §4.3 | P0-07 | S/med |
| P0-13 | Versioning policy confirmed (doc 07 §1, Q-03) | charter Phase 0 "versioning policy" | P0-01 | S/lo |

**Phase 0 exit (charter):** direction clear, scope controlled, process documented. Made checkable: P0-01..P0-06 and P0-13 done; P0-10 and P0-12 results recorded in `progress.md`.

## 9. Phase 1: Upstream baseline

| ID | Task | Implements | Depends on | Cx/Risk |
|---|---|---|---|---|
| P1-01 | Pin: fill `upstream/version-lock.md` §1 + create `version-lock.json`; CI check that both agree | UP-AC-2; ADR-0003 | v26 LTS release (Q-01), P0-07 | S/lo |
| P1-02 | Build image definition; publish it; record its digest | ADR-0004; BLD-AC-1 | P0-10 | M/med |
| P1-03 | `tools/build` fetch-verify script plus negative tests (bad sig, bad hash, wrong version) | UP-AC-1; SEC-AC-1 | P1-01 | M/lo |
| P1-04 | `config/build/stock.flags`: derive from official `config.gypi`; diff our `config.gypi` vs official; document expected differences | BLD-AC-2, BLD-AC-4; architecture.md §6 | P1-02, P1-03 | M/med |
| P1-05 | Manifest generator (`pini.release-manifest/v0`) | REL-AC-1; BLD-AC-5 | P1-04 | S/lo |
| P1-06 | CI T1: arm64 on the OCI self-hosted runner; x64 on GitHub-hosted runners within the private-repo minute allowance. Record wall time and minutes used (PR-3) | TST-AC-2 | P1-04 | M/**hi** |
| P1-07 | T2 full upstream run on M1; store as the triage reference | TST-AC-3 | P1-06 | M/med |
| P1-08 | OCI benchmark layout config + fingerprint script (doc 02 §4.1 controls); off-VM results sync | doc 02 §4.1 | P0-09, P0-12 | M/med |
| P1-09 | Out-of-process sampler (procfs, smaps_rollup, cgroup v2) | doc 02 §5; architecture.md CD-8 | PR-8 | M/lo |
| P1-10 | In-process preload sampler + overhead measurement | doc 01 §6; BM-AC-6 | P1-09 | M/med |
| P1-11 | Workloads W0–W5 with lockfiles and seeded fixtures (Express 5.x pinned) | BM-AC-1; doc 02 §2 | — | M/lo |
| P1-12 | Runner: matrix rows, randomized interleaving, oha integration, `result.json` schema validation | BM-AC-2, BM-AC-3; ADR-0005 | P1-09, P1-11 | L/med |
| P1-13 | Calibration on M1 → fixed rates; baseline M0+M1 for W0–W5; publish the report per doc 02 §8 | BM-AC-4 | P1-04, P1-08, P1-12 | M/med |
| P1-14 | Clean-VM reproduction (D-05): provision a fresh VM from the docs only, rebuild, compare the binary SHA-256, re-run the baseline, compare medians | BLD-AC-3; BM-AC-5 | P1-13 | M/med |
| P1-15 | Allocator check on our binary (PR-7); update H7 wording | doc 01 §4 H7 | P1-04 | S/lo |
| P1-16 | Pick the T3 add-on sample set (Q-07) | doc 03 §4 | P1-04 | S/lo |

**Phase 1 exit:** BLD-AC-1..5, BM-AC-1..6, TST-AC-2..3 met.

## 10. Phase 2: PINI distribution

| ID | Task | Implements | Depends on | Cx/Risk |
|---|---|---|---|---|
| P2-01 | ADR-0008 evidence: test `--tag`, `--release-urlbase`, node-gyp header fetch, `engines` checks; decide | ADR-0008; PR-10 | P1-04 | M/med |
| P2-02 | `pini` flavor; if ADR-0008 picks B, the first patch (`process.versions.pini`) with a test, through the doc 04 §4 patch process | CMP-AC-4; architecture.md §6 | P2-01 | M/med |
| P2-03 | Packaging: tarball layout, `pini-manifest.json`, `SHASUMS256.txt`, licenses | doc 06 §1; doc 07 §3, §5; REL-AC-1 | P2-02, D-01 | M/lo |
| P2-04 | Install docs executed by someone else; libatomic positive/negative test | DEP-AC-1, DEP-AC-2 | P2-03 | S/lo |
| P2-05 | T3 compatibility suites: Express 4/5 scenarios, add-on set, version-equality tests | CMP-AC-2, CMP-AC-3, CMP-AC-4; doc 05 §4 | P1-16, P2-02 | M/med |
| P2-06 | Differential triage automation (PINI vs M1) | TST-AC-4; CMP-AC-1 | P1-07 | M/lo |
| P2-07 | Rehearse a patch-level upgrade end-to-end (e.g. 26.11.1 → LTS-designated v26) | REL-AC-2 | P1-03..P1-06 | S/med |
| P2-08 | Reproducible-build check (two builds, compare, document differences) | doc 04 §3.4 | P2-03 | M/med |
| P2-09 | Decide ADR-0009 (signing/provenance) | ADR-0009 | — | S/lo |
| P2-10 | Separate the publish workflow; credentials unavailable to PR jobs | SEC-AC-2 | P0-06 | S/lo |
| P2-11 | Release-gate checklist in the release workflow, with evidence links | TST-AC-6; REL-AC-4 | P2-06 | S/lo |

**Phase 2 exit (charter):** PINI builds, identifies itself, installs, and passes tests independently of stock Node.js.

## 11. Phase 3: Memory diagnostics (may overlap Phase 2)

| ID | Task | Implements | Depends on | Cx/Risk |
|---|---|---|---|---|
| P3-01 | JSON schema `pini.memory-report/v0` | DG-AC-1; doc 01 §7.2 | — | S/lo |
| P3-02 | Report implementation (snapshot + series, `growth` slope, container fields); decide Q-05 | DG-AC-1, DG-AC-5 | P1-10, P3-01 | M/med |
| P3-03 | GC entry duration semantics (PR-9 / Q-06) | doc 01 §6 | P1-01 | S/med |
| P3-04 | Privacy sentinel test | DG-AC-3; SEC-AC-4 | P3-02 | S/lo |
| P3-05 | `tests/memory/` and `tests/gc/` positive/negative cases; DG-AC-2 fixtures | DG-AC-2; TST-AC-5 | P3-02 | M/med |
| P3-06 | Series-mode overhead on W1 | DG-AC-4 | P3-02, P1-13 | S/med |
| P3-07 | `docs/diagnostics-guide.md` | DG-AC-6 | P3-02 | S/lo |

## 12. Phases 4–8 (outline; detailed when the previous phase exits)

| ID | Task | Implements |
|---|---|---|
| P4-01 | A/A runs → regression thresholds written into doc 02 §6 | BM-AC-7 |
| P4-02 | Experiments for H1–H8 via the doc 01 §5 protocol, one EXP file each, findings logged | doc 01 §4, §8 |
| P4-03 | Update deployment budgeting guidance from H1/H2 | DEP-AC-3 |
| P4-04 | `pini-exp-ptrcomp` flavor with its own headers + `--release-urlbase`; add-on rows | ADR-0006; CMP-AC-2 |
| P5-01 | First patch only if P4 found a config-unfixable bottleneck; full patch process | charter §9 stage 4; doc 04 §4 |
| P6-01 | Security process dry run; fast-track dry run | SEC-AC-5; REL-AC-5 |
| P6-02 | Security contact live; signed artifacts + provenance | SEC-AC-6; REL-AC-3 |
| P6-03 | Upgrade/rollback test; examples; issue templates | DEP-AC-4; charter Phase 6 |
| P7/P8 | Per charter §13. Planned at Phase 6 exit | — |

## 13. Traceability check

**Every acceptance criterion maps to at least one task:**

| AC | Task(s) | | AC | Task(s) |
|---|---|---|---|---|
| UP-AC-1 | P1-03 | | DG-AC-1 | P3-01, P3-02 |
| UP-AC-2 | P1-01 | | DG-AC-2 | P3-05 |
| BLD-AC-1 | P1-02, P1-04 | | DG-AC-3 | P3-04 |
| BLD-AC-2 | P1-04 | | DG-AC-4 | P3-06 (sampler: P1-10) |
| BLD-AC-3 | P1-14 | | DG-AC-5 | P3-02 |
| BLD-AC-4 | P1-04 | | DG-AC-6 | P3-07 |
| BLD-AC-5 | P1-05 | | CMP-AC-1 | P2-06 |
| BM-AC-1 | P1-11 | | CMP-AC-2 | P2-05, P4-04 |
| BM-AC-2 | P1-12 | | CMP-AC-3 | P2-05 |
| BM-AC-3 | P1-12 | | CMP-AC-4 | P2-02, P2-05 |
| BM-AC-4 | P1-13 | | SEC-AC-1 | P1-03 |
| BM-AC-5 | P1-14 | | SEC-AC-2 | P2-10 |
| BM-AC-6 | P1-10 | | SEC-AC-3 | P0-08 |
| BM-AC-7 | P4-01 | | SEC-AC-4 | P3-04 |
| TST-AC-1 | P0-06 | | SEC-AC-5 | P6-01 |
| TST-AC-2 | P1-06 | | SEC-AC-6 | P0-03 (stub), P6-02 |
| TST-AC-3 | P1-07 | | DEP-AC-1 | P2-04 |
| TST-AC-4 | P2-06 | | DEP-AC-2 | P2-04 |
| TST-AC-5 | P3-05 | | DEP-AC-3 | P4-03 |
| TST-AC-6 | P2-11 | | DEP-AC-4 | P6-03 |
| REL-AC-1 | P1-05, P2-03 | | REL-AC-4 | P2-11 |
| REL-AC-2 | P2-07 | | REL-AC-5 | P6-01 |
| REL-AC-3 | P6-02 | | | |

**Tasks that trace to no acceptance criterion (justified):** P0-01 (review gate), P0-02/P0-05 (charter §15 / Phase 0 deliverables), P0-04 (ADR-0011), P0-07/P2-09 (decisions), P0-09/P0-10/P0-12/P1-15/P3-03 (prerequisites PR-1..PR-9), P0-11 (dev hygiene, context.md), P0-13 (charter Phase 0 "versioning policy"), P1-08/P1-09 (doc 02 §4.1/§5 specs; their result is covered by BM-AC-3/4), P1-16 (Q-07), P2-01 (ADR-0008), P2-08 (doc 04 §3.4), P4-02 (doc 01 protocol).

**Gaps found:**
1. ~~**BLD-AC-3 / BM-AC-5 depend on a second developer who does not exist yet (D-05).**~~ **resolved (2026-10-12):** both criteria were redefined as clean-VM rebuild + checksum comparison (D-05). The charter (vision.md §8.3, §13 Phase 1) now uses the same clean-VM wording, so there is no deviation.
2. The charter Phase 0 deliverable "upstream-management doc" has no separate file. It is covered by ADR-0002 + `upstream/version-lock.md`. Flagged in case a standalone doc is wanted.
3. Doc 04 §3.2 (network-isolated build) and §3.4 (reproducible build) are goals without hard acceptance criteria, by design (charter: "reproducible-where-practical"). P2-08 records the outcome.

## 14. Go / no-go checklist (before any code is written)

- [x] All docs reviewed and approved 2026-10-12.
- [x] D-03 decided: v26 LTS (2026-10-12).
- [x] D-04 decided: OCI Always Free arm64 + free GitHub Actions (2026-10-12).
- [x] D-05 decided: solo developer, with clean-VM reproduction and the solo review protocol (2026-10-12).
- [x] D-01 decided: MIT + DCO (2026-10-12).
- [x] D-07 decided: private repo and results (2026-10-12).
- [x] D-06 accepted as proposed (2026-10-12).
- [x] D-02 decided: afa.hamdu@gmail.com (2026-10-12).
- [x] OCI A1 capacity confirmed: two 2 OCPU / 12 GB VMs provisioned (2026-10-12).
- [ ] No objection to architecture.md CD-5 (our own build as baseline; official binary as M0).
- [ ] No objection to ADR-0002 (tarball + patch series), ADR-0005 (oha), ADR-0006 (pointer compression Phase 4 only).
- [ ] P0-10 dry run is approved as the first hands-on task.
