# PINI — Vision & Charter

| | |
|---|---|
| **Document** | Project charter: vision, scope, principles, architecture direction, roadmap |
| **Status** | Direction established — no implementation yet |
| **Last revised** | 2026-10-12 |
| **Objective** | A memory-efficient JavaScript runtime, built as a downstream distribution of Node.js and V8 |
| **Primary workloads** | HTTP APIs, Express apps, background workers, containerized services |
| **Philosophy** | Security first · evidence before optimization · compatibility · small patches · incremental delivery |

> **PINI earns its complexity one measured improvement at a time.**
> The first milestone is a trustworthy measurement and distribution foundation — not a RAM-reduction percentage.

---

## 1. Summary

PINI is a Node.js distribution focused on **memory efficiency, predictable garbage collection, and memory observability** for server-side JavaScript.

It does not build a new engine. V8 already provides a mature parser, JIT, generational/concurrent GC, and heap infrastructure; Node.js already provides the server runtime (networking, fs, streams, event loop, native add-ons). PINI keeps both and owns only what sits around them: the build, runtime defaults, diagnostics, a small set of documented patches, the benchmark suite, and the release process.

Work proceeds from least to most invasive:

```text
measure → configure → diagnose → patch Node.js → patch V8 (only if proven necessary)
```

Existing Node.js applications must run on PINI without code changes.

### 1.1 PINI is

- A downstream Node.js + V8 distribution with a reproducible build.
- A measurement platform for memory and GC behavior of real server workloads.
- A source of evidence-based runtime defaults for memory-constrained servers and containers.
- Eventually, the home of a small, carefully maintained set of Node.js/V8 patches.

### 1.2 PINI is not

- A new JavaScript engine, language, compiler, package ecosystem, or web framework.
- A replacement garbage collector (not on the committed roadmap).
- A promise that every application uses less RAM.
- A runtime that trades correctness, security, or compatibility for memory.
- A fork that modifies V8 internals speculatively.

### 1.3 Naming

"PINI" is the project name. It is unrelated to Node.js 12 or any Node.js release line. PINI version numbers are independent of Node.js and V8 version numbers (see §12), and every artifact must state which upstream versions it is built from.

---

## 2. Vision, Mission, Objectives

**Vision.** A reliable, secure, memory-efficient JavaScript runtime that lets teams run existing server-side JavaScript with lower overhead, predictable resource use, and full Node.js ecosystem compatibility.

**Mission.** Understand and improve how server JavaScript allocates, retains, reclaims, and reports memory — by measuring first, configuring second, and patching only with evidence.

| # | Objective | Meaning |
|---|---|---|
| O1 | Reduce memory overhead where measurable | Lower RSS, heap, external, or peak memory on representative workloads |
| O2 | Improve GC behavior | Fewer wasted collections, shorter pauses, less memory held after load ends |
| O3 | Predictable resource use | Stay within container/server limits; treat heap limit as *part* of the budget, not all of it |
| O4 | Preserve compatibility | Node.js APIs, npm packages, Express, Node-API add-ons keep working |
| O5 | Better diagnostics | Make it obvious whether memory is JS heap, external/Buffers, native, or OS overhead |
| O6 | Sustainability | Reproducible builds, automated tests, prompt upstream security updates, documented releases |

---

## 3. Problem Statement

Server JavaScript memory is not just "the V8 heap". It comes from JS objects and closures, retained references, request/response payloads, Buffers and ArrayBuffers, native Node.js internals and add-ons, TLS, database drivers and pools, caches and queues, workers and child processes, GC headroom and allocation spikes, application leaks, and runtime/OS overhead.

Two consequences shape the whole project:

1. **Not every memory problem is a GC problem.** If an application keeps references to dead data, no collector can free it.
2. **A smaller heap is not a smaller process.** A process can have a small heap and a large RSS driven by native or external memory.

PINI therefore always separates:

| Dimension | Question |
|---|---|
| Allocation | How fast does the workload create objects/buffers? |
| Retention | How much stays reachable and cannot be reclaimed? |
| Collection | How effectively is eligible memory reclaimed, and at what CPU/pause cost? |
| Native memory | How much lives outside the managed heap? |
| Process overhead | What does the runtime + OS cost before any app code runs? |
| Workload shape | How do traffic, concurrency, payload size, and architecture change the above? |

