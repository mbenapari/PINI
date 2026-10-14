# PINI — Compatibility Matrix

| | |
|---|---|
| **Status** | Approved 2026-10-12. **Nothing in this matrix has been tested yet.** Every cell is `untested` until a test run under doc 05 fills it. |
| **Doc #** | 03 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Platforms, Node.js API areas, Express, native add-ons and ABI, deliberate incompatibilities, known limits |
| **Charter refs** | vision.md §5.4, §11.1, §8.2 |

Status legend: `untested` · `pass` · `pass-with-notes` · `fail` · `unsupported` (deliberate, documented) · `n/a`.

---

## 1. Compatibility contract (proposed)

For a PINI release built from Node.js `vX.Y.Z`:

1. Any JavaScript program that runs on upstream `vX.Y.Z` runs on PINI with the **same observable behavior**. Documented memory-related defaults (`config/runtime/`) are the only exception, listed in §6.
2. Node-API add-ons built for Node-API versions supported by `vX.Y.Z` load and run on the default `pini` flavor.
3. Add-ons built against the V8/Node C++ ABI (`NODE_MODULE_VERSION`) for upstream `vX.Y.Z` load on the default `pini` flavor. They are **not** guaranteed on experimental flavors that change the ABI (§4).
4. `process.version` and `process.versions.node`/`v8` equal upstream's (architecture.md CD-6, pending ADR-0008).

---

## 2. Platforms

From upstream v26.11.1 `BUILDING.md` (verified) and charter §6.2.

| OS / libc | Arch | Upstream tier (v26) | PINI status | Notes |
|---|---|---|---|---|
| GNU/Linux, kernel ≥ 4.18, glibc ≥ 2.28 | arm64 | Tier 1 | **Target, first** (D-04) | Builds and benchmarks of record on OCI Ampere A1 |
| GNU/Linux, kernel ≥ 4.18, glibc ≥ 2.28 | x64 | Tier 1 | Target (build + test) | GitHub Actions hosted runners. No benchmarks of record until x64 hardware exists |
| Linux musl ≥ 1.2.5, kernel ≥ 6.12 (e.g. Alpine 3.22) | x64 | Tier 2 | Not planned for first milestone | Charter §8.2: no multi-platform matrix before Linux glibc is stable |
| macOS ≥ 13.5 | arm64 | Tier 1 | Dev-only, unsupported | No artifacts, no benchmarks |
| Windows, others | — | various | Not planned | Charter §16 |

**Runtime dependency (verified, v26 `BUILDING.md`):** "Starting with Node.js 25, official Linux binaries are linked with `libatomic`." The `libatomic`/`libatomic1` runtime must be present. Applies to PINI if built per ADR-0004. See doc 06 §2.

## 3. Node.js API areas (charter §11.1)

Covered by the upstream test suite (doc 05 T1/T2) plus PINI app tests (doc 05 T3).

| Area | Primary evidence | Status |
|---|---|---|
| ESM, CommonJS, module resolution (`require(esm)`) | upstream `test/es-module`, `test/parallel`; T3 apps | untested |
| HTTP/HTTPS, HTTP/2 | upstream `test/parallel` (http*, https*, http2*) | untested |
| Streams, Buffers | upstream `test/parallel` | untested |
| fs | upstream `test/parallel`, `test/sequential` | untested |
| Timers, event loop | upstream `test/parallel`, `test/sequential` | untested |
| worker_threads | upstream `test/parallel` (worker*) | untested |
| child_process, signals | upstream `test/parallel` | untested |
| crypto / TLS (bundled OpenSSL) | upstream `test/parallel` (crypto*, tls*) | untested |
| Errors, diagnostics report | upstream `test/report`, `test/parallel` | untested |
| `node:sqlite`, `node:ffi` (v26) | upstream `test/sqlite`, `test/ffi` | untested. Present in v26 tree; `--without-ffi` exists (verified). Not a PINI focus |
| Temporal (v26) | depends on build flag (architecture.md §6) | untested. Must match upstream: enabled |

