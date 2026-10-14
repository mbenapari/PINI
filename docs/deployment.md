# PINI — Deployment & Operations

| | |
|---|---|
| **Status** | Approved 2026-10-12. **Forward-looking.** There are no PINI artifacts yet; nothing below can be installed today. |
| **Doc #** | 06 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Artifact types, runtime dependencies, install, containers, memory budgeting, operations, upgrade/rollback |
| **Charter refs** | vision.md §6.2, §7 layer 7, §8.1.9, §16 container-native operation |
| **Self-contained for** | Operators evaluating PINI who read only this doc. Pointers lead to deeper material |

---

## 1. Artifacts (planned; doc 07 owns the format)

| Artifact | Phase | Notes |
|---|---|---|
| Linux arm64 tarball (`pini-<ver>-linux-arm64.tar.xz`) containing `bin/node`, headers, licenses (MIT + upstream `LICENSE`), `pini-manifest.json` | 2 (internal), 6 (preview) | First target (D-04). Name pattern is a proposal (doc 07 §5) |
| Linux x64 tarball | 2 (internal, built on GitHub Actions) | Tested, not benchmarked for the record |
| OCI image | 6 | Base image not chosen (doc 08 Q-08) |

The binary is named `node` so shebangs and tooling keep working. PINI identity lives in `pini-manifest.json` and in the memory report (architecture.md CD-6).

## 2. Runtime requirements (from upstream v26, verified in `BUILDING.md`)

- GNU/Linux, kernel ≥ 4.18, glibc ≥ 2.28, libstdc++ ≥ 6.0.25 (`GLIBCXX_3.4.25`), meaning distributions such as Debian 10, RHEL 8, and Ubuntu 20.04 or newer. Note that upstream does not support platforms whose vendor has ended support.
- **`libatomic` runtime** (`libatomic` or `libatomic1` package). Required since Node.js 25 for official Linux binaries, and therefore for PINI built per ADR-0004. Minimal container bases may lack it.

## 3. Install (planned flow)

1. Download the tarball, `SHASUMS256.txt`, and the signature (doc 07 §5).
2. Verify the signature, then the checksum (exact commands are published with the first release; they depend on ADR-0009).
3. Extract it and put `bin/` on `PATH`, or reference it by absolute path.
4. Run `node -p "process.versions"` and check that `pini-manifest.json` matches the expected upstream base.

**Side-by-side with upstream Node.js:** supported, in separate install prefixes. Version managers are out of scope for the first milestone.

## 4. Memory budgeting (the most important operator guidance)

Facts (verified in Node source, doc 01 §2.1):

- With no heap flags, Node sizes V8's old generation from `min(physical memory, cgroup limit)`. So in a container the default heap limit already follows the container's limit.
- `--max-old-space-size-percentage=<p>` sets old space as a percentage of the constrained memory (or of total memory if unconstrained). `--max-old-space-size=<MiB>` sets it absolutely. The percentage flag wins if both are given.

Guidance (charter O3: "heap limit is *part* of the budget, not all of it"):

- **Container budget ≈ JS heap limit + young generation + external/ArrayBuffers + native (OpenSSL, zlib, ICU, add-ons, thread stacks) + headroom.** The OOM killer judges cgroup usage, not heap.
- Measure, don't guess. Run the PINI memory report (doc 01 §7) under representative load and look at `heap.limit`, `external.*`, `derived.nativeResidual`, and `container.*`.
- **No recommended percentages are published yet.** Values come only from Phase 4 experiments H1/H2 (doc 01 §4). Until then, upstream defaults apply.

## 5. Containers

- Run under cgroup v2 with an explicit memory limit, so `process.constrainedMemory()` returns non-zero and the heap defaults follow the limit.
- Graceful shutdown: the app must handle `SIGTERM`. PINI does not change signal semantics.
- Health checks: example in `examples/` (Phase 6).
- Do not enable heap snapshots on signal in production images without the doc 04 §5 handling rules. Snapshots contain secrets.

## 6. Operations

| Task | How |
|---|---|
| Identify the version | `pini-manifest.json`; memory report `runtime.*`; `process.versions` (upstream values) |
| Inspect memory | PINI memory report (Phase 3); upstream `process.report` with `--report-exclude-env --report-exclude-network` |
| Investigate growth | Memory report series mode → `growth` slope. Then heap snapshot **in a controlled environment** (doc 04 §5) |
| Security updates | Watch PINI advisories. Every release states its upstream base and support status (doc 07 §3) |

## 7. Upgrade and rollback

- **Upgrade:** install the new version side-by-side, switch `PATH` or the image tag, and watch the memory report and error rates.
- **Rollback:** switch back. PINI writes no persistent state. Rollback is only blocked if the app itself took a dependency on a newer upstream API, and release notes flag upstream line changes (doc 07 §4).
- Tested upgrade/rollback is a Phase 6 deliverable (charter §13).

## 8. Acceptance criteria (DEP-AC)

- **DEP-AC-1** On a clean container from a glibc 2.28-class base with `libatomic` installed, the Phase 2 artifact runs `node -e` and W1. Without `libatomic` it fails with a clear loader error, and that failure is documented here.
- **DEP-AC-2** Install steps (§3) are executed verbatim by someone other than the author (Phase 2 exit, charter "installs").
- **DEP-AC-3** §4 guidance is updated with the Phase 4 H1/H2 results, or explicitly states "no change justified".
- **DEP-AC-4** Upgrade/rollback between two consecutive PINI builds is exercised and documented (Phase 6).