No optimization is judged on one of these in isolation.

---

## 4. Users and Workloads

**Primary users:** Node.js/Express developers, backend/API teams, operators running services in containers, teams packing many services onto constrained hosts, teams running queue workers and scheduled jobs, platform engineers who need memory diagnostics.

**Benchmark workloads** (production-like workloads decide value; synthetic ones only isolate mechanisms):

| Workload | What it reveals | First suite? |
|---|---|---|
| Plain `http` API | Baseline throughput and idle/loaded memory | ✅ |
| Express JSON API | Realistic framework overhead, JSON parse/serialize | ✅ |
| Allocation-intensive | GC frequency, pause times, young-gen behavior | ✅ |
| Buffer-heavy | External/ArrayBuffer memory | ✅ |
| Long-running steady load | Growth over time, retention, post-load recovery | ✅ |
| Database-backed API | Driver and pool overhead | later |
| Background worker | Memory across repeated jobs and after jobs finish | later |
| Container-limited service | Behavior under cgroup memory limits | later |
| High concurrency | Memory vs throughput vs latency trade-off | later |

---

## 5. Guiding Principles

1. **Security first.** Never trade security for memory or speed. Every change is assessed for memory safety, execution correctness, native add-on boundaries, TLS/networking, dependency risk, isolation assumptions, and artifact integrity. Upstream security releases are a core maintenance duty, not an optional chore.
2. **Evidence before optimization.** Every optimization proposal states: the problem, a workload that reproduces it, baseline numbers, the change, expected trade-offs, actual results, regression tests, and an explicit accept/reject/investigate decision.
3. **Reuse upstream.** Reuse V8's engine and GC and Node.js's APIs. Keep downstream patches small, self-explanatory, and easy to diff against upstream. Prefer fixes that can be upstreamed.
4. **Compatibility before novelty.** A memory win that breaks common packages is a regression. Compatibility is tested continuously, from Phase 1.
5. **Measure more than RAM.** Every result reports memory *and* throughput, latency (p50/p95/p99/max), CPU, GC pauses, allocation rate, peak and post-load memory, errors, and correctness.
6. **Incremental delivery.** Every phase ends with a usable, testable deliverable and an exit criterion. Phases advance on evidence, not on the calendar.
7. **No unnecessary complexity.** No custom allocators, replacement GCs, or broad engine patches without proof they are needed.

---

## 6. Technical Direction

### 6.1 Locked decision — ADR-0001

**PINI is a downstream distribution of Node.js, using the V8 bundled with that Node.js release.**

- Node.js is the runtime foundation; V8 is the engine.
- PINI owns: build, configuration, defaults, diagnostics, patches, tests, benchmarks, releases.
- Upstream Node.js/V8 remain the source of engine functionality and security fixes.
- Every downstream modification is a deliberate, documented, individually tested patch.
- Modify as little upstream code as reasonably possible.

Reversing this decision requires a written rationale and an impact assessment on completed work (§14).

**Why not a new engine?** Reimplementing parsing, JIT, object model, and GC multiplies cost and security risk with no evidence it is needed.
**Why not embed V8 directly?** Existing Node.js/Express apps need the full Node.js API surface, module loading, and add-on ABI; Node.js already provides them.

### 6.2 Technology choices

| Area | Direction |
|---|---|
| Engine / runtime | V8 / Node.js — an actively supported LTS line, pinned exactly |
| Build | Upstream Node.js build system (`configure` + `make`/ninja) |
| Project tooling | Node.js scripts (ES modules); pnpm where a package manager is needed |
| Benchmarks | Node.js workloads + an external load generator |
| Tests | Upstream Node.js test suite (tiered) + PINI-specific tests |
| Platform | Linux x64/arm64 first; containers via Docker-compatible runtimes. macOS used for development only |
| Docs / VCS / CI | Markdown / Git / automated build-test-benchmark-verify pipeline |

The exact upstream version is selected in Phase 1 and recorded in `upstream/version-lock.md` with its bundled V8 version, source hash, toolchain, and upstream support window. PINI never stays on an EOL or vulnerable Node.js line because it is easier to patch.

### 6.3 Known levers to evaluate (hypotheses, not commitments)

