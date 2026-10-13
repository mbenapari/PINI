# PINI — Context for Coding Agents

| | |
|---|---|
| **Doc #** | 11 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Last updated** | 2026-10-12 |
| **Read first** | This file → [progress.md](progress.md) → the doc that owns the area you are touching (architecture.md §0 index) |

---

## 1. What PINI is (one paragraph)

PINI is a downstream **distribution** of Node.js using the V8 bundled with it (ADR-0001, locked). It owns build, defaults, diagnostics, small documented patches, tests, benchmarks, and releases. It does **not** write an engine, a GC, or a framework. Work proceeds measure → configure → diagnose → patch Node → patch V8 (only if proven). Charter: [vision.md](vision.md).

## 2. Current state (2026-10-12)

- Phase 0. The repo contains only docs. **No code, no git repo, no CI, no build host.**
- The doc set is a **draft pending owner review**. Do not implement anything until project-plan.md §14 go/no-go is checked and the owner explicitly asks for implementation.
- Upstream is not pinned yet. **Accepted (D-03): the first v26 LTS release** (on/after 2026-10-28). v24 is fallback only. See `upstream/version-lock.md`.
- **Owner decisions in force (2026-10-12):**
  - **License (D-01):** MIT + DCO. Every commit needs `git commit -s`.
  - **Infrastructure (D-04):** no budget. OCI Always Free Ampere A1 **arm64** is the build and benchmark host of record, so arm64 comes first. x64 is build and test only, on free GitHub Actions; private-repo minutes are limited, so keep CI jobs lean.
  - **Solo developer (D-05):** reproduction = clean-VM rebuild + checksum comparison. Patch review = cooling-off self-review + code-reviewer agent + full test tier (doc 04 §4).
  - **Visibility (D-07, amended 2026-10-13):** repo and committed summary results are public (github.com/mbenapari/PINI); raw benchmark series stay off-repo.
  - **Security contact (D-02):** afa.hamdu@gmail.com.
  - **OCI layout:** two A1 VMs (2 OCPU / 12 GB each): one SUT, one load generator.
- Benchmarks: compare only within the same host and session, always with an M1 A/A run. OCI VMs are disposable (idle reclamation), so never leave results only on a VM.

## 3. Hard rules (charter §14.3 plus project specifics)

1. Follow locked decisions. No unrelated features.
2. Never claim an optimization works without a `result.json` from the doc 02 procedure.
3. **Never invent files, APIs, flags, or build steps.** Verify them against the *pinned* upstream tag (`file:line`) or a command run on the pinned build. If you can't verify something, label it *Assumption*.
4. Never edit upstream source directly. Changes go only through `patches/` with the doc 04 §4 header and tests.
5. Never edit upstream tests to make them pass (doc 05 §1).
6. Tooling runs on a separate stock Node.js, never on the binary under test (architecture.md CD-7).
7. Diagnostics output: no env values, no argv values, no heap contents, no network interfaces (doc 04 §5).
8. Every flavor passes an explicit Temporal flag (architecture.md §6, BLD-AC-4).
9. Do not change `process.version`/`process.release` (no `--tag`) until ADR-0008 is decided.
10. Update `progress.md` after meaningful work. New decisions go to `decision-log.md`. Finish with a summary of changes, commands run, tests, benchmark results, and open issues.

## 4. Environment facts (dev machine, verified 2026-10-12)

| Fact | Value | Consequence |
|---|---|---|
| OS / arch | macOS (Darwin 25.6.0), arm64 | Dev only; not a build or benchmark host of record (CD-9) |
| Node | 24.14.1 via fnm (`~/.local/share/fnm/node-versions/v24.14.1/`); V8 `13.6.233.17-node.44` | **Behind two security releases** (24.17.0, 24.18.1). Update (P0-11) |
| `process.config` | `v8_enable_pointer_compression: 0`, `v8_enable_sandbox: 0`, `node_use_node_snapshot: true`, `enable_lto: false` | Matches official Linux builds for these keys |
| Binary linkage (`otool -L`) | CoreFoundation, Security, libc++, libSystem; no jemalloc/tcmalloc strings | macOS only; Linux allocator check is PR-7 |
| Python | `/usr/bin/python3` = 3.9.6 | **Too old for v26 `configure`** (accepts 3.10–3.14). Fine for v24 |
| Compilers | Apple `clang`/`gcc` shim, `make` present | Not the target toolchain |
| Missing | `gpg`/`gpgv`, `docker`, `podman`, `pnpm`, `ninja`, any load generator | Install as tasks require |
| REA (binary inspection MCP) | Not used. `process.config`, `otool`, and `strings` answered every question | — |