## 4. Native add-ons and ABI

Verified values for the candidate lines (from `src/node_version.h`, `dist/index.json`):

| Line | `NODE_MODULE_VERSION` | Node-API supported range |
|---|---|---|
| v24.21.0 | 137 | up to 10 (`process.versions.napi` = 10 on local 24.14.1) |
| v26.11.1 | 147 | 1–10 (`NODE_API_SUPPORTED_VERSION_MIN/MAX` in `src/node_version.h`) |

| Mechanism | `stock` / `pini` flavor | `pini-exp-ptrcomp` flavor |
|---|---|---|
| Node-API (C, `node_api.h`) add-ons | Expected compatible. Verify with upstream `test/node-api`, `test/js-native-api` + T3 add-on set | **Unknown.** Node-API does not expose V8 object layout, but *assumption, unverified*: the upstream `configure` help says pointer compression "breaks ABI compatibility". To be measured (ADR-0006) |
| V8/NAN C++ add-ons (`NODE_MODULE_VERSION`) | Expected compatible (same headers as upstream) | **Expected incompatible** with prebuilds made for standard builds (configure help text) |
| Prebuilt binaries downloaded by `node-gyp`/`prebuild-install` | Depends on `process.release.headersUrl` and version string (ADR-0008) | Need matching headers; likely rebuild from source |
| Add-ons compiled from source against **nodejs.org headers** | Expected compatible | **Hazard (assumption, verify in Phase 4):** `headersUrl` is derived from the release URL base + version (`src/node_metadata.cc`). An experimental flavor built with the default URL base would point node-gyp at upstream headers whose `config.gypi` says `v8_enable_pointer_compression: 0`. Add-ons could then compile with the wrong V8 layout assumptions. Experimental flavors must ship their own headers tarball and set `--release-urlbase` accordingly |
| WebAssembly | Expected compatible | untested |

**T3 add-on sample set (proposed, picked in Phase 1):** at least one popular Node-API add-on with prebuilds, one compiled from source with node-gyp (node-gyp latest 13.1.0 at 2026-10-12), and one database driver with a native component. *Specific packages: not chosen yet (open, doc 08 Q-07).*

Any flavor change that alters ABI is a **compatibility event** (charter §11.1): release notes, a separate artifact name, and an explicit row in §6.

## 5. Express (charter §11.1 early target)

Express 5.x (latest 5.3.0 on npm at 2026-10-12). Also test 4.x (`latest-4`: 4.22.3) because it is still widely deployed (*assumption about deployment share*).

| Scenario | Status |
|---|---|
| Basic routing, JSON in/out | untested |
| Middleware chain, error middleware | untested |
| Async handlers and rejected promises | untested |
| Concurrency (W2 at 80% rate, zero errors) | untested |
| Graceful shutdown (SIGTERM drains in-flight requests) | untested |
| DB-backed endpoint (later phase) | untested |

## 6. Deliberate incompatibilities

None. Every future entry needs a justification, a test, a release-note line, and an impact assessment (charter §11.1).

| ID | What differs | Why | Since | Test |
|---|---|---|---|---|
| — | — | — | — | — |

## 7. Known limits

- Pointer-compression flavors cap the V8 heap at 4 GiB (upstream `configure` help text, verified). Never a default without ADR-0006 acceptance.
- macOS/Windows: no artifacts.

## 8. Acceptance criteria (CMP-AC)

- **CMP-AC-1** Each release candidate has every §3 row filled from a T2 full upstream run, with failures triaged against the same tests on M1 (an upstream failure that also fails on M1 is not a PINI regression, but it is listed).
- **CMP-AC-2** §4 add-on rows are filled for `stock` and `pini` by Phase 2 exit, and for every experimental flavor before its experiment is reported.
- **CMP-AC-3** §5 Express rows pass on `pini` by Phase 2 exit.
- **CMP-AC-4** `process.version`/`process.versions` on `pini` equal M1's, unless ADR-0008 decides otherwise. Asserted in T3.