These are existing, documented mechanisms to be measured in Phases 1–4 *before* any custom code:

| Lever | Type | Expected effect / risk |
|---|---|---|
| V8 heap flags (`--max-old-space-size`, `--max-semi-space-size`, `--optimize-for-size`, …) | Runtime config | Trade heap headroom against GC frequency and CPU |
| Container-aware heap sizing (cgroup limits) | Runtime config / defaults | Avoid OOM-kills and over-reserved heaps in containers |
| Pointer compression (`--experimental-enable-pointer-compression` build) | Build config | Can substantially shrink heap size; caps heap per isolate and has historically affected native add-on ABI compatibility — must be measured and compatibility-tested. Standard Node.js builds ship with it **disabled** (verified on Node 24.14.1: `v8_enable_pointer_compression: 0`) |
| Allocator choice / tuning for native memory | Build/runtime config | May reduce RSS fragmentation; needs native-memory measurement |
| Snapshot / startup tuning | Build config | Startup time and initial RSS for short-lived processes |

---

## 7. Architecture (logical layers)

```text
┌───────────────────────────────────────────────┐
│ 7  Release & distribution  (binaries, images, │
│    checksums, signatures, notes, advisories)  │
├───────────────────────────────────────────────┤
│ 6  Tests & benchmarks  (correctness, compat,  │
│    memory/GC regression, perf, stress, sec)   │
├───────────────────────────────────────────────┤
│ 5  Patches  (patches/node, patches/v8)        │
│ 4  Memory policy  (evidence-based defaults)   │
│ 3  Memory diagnostics  (reports, GC telemetry)│
│ 2  Build & configuration  (pins, flags, meta) │
├───────────────────────────────────────────────┤
│ 1  Upstream foundation  (Node.js + bundled V8)│
└───────────────────────────────────────────────┘
```

| Layer | Responsibility | Rule |
|---|---|---|
| 1 Upstream | JS execution, GC, Node.js APIs | Pinned; not duplicated into the repo |
| 2 Build & config | Reproducible build, targets, toolchain, version metadata, patch application/verification | Any behavior-affecting setting is documented and benchmarked |
| 3 Diagnostics | Heap used/total/limit, RSS, external, ArrayBuffers, GC events, container limit, growth indicators, structured/time-series output | Reuse `process.memoryUsage`, `v8.getHeapStatistics`, `perf_hooks` GC entries, diagnostic reports before inventing new instrumentation; low overhead; no sensitive data by default |
| 4 Memory policy | Heap configuration, native/external accounting, container defaults, per-workload recommendations | Never assume one configuration fits all workloads |
| 5 Patches | Narrow source changes: hot-path allocation, retention in runtime components, GC heuristics, native allocation patterns | V8 patches only after config and Node.js-level options are exhausted |
| 6 Tests & benchmarks | Prove PINI is correct, secure, compatible, and measurably useful | Runs continuously, not at the end |
| 7 Release | Linux binaries, container images, checksums, signatures, compatibility info, upgrade/rollback guidance | Starts only after build is reproducible and tests are automated |

---

## 8. Initial Release Scope

### 8.1 In scope

1. Pinned, upstream-supported Node.js/V8 baseline, built unmodified from source.
2. Recorded build environment and exact source versions.
3. Repeatable benchmark methodology and the five first-suite workloads (§4).
4. Baseline memory + performance measurements.
5. PINI repository, core docs, and CI.
6. PINI-branded build with minimal downstream changes.
7. A basic structured memory diagnostics report.
8. Compatibility and memory-regression tests.
9. Install/run documentation.
10. PINI vs. upstream comparison, published honestly — including regressions and inconclusive results.

### 8.2 Out of scope (first milestone)

Replacement GC · new compiler or language · new package ecosystem or module semantics · required app code changes · custom framework · new add-on ABI · guaranteed compatibility with every native module · speculative V8 changes · universal RAM-reduction claims · multi-platform release matrix before Linux is stable.

### 8.3 Success criteria

- Source versions and build environment are pinned, and the build is reproduced from scratch on a clean VM with matching checksums (solo-maintainer rule, D-05).
- Baseline and PINI are benchmarked under identical conditions.
- Diagnostics work and are tested.
- Representative Node.js and Express apps run.
- Important correctness and memory regressions are detected automatically.
- Security and upgrade responsibilities are documented.
- Results are recorded honestly, even if no memory improvement exists yet.