## 5. Verified upstream facts you will need

| Fact | Where verified |
|---|---|
| Schedule: v24 Maintenance 2026-10-20, EOL 2028-04-30; v26 LTS 2026-10-28, EOL 2029-04-30 | nodejs/Release `schedule.json` |
| v26.11.1 → V8 `14.6.202.34-node.37`, ABI 147; v24.21.0 → V8 `13.6.233.17-node.53`, ABI 137 | tags' `common.gypi`, `v8-version.h`, `node_version.h` |
| Default heap sizing uses `min(total, cgroup-constrained)` | `src/api/environment.cc:210–221` (v24.21.0, v26.11.1) |
| `--max-old-space-size-percentage` exists (v24.21.0+, v26) | `doc/api/cli.md`; local `node --help` |
| `v8.getHeapStatistics().total_allocated_bytes` | v26.11.1 `doc/api/v8.md` (not in v24.21.0) |
| `v8.startHeapProfile()` added v26.1.0 | v26.11.1 `doc/api/v8.md` |
| GC perf entries recorded between GC prologue/epilogue callbacks | `src/node_perf.cc:208, 265–267` (v26.11.1) |
| `configure` flags: `--experimental-enable-pointer-compression`, `--experimental-pointer-compression-shared-cage`, `--shared`, `--v8-lite-mode`, `--v8-enable-hugepage`, `--enable-lto`, `--enable-pgo-generate/-use`, `--enable-asan`, `--ninja`, `--tag`, `--release-urlbase`, `--v8-options`, `--without-node-snapshot`, `--node-snapshot-main`, `--v8-enable-snapshot-compression`, `--v8-enable/disable-temporal-support` (v26) | `configure.py` at v26.11.1 |
| `--with-snapshot`/`--without-snapshot`/`--without-corepack` exist in v24.21.0 but **not** in v26.11.1; `--use-largepages` is a no-op | `configure.py` diff |
| Source tarball has `test/` and `benchmark/`, not V8's tests | `node-v26.11.1.tar.xz` listing |
| Test targets: `test`, `test-only`, `test-ci`, `test-ci-js`, `test-ci-native`, `jstest`, `build-ci`, ... | v26.11.1 `Makefile` |

## 6. Commands that are known to be real

```sh
node -p "process.versions"            # versions
node -p "process.config.variables"    # build config of a binary
node --v8-options | grep -i <flag>    # V8 flag existence on that binary
node --help | grep -i <flag>          # Node CLI flag existence
# Upstream verification (from upstream README "Verifying binaries"):
curl -fsLo nodejs-keyring.kbx https://github.com/nodejs/release-keys/raw/HEAD/gpg/pubring.kbx
curl -fsO https://nodejs.org/dist/vX.Y.Z/SHASUMS256.txt.asc
gpgv --keyring=./nodejs-keyring.kbx --output SHASUMS256.txt < SHASUMS256.txt.asc
shasum --check SHASUMS256.txt --ignore-missing
# Upstream build (BUILDING.md):
./configure <flags> && make -j4        # >= 8 GB RAM for -j4 per upstream
```

## 7. Where things go (charter §15)

`upstream/` pins · `patches/node|v8/` patches + series · `config/build|runtime/` flavors/defaults · `benchmarks/` workloads · `tests/` PINI suites · `tools/build|diagnostics|benchmark|release/` tooling · `artifacts/` outputs (gitignored) · `docs/` docs.
