# PINI — Benchmark Methodology

| | |
|---|---|
| **Status** | Approved 2026-10-12. Owner decisions D-04, D-05 and D-07 (accepted 2026-10-12) are applied. |
| **Doc #** | 02 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Workloads (W0–W5), comparison matrix (M0–M4), environment control, run procedure, metrics and their sources, statistics, result schema, report template |
| **Charter refs** | vision.md §4, §5.5, §9 stage 1, §10 |
| **Depends on** | doc 01 §2 (metric vocabulary), ADR-0005 (load generator), ADR-0007 (benchmark host) |

---

## 1. Principles (from charter §10, made operational)

1. Memory is never reported without throughput, latency (p50/p95/p99/max), CPU, GC, and errors alongside it.
2. Success criteria are written *before* a run (doc 01 §5). Numeric regression thresholds do not exist until Phase 4 derives them from measured variance.
3. Report distributions, not best-of. Every number has a spread.
4. Open-model load (fixed arrival rate) is the default, so latency is not hidden by coordinated omission. Closed-model (max-throughput) runs are used **only** for calibration (§4.2).
5. Every result is reproducible from its manifest: binary hash, workload commit, load-generator version, host fingerprint.

---

## 2. Workloads

All server workloads live in `benchmarks/<id>/`. Each is a single process listening on a configurable port with no external services, and has **pinned dependencies** (lockfile committed). Payload fixtures are generated deterministically from a fixed seed and committed or generated at run start with the seed recorded.

### 2.1 W1 — Plain `http` API (first suite)

- `node:http` server. `GET /json` returns a fixed ~1 KiB JSON body. `GET /health` returns 204.
- Keep-alive on. No middleware, no logging.
- **Reveals:** runtime baseline throughput and memory under load; the floor for W2.

### 2.2 W2 — Express JSON API (first suite)

- Express (latest 5.x at Phase 1 pin time, version recorded in lockfile; *exact version not chosen yet*).
- Routes: `GET /items/:id` (lookup in an in-memory Map of 10k items, serialize ~2 KiB). `POST /items` (parse ~4 KiB JSON body with `express.json()`, validate shape by hand, store with a bounded LRU of 10k entries so retention is fixed, not growing). An error route that throws, handled by error middleware.
- One trivial custom middleware (request-id header). No logging to disk.
- **Reveals:** framework overhead, JSON parse/serialize, middleware allocation.

### 2.3 W3 — Allocation-intensive (first suite)

- `GET /alloc?n=<N>&depth=<D>` builds N short-lived nested objects of depth D, maps/filters/reduces them, and returns a small summary (output size independent of N, so I/O does not dominate).
- Parameter ladder: N ∈ {1e3, 1e4, 1e5} at fixed D=3.
- Also a **non-HTTP mode** (`node benchmarks/w3/standalone.mjs`) that runs the same kernel in a loop for a fixed iteration count. It isolates GC from networking and serves as the microbenchmark that is never used alone for decisions (charter §9).
- **Reveals:** allocation rate, scavenge frequency, promotion, young-gen sizing (H3).

### 2.4 W4 — Buffer-heavy (first suite)

- `POST /echo` streams the request body back (sizes 64 KiB, 256 KiB, 1 MiB).
- `GET /blob?size=<S>` returns a freshly allocated Buffer of S bytes. `POST /gzip` pipes the body through `zlib.createGzip()` (zlib is native memory).
- **Reveals:** external/ArrayBuffer memory, native residual, allocator behavior (H7).

### 2.5 W5 — Long-running steady load (first suite)

- W2's server, driven at a fixed rate (§4.2: 50% of M1 saturation) for **60 minutes** (Phase 1), extended to longer in Phase 4 once variance is known. This is followed by **15 minutes of zero load** (recovery window).
- **Reveals:** growth over time (slope), retention, post-load recovery (H5).

### 2.6 W0 — Idle probe (supporting, not a charter workload)