---

## 9. Optimization Strategy (staged)

| Stage | Activity | Gate to next stage |
|---|---|---|
| 1 Measure | RSS (startup, warm, peak, post-load), heap used/total/limit, external, ArrayBuffers, CPU, throughput, latency, GC frequency/duration — repeated runs, full environment recorded | Stable baseline with known variance |
| 2 Configure | Test existing Node.js/V8 options (§6.3). Ask: wrong heap limit? container limit? too-small heap → GC thrash? app retention? native-dominated? oversized buffers? concurrency spikes? | Configuration space explored for the target bottleneck |
| 3 Diagnose | Structured snapshots, GC summaries, allocation-rate summaries, growth warnings, container-limit reporting, log-friendly/machine-readable output | Root cause located in a specific layer |
| 4 Patch Node.js | Buffer allocation, runtime object allocation, internal data structures, resource lifecycle, retention in runtime components | Config cannot fix it; narrow patch + regression test |
| 5 Patch V8 | GC heuristics, allocation behavior, object representation, heap/compaction behavior | Node.js-level fix impossible; broad-suite results acceptable; maintenance cost accepted |
| 6 Research | Constrained-environment adaptation, idle footprint, workload-aware policies, worker memory, reclamation under sustained load | Weighed against long-term fork cost |

A patch is never accepted because it wins one micro-benchmark. It must hold up across correctness, security, compatibility, and the full workload suite.

---

## 10. Benchmarking & Evaluation

**Comparison matrix** (separates config effects from code effects):

1. Upstream Node.js, default settings
2. Upstream Node.js, tuned settings
3. PINI, documented defaults
4. PINI, experimental configurations (when applicable)

All four use the same upstream source version PINI is derived from.

### 10.1 Metrics

| Category | Metrics |
|---|---|
| Memory | RSS, heap used, heap total, external, ArrayBuffers — always labelled with which one |
| Peak / recovery | Peak RSS under load; memory after load ends and after idle |
| GC | Frequency, duration, pause distribution |
| Performance | Requests/s, throughput |
| Latency | p50, p95, p99, max |
| CPU | Utilization, cost per request |
| Reliability | Crashes, errors, timeouts, OOMs |
| Compatibility | Test pass rates, package execution outcomes |

**Conditions:** same hardware (or equivalent isolated environment), OS, workload and input data, concurrency, warm-up, duration, and configuration (unless configuration is the variable). Multiple runs; report variance, not best-of.

**Acceptance:** success criteria are defined *before* each experiment. Numeric regression thresholds are set in Phase 4 from measured variance — not invented beforehand.

**Every report includes:** PINI/Node.js/V8 versions, commits, build config, hardware/OS, container limits, workload description, method, results with variability, limitations, and interpretation. Public performance claims must link to reproducible results.

---

## 11. Compatibility, Security, Testing

### 11.1 Compatibility

- **Node.js APIs:** ESM, CommonJS, module resolution, HTTP/HTTPS, streams, Buffers, fs, timers, worker threads, child processes, crypto/TLS, errors, signals.
- **Express (early target):** basic API, JSON I/O, middleware, error middleware, async handlers, concurrency, graceful shutdown, a DB-backed endpoint — tested for correctness *and* resource behavior.
- **Native add-ons:** document which mechanisms (Node-API versions, ABI) are supported; no universal promises without evidence. Any build change that alters the ABI (e.g. pointer compression) is a compatibility event.
- **Deliberate incompatibilities** must be documented, justified, tested, called out in release notes, and assessed for impact.

### 11.2 Security

- **Upstream tracking:** monitor Node.js and V8 security releases; for each, decide whether PINI is affected, whether patches still apply, and whether an (emergency) release is needed. Never hold a vulnerable version to preserve a benchmark.
- **Build security:** pinned and verified sources, controlled build deps, reproducible-where-practical builds, checksums, signed releases, least-privilege CI credentials, protected release workflows, documented provenance.
- **Patch security:** every Node.js/V8 patch is reviewed and tested; GC, memory layout, native interface, and object representation changes get extra scrutiny.
- **Dependencies:** minimal tooling deps; automated scanning in CI.
- **Diagnostics privacy:** no secrets, tokens, or user data in default output. Heap snapshots and profiles are confidential artifacts with documented access, storage, retention, and deletion rules.
- **Vulnerability process:** intake, severity assessment, coordinated fix, release, advisory, version retirement. Every release states its support status and upstream base.

