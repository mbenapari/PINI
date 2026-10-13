# PINI — Memory Strategy

| | |
|---|---|
| **Status** | Approved 2026-10-12 |
| **Doc #** | 01 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Memory vocabulary, metric definitions mapped to real APIs, the hypothesis register (H1–H8), experiment protocol, findings log, and the diagnostics report v0 spec (charter layer 3) |
| **Charter refs** | vision.md §3, §6.3, §9, §16 |

---

## 1. Purpose

This doc turns charter §3 ("Not every memory problem is a GC problem"; "A smaller heap is not a smaller process") into definitions precise enough to measure. It also lists every lever as a falsifiable hypothesis. Nothing here claims any lever helps. Findings are recorded in §8 only after an experiment run under doc 02 has produced them.

---

## 2. Vocabulary: where a Node.js process's memory lives

| Term | Meaning | Primary source (verified API/field) |
|---|---|---|
| **RSS** | Resident physical pages of the process: JS heap, native heap, code, stacks, mapped libs | `/proc/<pid>/status` `VmRSS` (out-of-process); `process.memoryUsage().rss` / `process.memoryUsage.rss()` (in-process) |
| **Peak RSS** | Highest RSS observed by the kernel | `/proc/<pid>/status` `VmHWM`; diagnostic report `resourceUsage.maxRss` |
| **JS heap used / total** | Live+garbage bytes in V8 managed spaces vs. bytes reserved for them | `process.memoryUsage().heapUsed/heapTotal`; `v8.getHeapStatistics().used_heap_size/total_heap_size` |
| **Heap limit** | V8's configured ceiling | `v8.getHeapStatistics().heap_size_limit` |
| **Per-space** | new/old/code/large-object/etc. breakdown | `v8.getHeapSpaceStatistics()` (13 spaces on local 24.14.1, including `new_space`, `old_space`, `large_object_space`, `trusted_space`) |
| **External** | Memory held by C++ objects bound to JS objects, including ArrayBuffers and external strings | `process.memoryUsage().external`; `v8.getHeapStatistics().external_memory` |
| **ArrayBuffers** | Subset of external: ArrayBuffer/SharedArrayBuffer backing stores, including all Node `Buffer`s | `process.memoryUsage().arrayBuffers` |
| **malloced** | Memory V8 itself `malloc`s outside the heap | `v8.getHeapStatistics().malloced_memory/peak_malloced_memory` |
| **Allocation (cumulative)** | Bytes allocated since isolate creation | `v8.getHeapStatistics().total_allocated_bytes`. **Documented in v26.11.1, absent in v24.21.0 docs** (ADR-0003) |
| **Native / other** | Everything in RSS not explained above: libuv, OpenSSL, zlib, ICU, add-ons, allocator fragmentation, thread stacks | Derived: `RSS − (heap_total + external_unaccounted…)`, a *residual*, never a measured quantity. Always labelled "derived". |
| **Container limit** | cgroup memory limit applying to the process | `process.constrainedMemory()` (stable since v24.0.0; returns `0` if no constraint); cgroup v2 `memory.max` |
| **Container usage** | What the OOM killer actually judges | cgroup v2 `memory.current`, `memory.peak` (*kernel facts from general knowledge; verify on benchmark host kernel*) |

**Rule (charter §10):** every memory number in every report names which of these it is. "Memory" without a qualifier is a review blocker.

### 2.1 How Node sizes the heap today (verified in source)

- **Default old-space sizing is already cgroup-aware.** `SetIsolateCreateParamsForNode` (`src/api/environment.cc:210–221`, identical at v24.21.0 and v26.11.1) takes `uv_get_constrained_memory()`. If that is non-zero, it uses `min(uv_get_total_memory(), constrained)` and calls `constraints.ConfigureDefaults(total_memory, 0)` when no explicit max old-generation size is set.
  - **Implication:** charter §6.3's "container-aware heap sizing" lever is *not* green-field. The hypothesis is about whether the **upstream proportion** is right for server workloads, not about adding awareness. H2 below is scoped accordingly.
- **`--max-old-space-size-percentage=<pct>`** exists in both v24.21.0 and v26.11.1 (`doc/api/cli.md`, allowed in `NODE_OPTIONS`). It takes precedence over `--max-old-space-size`. Its implementation (`src/node_options.cc`, v24.21.0 lines ~130–148) uses the constrained memory when present, else total memory, and is capped at 4 GiB in pointer-compression builds.
- **`--max-semi-space-size`**: per Node docs, young generation = 3 × semi-space, so +1 MiB semi-space adds about 3 MiB of heap. Default depends on the memory limit.

---

## 3. Analysis dimensions

The charter §3 dimensions, each with the metric that answers it and the workload that isolates it (workloads defined in doc 02 §2):

