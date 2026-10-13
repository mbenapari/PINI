# PINI — Test Strategy

| | |
|---|---|
| **Status** | Approved 2026-10-12 |
| **Doc #** | 05 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Test tiers T0–T4, how upstream suites are driven, PINI-owned suites, memory/GC regression test design, release gates |
| **Charter refs** | vision.md §5.4, §11.3, §14.4 |

---

## 1. Principles

1. Upstream's suite is the main correctness oracle. PINI never edits upstream tests to make them pass.
2. Every failure on a PINI build is compared with the same test on **M1** (our unmodified `stock` build, doc 02 §3). Only failures that do not reproduce on M1 count as PINI regressions.
3. Memory tests assert **reachability and bounds**, not exact byte counts, so they tolerate machine variance (charter §11.3).

## 2. Upstream suites (verified at v26.11.1)

The source tarball contains `test/` with these suite directories: `abort addons async-hooks benchmark cctest client-proxy common doctool embedding es-module ffi fixtures fuzzers internet js-native-api known_issues message module-hooks node-api nop overlapped-checker parallel pseudo-tty pummel report sea sequential sqlite system-ca test-runner test426 testpy tick-processor tools trace_events v8-updates wasi wasm-allocation wpt`.

Relevant `Makefile` targets (v26.11.1, verified): `test`, `test-only`, `test-ci`, `test-ci-js`, `test-ci-native`, `jstest`, `test-addons`, `test-node-api`, `test-js-native-api`, `test-wpt`, `test-internet`, `test-known-issues`, `test-debug`, `test-valgrind`, `build-ci`. `CI_JS_SUITES` = `default pummel`. `NATIVE_SUITES` = `addons ffi js-native-api node-api embedding`.

**V8's own test suite is not in the tarball** (architecture.md CD-2). It is only needed if a V8 patch is ever proposed (Phase 5+).

## 3. Tiers

| Tier | When | Contents | Budget (target) |
|---|---|---|---|
| **T0** | Every PR | Lint/format of tooling; doc link check; unit tests for `tools/` (fetch-verify negative test UP-AC-1, manifest/schema validation); no runtime build | minutes |
| **T1** | Every PR that changes build/config/patches/diagnostics; nightly on main | Build the affected flavor + a **fast upstream subset**: `test/parallel` + `test/es-module` + `test/node-api` + `test/js-native-api` + `test/report`. Plus all T3 smoke tests | *Assumption:* hours on hosted runners with ccache. Measured in Phase 1 (doc 09 §4 PR-3) |
| **T2** | Release candidates; weekly on main | Full upstream: `make test-ci` equivalent on the flavor under test, *and* on M1 for differential triage | measured in Phase 1 |
| **T3** | With T1 and T2 | PINI-owned suites (§4) | — |
| **T4** | Release candidates; on demand | Stress/stability: W5 long run, container-limit runs, ASan build of relevant suites for patched builds (`configure --enable-asan`, verified flag) | long |

Benchmarks are not tests. Benchmark regression checks (doc 02) run on the benchmark host, not in T1/T2, and feed the release gate in §6.

## 4. PINI-owned suites (`tests/`)

| Directory (charter §15) | Purpose | Examples |
|---|---|---|
| `tests/correctness/` | Behavior PINI must preserve | `process.version`/`versions` equal M1 (CMP-AC-4); `process.config` flavor sanity; Temporal present iff upstream has it |
| `tests/compatibility/` | Real apps and add-ons | Express 4/5 scenarios (doc 03 §5); add-on sample set (doc 03 §4); graceful shutdown |
| `tests/memory/` | Memory regression (bounded) | Repeated requests: heap-after-major-GC returns to within a band after N iterations. Buffer churn: `arrayBuffers` returns near its baseline after release. Idle recovery |
| `tests/gc/` | Reachable vs collectable | Allocate garbage → force GC (`--expose-gc`, tests only) → `heapUsed` drops; retain objects → it does not; `FinalizationRegistry`/`WeakRef` sanity |
| `tests/diagnostics/` | Report v0 | DG-AC-1..5 (doc 01 §7.3), including the privacy sentinel test |
| `tests/security/` | Modified-component tests | Fetch-verify negative tests; per-patch security tests |
| `tests/regression/` | One test per fixed bug | — |

**Memory test design rule:** assert relative to a baseline measured *in the same process* after warm-up, with a tolerance band. Bands start generous and are tightened only with data from Phase 4. Each test documents its band rationale.

## 5. Differential triage procedure

For any red test on a PINI flavor:
1. Re-run on M1 at the same commit and host.
2. Fails on M1 too: tag it `upstream-known`, record it in the RC's compatibility notes, and do not block, unless it is security- or data-loss-related.
3. Passes on M1: it is a PINI regression and blocks the release (§6).
4. Flaky (passes on retry): log it in a flake ledger. Three flakes in 30 days means investigate.

## 6. Release gates (charter §11.3, made checkable)

A release candidate ships only when **all** of the following are true:

| Gate | Evidence |
|---|---|
| No critical correctness failure | T2 + T3 green, apart from `upstream-known` items |
| No known critical security issue | doc 04 §8 log shows no open High/Critical for the pinned version |
| No reproducible severe memory regression | doc 02 run of W0–W5, M3 vs previous release, within Phase 4 thresholds. Before thresholds exist: within the A/A spread, or explained |
| No unexplained major performance regression | same run, throughput/p99/CPU |
| Build/artifact OK | Reproducible-build check result recorded. Checksums and signature verify (doc 07 §5) |
| No compatibility regression violating the contract | doc 03 CMP-AC-1..4 |

## 7. Acceptance criteria (TST-AC)

- **TST-AC-1** T0 runs on every PR and blocks merge on failure.
- **TST-AC-2** T1 builds `stock` and runs the fast subset in CI, and its wall time is recorded.
- **TST-AC-3** T2 runs to completion on `stock` (M1) at least once in Phase 1, and its results are stored as the reference for differential triage.
- **TST-AC-4** The differential triage procedure (§5) is automated: the report lists each failure as PINI-only or upstream-known.
- **TST-AC-5** `tests/memory/` and `tests/gc/` each contain at least one positive and one negative case (garbage collected vs retained), passing on M1 (Phase 3).
- **TST-AC-6** Release gates (§6) are a checklist in the release workflow, and every gate links to its evidence.