### 11.3 Testing

| Suite | Covers |
|---|---|
| Correctness | JS semantics and Node.js API behavior |
| Compatibility | Tiered upstream Node.js tests (fast subset per CI run, full suite for release candidates) + PINI app tests |
| Memory regression | Object/array/string/Buffer allocation, repeated and concurrent requests, repeated jobs, idle recovery, long-running behavior — tolerant of harmless machine variance |
| GC | Small/large temporary allocations, long-lived and mixed lifetimes, retention, pressure, repeated cycles — distinguishing reachable from collectable memory |
| Stress / stability | Sustained load, concurrency, resource pressure, graceful shutdown, recovery |
| Security | Applicable upstream security tests + tests for modified components |

**Release gates — a candidate does not ship with any unresolved:** critical correctness failure · known critical security issue · reproducible severe memory regression · unexplained major performance regression · broken build/artifact · compatibility regression violating the release contract.

---

## 12. Releases & Versioning

- **PINI uses its own SemVer**, describing PINI's contract only: *major* = breaking PINI-specific behavior; *minor* = compatible features/improvements; *patch* = fixes, maintenance, security.
- **Every release records:** PINI version, Node.js version, V8 version, PINI commit, patch-set revision, build config, supported platforms, security support status. Upstream versions are never inferred from the PINI version.
- **Channels:** development → experimental → release candidate → stable. Experimental features never silently enter the stable contract.
- **Upstream upgrades are planned work:** bump sources → reapply patches → verify build → correctness + compatibility tests → security review → benchmark comparison → release notes → rollback plan. Security updates may be fast-tracked.

---

## 13. Roadmap

Each phase has one deliverable and one exit criterion. Phases advance on evidence, not elapsed time.

| Phase | Goal | Deliverable | Exit criterion |
|---|---|---|---|
| **0 Foundation** | Rules and direction | Repo, charter, README, CONTRIBUTING, SECURITY, test strategy, benchmark methodology, upstream-management doc, decision log, CI skeleton, versioning policy | Direction clear, scope controlled, process documented |
| **1 Upstream baseline** | Build and measure unmodified Node.js | Pinned supported LTS + V8 version, source build, build instructions, first-suite benchmarks, baseline report with variance | A clean-VM rebuild matches checksums and reproduces comparable numbers |
| **2 PINI distribution** | Separately identifiable runtime | PINI build/packaging workflow, version metadata, upstream-relationship doc, minimally modified build, install docs | PINI builds, identifies itself, installs, and passes tests independently of stock Node.js |
| **3 Memory diagnostics** | Explain memory behavior | Tested structured memory report incl. GC telemetry and runtime metadata; overhead measured; interpretation guide | Developers can tell heap vs external vs native vs overhead, and investigate growth |
| **4 Config experiments** | Lowest-risk wins | Experiments on §6.3 levers; recommended settings; accepted/rejected experiment log; numeric regression thresholds | At least one real bottleneck investigated to a conclusion (which may be "no change justified") |
| **5 Targeted patches** | Narrow, evidence-backed source changes | First custom patch (Node.js first, V8 only if required) with regression tests and maintenance assessment | Any accepted patch shows repeatable benefit with no unacceptable regressions. "No patch warranted yet" is a valid outcome |
| **6 Developer preview** | Limited external use | Dev builds, platform docs, Express/Node examples, known limitations, issue templates, security update process, tested upgrade/rollback | External developers can evaluate PINI and file reproducible reports |
| **7 Stable 1.0** | Reliable runtime for defined workloads | Frozen scope, release suite passed, verified provenance, published benchmarks, install/migration docs, support policy, release notes | Meets documented correctness, security, compatibility, and operational requirements |
| **8 Continuous** | Sustain and extend | Regular releases tracking upstream; patches rebased or dropped; suite expanded; platforms added on demand | Ongoing |