| Dimension | Answered by | Isolating workload |
|---|---|---|
| Allocation | `total_allocated_bytes` rate (v26), minor-GC frequency | W3 |
| Retention | heap used after major GC at steady state; post-load heap; heap snapshot diff (investigation only) | W5 |
| Collection | GC count/duration by kind; CPU share in GC; pause distribution | W3, W5 |
| Native memory | Derived residual; external; arrayBuffers; `malloced_memory` | W4 |
| Process overhead | RSS at ready (`W0` idle probe, doc 02 §2.6) | W0 |
| Workload shape | All of the above vs. rate/payload/concurrency ladders | W1, W2 |

---

## 4. Hypothesis register

A hypothesis is a lever from charter §6.3 plus a falsifiable prediction. Status values are `untested`, `in-experiment`, `accepted`, `rejected`, `inconclusive`. Everything starts `untested`. Flags are verified as present in local `node --v8-options` / `node --help` (24.14.1) and in v26.11.1 docs/configure unless noted.

| ID | Lever | Type | Prediction (to falsify) | Risks to measure | Phase | Status |
|---|---|---|---|---|---|---|
| H1 | `--max-old-space-size` / `--max-old-space-size-percentage` lower than default | runtime | Lower peak RSS on W2/W5 with ≤ agreed throughput/latency cost | GC thrash, OOM under burst, p99 | 4 | untested |
| H2 | Upstream cgroup-proportional default vs explicit percentage in containers | runtime | A documented percentage keeps container usage below `memory.max` with fewer OOMs at equal throughput | Over-tight heap → more major GCs | 4 | untested |
| H3 | `--max-semi-space-size` (larger *or* smaller) | runtime | Larger reduces scavenge count and CPU on W3, at a predictable heap cost (3× semi-space) | RSS up; pause changes | 4 | untested |
| H4 | `--optimize-for-size` | runtime (V8) | Lower heap on W2/W5 | Throughput regression | 4 | untested |
| H5 | V8 memory reducer behavior (`--memory-reducer` family, on by default) | runtime (V8) | Post-load recovery (doc 02 metric `recov_*`) differs measurably when tuned | Idle CPU | 4 | untested |
| H6 | Pointer compression (`--experimental-enable-pointer-compression`) | build | Smaller heap (V8 reported "up to 43%" heap reduction for Chrome, v8.dev 2020; **not** a Node prediction) | 4 GiB heap cap; ABI break per configure help; add-on compat; throughput | 4 (ADR-0006) | untested |
| H7 | Allocator choice for native memory (glibc malloc tuning, e.g. `MALLOC_ARENA_MAX`, or an alternative allocator via `LD_PRELOAD`) | runtime env / build | Lower RSS residual on W4 | Throughput; fragmentation over time; supportability | 4 | untested. *Assumption:* Linux official binary uses glibc malloc (no jemalloc/tcmalloc strings found in the local macOS binary; confirm on Linux with `ldd` + symbol check in Phase 1) |
| H8 | `--v8-enable-hugepage` build | build | Lower TLB cost → CPU; RSS effect unknown | RSS *increase* likely | 4 (low priority) | untested |

Not levers (verified, kept out to prevent confusion): `--use-largepages` is a no-op in v26 `configure`. `--v8-lite-mode` and `--jitless` trade JIT for memory and are a reference point only, never a default for server workloads.

Diagnostic-only flags (never defaults): `--trace-gc`, `--trace-gc-nvp`, `--trace-gc-verbose`, `--expose-gc`, `--predictable-gc-schedule`, `--single-threaded-gc`, `--heap-prof`, `--heapsnapshot-near-heap-limit`, `--heapsnapshot-signal`.

---

## 5. Experiment protocol

Every experiment is a file `docs/experiments/EXP-NNNN-<slug>.md` (directory created on first use). It contains the charter §5.2 fields in this order:

1. **Problem**: which dimension (§3), observed on which workload.
2. **Hypothesis ID** (§4) and the written prediction.
3. **Pre-registered success criteria**: chosen *before* running, per charter §10. Before Phase 4 thresholds exist, criteria are stated as "direction + must not regress beyond the M1 run-to-run spread on {throughput, p99, CPU}".
4. **Matrix rows** compared (doc 02 §3) and configurations.
5. **Baseline** result IDs (doc 02 §7).
6. **Change**: exact flags/patch.
7. **Results** with variability. All §2 metrics, not only the target.
8. **Trade-offs**, **regression tests added**.
9. **Decision**: accept / reject / investigate, plus who decided and the date.
10. **Revisit conditions**.

An accepted *runtime* lever becomes a documented default in `config/runtime/` (layer 4) with a link to its EXP file. An accepted *build* lever becomes a flavor (architecture.md §6), and it is a compatibility event if it changes ABI (doc 03 §4).

---

## 6. Measurement overhead rules