- Start the binary with an empty HTTP server, wait for "listening", then sample for 60 s with no traffic.
- **Reveals:** process overhead at startup and idle (charter §3 "process overhead"). Cheap, and run in every matrix cell.

### 2.7 Later workloads (charter §4, not in Phase 1)

Database-backed API, background worker, container-limited service, and high concurrency get specs in this doc when their phase starts. Until then they are tracked in doc 09 §7 (deferred).

---

## 3. Comparison matrix

| Row | Binary | Config | Purpose |
|---|---|---|---|
| **M0** reference | Official nodejs.org Linux binary, same version | defaults | Detects toolchain-induced differences between upstream's build and ours (architecture.md CD-5). Run once per pin, not per experiment. |
| **M1** upstream default | Our `stock` flavor build | defaults | Baseline of record |
| **M2** upstream tuned | Our `stock` flavor build | tuned flags (per experiment) | Separates config effects from code effects |
| **M3** PINI defaults | `pini` flavor | `config/runtime/` defaults | What users get. Identical to M1 until any default is accepted |
| **M4** PINI experimental | `pini-exp-*` flavor or `pini` + flags | per experiment | Experiments (doc 01 §5) |

All rows use the same upstream tarball (version-lock). If M0 and M1 differ beyond run-to-run spread on any primary metric, that is investigated before any experiment is interpreted.

---

## 4. Procedure

### 4.1 Environment control (benchmark host, ADR-0007)

| Control | Requirement | Recorded as |
|---|---|---|
| Hardware | OCI Always Free Ampere A1 (Linux arm64) VM(s), per ADR-0007. Never a shared CI runner. **Use the same VM(s) for all rows in a comparison. Results from different hosts, shapes or sessions are never compared directly** | shape, OCPUs, RAM, `lscpu`, `uname -r`, region/AD |
| OS | Pinned distro image; no unrelated services | distro + version |
| CPU isolation | Server (SUT) and load generator on **disjoint CPUs**. **Chosen layout (accepted 2026-10-12): two A1 VMs, 2 OCPU / 12 GB each.** One is the SUT and one is the load generator, in the same availability domain on a private network. The layout is recorded in every result | layout, cpusets |
| Frequency | Not controllable on a cloud VM. Record whatever `cpufreq` exposes, if anything | as available |
| Memory | Swap off for runs, or recorded. THP setting recorded (`/sys/kernel/mm/transparent_hugepage/enabled`) | values |
| Network | Loopback (single-VM layout) or VCN private IPs (two-VM layout) | layout |
| Containers | For container-limited runs: cgroup v2 `memory.max` set, recorded | limit |
| Noise | No other benchmark concurrently; host idle check before each run (load average below a recorded threshold) | pre-run loadavg |

**Accepted 2026-10-12 (D-04): there is no budget, so infrastructure is OCI Always Free.** The resource figures above were supplied by the owner and have not been re-verified against Oracle's current terms. Caveats this methodology must absorb:

- **Noise from shared hardware.** A1 VMs share physical hosts with other tenants. Mitigations:
  - n starts at **20** per cell, not 10.
  - Strict randomized interleaving of rows.
  - An A/A run (M1 vs M1) in every session, to quantify that session's noise.
  - Variance is always reported.
  - No comparison across hosts, shapes or sessions without a same-session M1.