### 13.1 Immediate next steps

The next step is **not** touching the garbage collector. It is:

1. Create the repo structure (§15) and core docs (§14).
2. Select and pin a supported Node.js LTS; record its V8 version, source hash, prerequisites, and support window.
3. Build stock Node.js from source on Linux; run its tests.
4. Implement the five first-suite benchmarks and record the baseline.
5. Produce the first PINI-branded build (no memory claims).
6. Implement the diagnostics report, reusing Node.js/V8 facilities.
7. Analyze: is the largest bottleneck in the workload, configuration, Node.js, V8, native allocations, or the OS/container?
8. Run the lowest-risk experiment; keep it only if the benefit is defensible.
9. Automate correctness, compatibility, and benchmark regression checks.
10. Prepare the developer preview.

**Immediate deliverable: a reproducible PINI build with baseline benchmarks and memory diagnostics.**

---

## 14. Governance

### 14.1 Core documents (`docs/`)

| File | Purpose |
|---|---|
| `vision.md` | This charter: vision, principles, scope, roadmap, future directions |
| `project-plan.md` | Phases, tasks, dependencies, exit criteria |
| `architecture.md` | Runtime layers and technical boundaries |
| `memory-strategy.md` | Memory concepts, hypotheses, experiments, findings |
| `benchmark-methodology.md` | Workloads, metrics, procedures |
| `compatibility-matrix.md` | Platforms, Node.js behavior, add-on support, known limits |
| `security-policy.md` | Security requirements and vulnerability handling |
| `test-strategy.md` | Test tiers and release gates |
| `deployment.md` | Install, containers, operations |
| `release-process.md` | Versioning, upstream upgrades, packaging |
| `decision-log.md` | Architectural decisions (ADRs) and rationale |
| `progress.md` | Current phase, done, blockers, next |
| `context.md` | Current state and constraints for coding agents |

### 14.2 Decision rules

Every significant decision records: problem, options, chosen direction, reasoning, trade-offs, and conditions for revisiting. Locked decisions are not changed casually; changing the foundation requires a written rationale and an impact assessment.

### 14.3 Rules for coding agents

1. Read `context.md`, `progress.md`, and relevant docs before changing anything.
2. Follow locked decisions; don't add unrelated features.
3. Never claim an optimization works without measurements.
4. Add tests for behavioral changes; preserve upstream version tracking; follow security rules.
5. Never invent files, APIs, flags, or build steps — verify them against the pinned source.
6. Update `progress.md` after meaningful work; record new decisions in `decision-log.md`.
7. Finish with a summary of changes, commands run, tests, benchmark results, and open issues.

### 14.4 Definition of done

| Work type | Done when |
|---|---|
| Docs | Accurate; assumptions flagged; instructions actionable; related docs updated; open decisions recorded |
| Runtime change | Reviewed; correctness + compatibility tests pass; security assessed; memory/perf measured where relevant; regressions documented; build still reproducible |
| Optimization | Bottleneck reproducible; baseline exists; change narrow; measured effect; trade-offs recorded; no unacceptable regression |
| Release | Versions recorded; required tests pass; artifacts verified; security reviewed; notes + install/rollback docs ready; supported config documented |

---

## 15. Repository Layout (target)

```text
PINI/
├── README.md  LICENSE  CONTRIBUTING.md  SECURITY.md  CHANGELOG.md  .gitignore
├── docs/                 # §14.1 core documents
├── upstream/
│   └── version-lock.md   # pinned Node.js/V8 versions, hashes, toolchain
├── patches/
│   ├── node/
│   └── v8/
├── config/
│   ├── build/
│   └── runtime/
├── benchmarks/           # http, express, allocation, gc, buffers, database, memory
├── tests/                # correctness, compatibility, memory, gc, security, regression
├── tools/                # build, diagnostics, benchmark, release
├── examples/             # basic-node-api, express-api, worker
├── artifacts/README.md   # where build outputs go (not committed)
└── .github/workflows/
```

**Rules:** no committed binaries or large build outputs; no vendored copy of the full upstream tree unless the upstream-management decision requires it; exact upstream versions and patch IDs recorded; project tooling separate from upstream code; every patch explained and tested; every experiment reproducible; understandable to developers new to V8. The upstream source-management mechanism (submodule, fetch-and-verify script, or similar) is decided in Phase 0/1 and recorded as an ADR.