- Out-of-process samplers (procfs, cgroup files) are the source of record for RSS and container memory (architecture.md CD-8).
- The in-process sampler is a preload module (loaded with `--import`). It reads `process.memoryUsage()`, `v8.getHeapStatistics()`, `v8.getHeapSpaceStatistics()`, and observes `PerformanceObserver({ entryTypes: ['gc'] })`. Its own cost must be measured: run W1 with and without it, under doc 02 conditions, and record the delta in throughput, CPU, and RSS. If the delta exceeds the M1 run-to-run spread, sampling frequency is reduced until it does not.
- GC `PerformanceEntry` (`entryType: 'gc'`) gives `detail.kind` (`NODE_PERFORMANCE_GC_MAJOR`/`MINOR`/`INCREMENTAL`/`WEAKCB`, plus `NODE_PERFORMANCE_GC_MINOR_MARK_SWEEP` in v24.21.0+ docs) and `detail.flags`. **Interpretation caveat:** verified that Node records the entry between V8's GC prologue and epilogue callbacks (`src/node_perf.cc:208`, `:265–267` at v26.11.1). Whether that interval equals the main-thread pause, given that concurrent marking and incremental steps happen outside it, is *not verified*. Until it is (Phase 3 task P3-03), report it as "GC callback duration", not "pause".
  - Note: `NODE_PERFORMANCE_GC_MINOR_MARK_SWEEP` is documented in v24.21.0 but was not present in `perf_hooks.constants` on local 24.14.1. Code must not assume a constant exists without checking the pinned build.

---

## 7. Diagnostics report v0 — specification (charter layer 3, Phase 3)

Goal (charter §13 Phase 3 exit): a developer can tell heap vs external vs native vs overhead, and can investigate growth.

### 7.1 Shape

- Produced by `tools/diagnostics/` as **JSON** (schema `pini.memory-report/v0`), with an optional human-readable rendering.
- Two modes:
  - **Snapshot:** one document at a point in time.
  - **Series:** newline-delimited JSON, one sample per interval, plus a summary document at the end.
- Triggered by in-process preload (`--import`) or on demand by signal. *Open question for Phase 3:* reuse `--report-on-signal` / `process.report.getReport()` as the transport, or a separate signal. Default assumption: compose *from* `process.report.getReport()` where it already has the data, rather than duplicating it.

### 7.2 Fields

| Field | Type | Source | Notes |
|---|---|---|---|
| `schema` | string | constant | `"pini.memory-report/v0"` |
| `runtime.node`, `runtime.v8`, `runtime.pini`, `runtime.flavor` | string | `process.versions`; release manifest (doc 07 §3) | `pini`/`flavor` null on upstream builds |
| `runtime.execArgv`, `runtime.v8FlagsSet` | string[] | `process.execArgv`; `NODE_OPTIONS` **names only** | Never values of env vars (doc 04 §5) |
| `process.rss`, `process.rssPeak` | bytes | `memoryUsage.rss()`; report `resourceUsage.maxRss` | |
| `heap.used`, `heap.total`, `heap.limit` | bytes | `getHeapStatistics()` | |
| `heap.spaces[]` | object[] | `getHeapSpaceStatistics()` | name, size, used, available, physical |
| `external.total`, `external.arrayBuffers` | bytes | `memoryUsage()` | |
| `v8.malloced`, `v8.mallocedPeak` | bytes | `getHeapStatistics()` | |
| `alloc.totalBytes`, `alloc.ratePerSec` | bytes, bytes/s | `total_allocated_bytes` delta | null where the field is absent (pre-v26) |
| `gc.window` | object | `PerformanceObserver` `gc` | per-kind count, sum and max duration, over the interval |
| `container.limit`, `container.usage`, `container.peak` | bytes \| null | `process.constrainedMemory()`; cgroup v2 files if readable | null outside a cgroup limit |
| `derived.nativeResidual` | bytes | `rss − heap.total − external.total` | Labelled *derived*. Can be negative because RSS counts only resident pages; documented |
| `derived.heapLimitShareOfContainer` | ratio \| null | `heap.limit / container.limit` | Warns when > configured threshold (default: report only, no warning, until Phase 4) |
| `growth` | object | series mode only | slope of `heap.used` after major GC, and of `rss`, via least squares over a window. "Growth", never "leak" (charter §16) |

### 7.3 Acceptance criteria (DG-AC)

- **DG-AC-1** Report validates against the v0 JSON schema on the pinned v26 build and, with `alloc.*` null, on the fallback v24 line.
- **DG-AC-2** On a workload that only grows Buffers (test fixture), `external.arrayBuffers` rises and `heap.used` does not rise proportionally. On one that only retains JS objects, the reverse. Both are asserted in `tests/` (doc 05).
- **DG-AC-3** Default output contains no environment variable values, no command-line argument values beyond flag names, no heap contents, and no network interface details (doc 04 §5). This is asserted by a test that injects a sentinel secret into env and argv.
- **DG-AC-4** Series mode overhead on W1 is within the M1 run-to-run spread for throughput, p99, and CPU (doc 02 §5).
- **DG-AC-5** `container.*` fields are non-null inside a cgroup v2 limit and null outside one. Verified in the container test (doc 05 T3).
- **DG-AC-6** An interpretation guide (`docs/diagnostics-guide.md`, created in Phase 3) explains each field and the derived-residual caveat.

---

## 8. Findings log

| Date | EXP | Hypothesis | Decision | Summary |
|---|---|---|---|---|
| — | — | — | — | No experiments run yet. |