- **Idle reclamation.** Oracle may reclaim Always Free compute it considers idle (*thresholds per Oracle's current policy, not verified here*). Treat the VMs as **disposable**: provisioning is scripted (P0-09), and results are copied off the VM after every session.
- **Build time and RAM.** A 2–4 OCPU VM is slow for a Node build (upstream says ≥ 8 GB RAM for `-j4`). Builds run on a 2 OCPU / 12 GB VM with ccache (expect long builds; `-j2`). Never benchmark on a VM while it is building.
- **Disk.** Always Free block storage is limited (*exact quota per Oracle's terms, not verified here*). Source tree + `out/` + ccache + images take tens of GB. Keep one source tree and prune old images and artifacts.
- **x64.** There is no benchmark of record on x64 until suitable x64 hardware exists. GitHub Actions runners are for build and test only.

**OCI is insufficient, and D-04 must be revisited, if any of these happen:**

- After n=20, the same-session A/A spread on primary metrics is still wider than the effects an experiment pre-registers as meaningful.
- A1 capacity is repeatedly unavailable in the home region.
- Reclamation disrupts sessions.
- The build does not fit in the VM's RAM or disk.

### 4.2 Run phases (per workload × row × repetition)

1. **Start** the server with the row's binary/flags. The out-of-process sampler attaches immediately (1 s interval).
2. **Ready**: wait for the listening signal. Record `rss_ready`.
3. **Idle** 30 s. Record `rss_idle`.
4. **Warm-up** 60 s at the target rate (results discarded).
5. **Measure** 180 s at the target rate (W5: 60 min).
6. **Recovery** 120 s at zero load (W5: 15 min). Record `rss_post_load` at the end and `recov_ratio = (rss_peak − rss_post_load) / (rss_peak − rss_idle)`.
7. **Stop** with SIGTERM. Record exit status and any errors.

**Rate selection (calibration).** For each workload, once per pin, run a closed-model saturation test on **M1** to find max sustainable throughput (highest rate with error rate 0 and p99 below the knee). Target rates are then **50% and 80% of M1 saturation**, fixed for every row. Rates are never re-calibrated per row, because that would hide regressions.

### 4.3 Repetitions and ordering

- **n = 20** repetitions per cell to start (raised from 10 because of noise from shared OCI hardware, D-04). This is a *proposal*: Phase 1 measures the coefficient of variation, and n is adjusted to whatever yields a stable median. The change is recorded.
- Rows are **interleaved in randomized order** (M1, M3, M1, M4, ...), not run in blocks, so slow drift (thermal, background) spreads evenly across rows.
- A fresh process for every repetition.

---

## 5. Metrics and sources

| Metric | Source | Sampling |
|---|---|---|
| `rss`, `rss_peak` | `/proc/<pid>/status` `VmRSS`, `VmHWM` (out-of-process) | 1 s |
| `pss`, anon vs file | `/proc/<pid>/smaps_rollup` (*Linux ≥ 4.14, general knowledge; verify on host*) | 5 s |
| `cg_current`, `cg_peak` | cgroup v2 `memory.current`, `memory.peak` (container runs) | 1 s |
| `heap_used`, `heap_total`, `heap_limit`, `external`, `array_buffers`, `malloced`, spaces | in-process preload sampler (doc 01 §6) | 1 s (adjusted to overhead) |
| `alloc_rate` | `total_allocated_bytes` delta (v26+) | 1 s |
| GC count/duration by kind | `PerformanceObserver` `gc` entries, aggregated per second | event |
| `cpu_user`, `cpu_sys`, `cpu_per_req` | `/proc/<pid>/stat` utime/stime; ÷ completed requests | 1 s |
| throughput, p50/p95/p99/max, errors, timeouts | load generator JSON output (ADR-0005) | per run |
| `rss_ready`, `rss_idle`, `rss_post_load`, `recov_ratio` | derived (§4.2) | per run |
| `rss_slope`, `heap_slope` (W5) | least-squares slope over the measure window after warm-up | per run |
| crashes, OOM kills | exit status; `dmesg`/cgroup `memory.events` `oom_kill` | per run |

**Sampler overhead** is itself a reported result (DG-AC-4 in doc 01). The in-process sampler is **off** in runs whose purpose is throughput/latency of record. In that case GC and heap metrics come from a paired run with the sampler on, and the pairing is stated in the report.

---

## 6. Statistics

- Per metric per cell: **median, IQR, min, max, n**, plus the coefficient of variation.
- Row comparison: the **difference of medians**, with a bootstrap 95% CI (10,000 resamples). A difference whose CI includes 0 is reported as "no detectable difference", never as a win.
- No outlier removal except for runs that failed a pre-run environment check (§4.1). Those are excluded and listed.
- **Regression thresholds** (Phase 4 deliverable, charter §13): derived from M1 vs M1 A/A runs. Proposed rule: threshold = max(observed A/A 95th-percentile difference, a floor set in Phase 4). The rule is written down in this section when set.

---

## 7. Result schema and storage

- Each run emits `result.json` (schema `pini.bench-result/v0`): run id, workload id + commit, row, binary manifest (doc 07 §3), flags, host fingerprint (§4.1 table), load-generator name+version+args, the time series file path, and the summary metrics of §5.
- Raw results go to `artifacts/bench/` (gitignored) and are copied off the VM after every session, because of reclamation risk. Summary JSON is committed to `results/` in the **public** repo (D-07, amended 2026-10-13). Raw series stay off-repo. Raw series are kept as private CI artifacts or in off-VM storage. Until D-07 is revisited (Phase 6), "published" in this doc means published *inside the private repo*.

---

## 8. Report template

Each baseline or experiment report includes, in this order (charter §10 "Every report includes"):

1. PINI / Node.js / V8 versions, commits, flavor, build config (from manifests)
2. Hardware / OS / kernel / container limits / environment controls (§4.1)
3. Workload description and parameters; load-generator version and args
4. Method (rows, rates, n, ordering)
5. Results table (median [IQR]) for **every** §5 metric, not only the target
6. Variability and A/A context
7. Limitations
8. Interpretation and decision (or "inconclusive")
9. Links to raw results

---

## 9. Load generator

Per ADR-0005 (*proposed*): **oha** (`hatoo/oha`, MIT, v1.16.0 released 2026-08-23, actively maintained) as the primary generator. Reasons:

- Fixed-rate mode (`-q <QPS>`) with **`--latency-correction`** for coordinated omission.
- Duration mode (`-z`).
- Machine-readable `--output-format json` with a published schema.
- A single static binary that does not run on Node, so it never shares the runtime under test (architecture.md CD-7).

**Fallback:** k6 (`grafana/k6` v2.3.0, AGPL-3.0, used as an unmodified external tool) for multi-step scripted scenarios. Its `constant-arrival-rate` executor is documented at grafana.com.

**Rejected for measurement:** autocannon (closed-model by default; last release v8.0.0 in 2024-10). wrk (no coordinated-omission correction; last push 2023). wrk2 (corrects for it but is unmaintained since 2024-03).

The generator version is pinned and recorded per run. Changing it requires re-running M1 A/A.

---

## 10. Acceptance criteria (BM-AC)

- **BM-AC-1** W0–W5 exist with pinned dependencies and run green on M1 with a zero error rate at the 50% rate.
- **BM-AC-2** A single command runs a full matrix cell set (workload × rows × n) and writes `result.json` files that validate against `pini.bench-result/v0`.
- **BM-AC-3** Every `result.json` carries the binary manifest, host fingerprint, and generator version. A run missing any of them fails.
- **BM-AC-4** The Phase 1 baseline report (M0 + M1, all of W0–W5) is published per §8, including CV per metric.
- **BM-AC-5** *(Adapted for a solo developer, D-05.)* On a **freshly provisioned clean VM of the same shape**, following only the docs, the baseline is re-run. Medians fall within the published IQR overlap for primary metrics, or the difference is explained by the same-session A/A spread. The comparison is recorded. This stands in for the charter's "another developer gets comparable numbers".
- **BM-AC-6** The sampler-overhead measurement (doc 01 DG-AC-4) is published alongside the baseline.
- **BM-AC-7** Regression thresholds are derived from A/A runs and written into §6 (Phase 4).