---

## 16. Future Directions (not committed)

Considered only after the core runtime and measurement infrastructure are reliable.

| Direction | Idea | Constraint |
|---|---|---|
| Adaptive memory config | Container-aware defaults, memory budgets, environment profiles, warnings for dangerous configs | Conservative — bad adaptation causes GC thrash or OOM |
| Low-memory profile | Smaller idle footprint, conservative allocation, predictable under pressure | Opt-in; measured against general profile; never changes app semantics |
| High-throughput profile | Throughput and stable latency with larger budgets | No single config optimizes everything |
| GC observability | Frequency, pauses, occupancy, allocation pressure, traffic correlation | Low monitoring overhead |
| Diagnostics toolkit | Detect steady growth, spikes, high external memory, post-load retention | Guides investigation; doesn't call every increase a leak |
| Container-native operation | Process vs container memory reporting, image variants, health-check examples | Tested across supported container environments |
| Workers & jobs | Memory across repeated jobs, cleanup, restart guidance | Runtime never restarts workers or drops state implicitly |
| Serverless / short-lived | Startup time, initial RSS, time-to-first-request | Must not hurt long-running performance |
| Multi-process management | Per-process and aggregate memory, sizing guidance | Kept outside the core runtime unless strongly justified |
| Platforms | More Linux arches, then macOS, Windows | Follows demand and maintainer capacity |
| Upstream contributions | Send general fixes to Node.js/V8 | Preferred over permanent divergence |
| Deep runtime research | Object representation, allocation, heap layout, GC policy | Requires coverage, V8 expertise, a measurable target, and accepted maintenance cost |

---

## 17. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Upstream changes break patches | Build/maintenance failures | Small patches; automated patch application |
| V8 changes introduce defects | Instability, security issues | Focused tests, review, broad regression suite |
| Memory wins cost throughput/latency | Worse apps | Always benchmark memory and performance together |
| Synthetic benchmarks mislead | False claims | Production-like workloads; published methodology |
| App leaks mistaken for GC defects | Wasted effort | Separate allocation / retention / collection analysis |
| Native memory overlooked | Wrong conclusions | Measure RSS, heap, external independently |
| Security updates lag | Vulnerable releases | Upstream monitoring; defined security release process |
| Compatibility breaks (incl. ABI changes) | Packages stop working | Continuous compat tests; published support matrix |
| Scope creep | Stagnation | Phase exit criteria; explicit scope control |
| Fork maintenance cost grows | Slow releases and fixes | Upstream-first; minimal divergence |
| Diagnostics leak sensitive data | Privacy/security incident | Safe defaults; documented handling of snapshots |
| Resource limits misunderstood | OOM failures | Document total-process and container budgeting |
| Too few maintainers | Slow updates | Small feature set; documented responsibilities |

---

## 18. References

Re-check all of these against the pinned version when Phase 1 selects it — V8 internals and build flags change between releases.

- Node.js source — <https://github.com/nodejs/node>
- Node.js build guide — <https://github.com/nodejs/node/blob/main/BUILDING.md>
- Node.js release schedule — <https://github.com/nodejs/release#release-schedule>
- Node.js docs — <https://nodejs.org/docs/>
- `process.memoryUsage()` — <https://nodejs.org/api/process.html#processmemoryusage>
- `perf_hooks` — <https://nodejs.org/api/perf_hooks.html>
- `v8` module — <https://nodejs.org/api/v8.html>
- V8 embedding — <https://v8.dev/docs/embed>
- V8 GC docs — <https://github.com/v8/v8/blob/main/docs/heap/garbage-collection.md>
- V8 pointer compression — <https://v8.dev/blog/pointer-compression>

---

## 19. Closing Direction

PINI starts as a carefully maintained Node.js distribution and moves — only as evidence allows — from reproducible baseline, to branded distribution, to diagnostics, to measured configuration, to targeted patches.

It does not assume V8's collector is inadequate. It finds where real workloads spend memory, what stops memory from being reclaimed, and which change gives the best overall trade-off.

Success depends on five things: **measurable value**, **compatibility**, **security**, **maintainability**, and **discipline**.
