# Upstream Version Lock

| | |
|---|---|
| **Status** | **Template, not yet pinned.** Line choice **accepted 2026-10-12 (D-03 / ADR-0003): the first v26 LTS release, on or after 2026-10-28.** v24 is fallback only. The Phase 1 pin is made by filling §1 and setting status to `Pinned`. First build target: linux-arm64 (D-04). |
| **Owner docs** | [decision-log.md ADR-0002/0003/0004](../docs/decision-log.md), [security-policy.md §2](../docs/security-policy.md), [release-process.md §4](../docs/release-process.md) |
| **Last revised** | 2026-10-12 |

> Rule (charter §6.2): PINI never stays on an EOL or vulnerable Node.js line because it is easier to patch.
> Machine-readable twin: `upstream/version-lock.json`, to be created in Phase 1 (task P1-01). Both must agree. CI checks this.

---

## 1. Active pin

| Field | Value |
|---|---|
| Status | `Not pinned` |
| Node.js version | *(TBD: first LTS-designated v26.x, expected on or after 2026-10-28)* |
| Release line / codename | 26.x / *(codename assigned at LTS promotion; not yet published)* |
| LTS phase at pin date | |
| Maintenance start / EOL | 2027-10-20 / 2029-04-30 (schedule.json, 2026-10-12; "Dates are subject to change") |
| Bundled V8 (`process.versions.v8`) | |
| `NODE_MODULE_VERSION` / Node-API max | |
| Source tarball URL | `https://nodejs.org/dist/vX.Y.Z/node-vX.Y.Z.tar.xz` |
| Tarball SHA-256 | |
| `SHASUMS256.txt.asc` SHA-256 | |
| Verified by key (fingerprint) | |
| `nodejs/release-keys` commit used | |
| Verification date / by | |
| Build image digest (ADR-0004) | |
| Toolchain | Clang 20.1 + gcc-toolset-14-libatomic-devel (target, per upstream official), Python 3.1x, rustc ≥ 1.86 |
| Required explicit `configure` flags | `--v8-enable-temporal-support` (matches official `v8_enable_temporal_support: 1`) |
| Patch series revision | `none` |
| Pinned by / date / ADR | |

---

## 2. Accepted line: reference data (verified 2026-10-12)

The LTS-designated v26 release does not exist yet. These are the facts for the **latest v26 release today**, so the Phase 0 dry run (task P0-10) can start immediately. **Do not use v26.11.1 as the Phase 1 pin**: it is a *Current* release (`NODE_VERSION_IS_LTS 0` in its `src/node_version.h`).

| Field | v26.11.1 (reference) | Source |
|---|---|---|
| Release date | 2026-10-07 | `nodejs.org/dist/index.json` |
| Status | Current (LTS promotion scheduled 2026-10-28) | nodejs/Release README + schedule.json |
| V8 | `14.6.202.34-node.37` | `deps/v8/include/v8-version.h` + `common.gypi` `v8_embedder_string` |
| `NODE_MODULE_VERSION` | 147 | `src/node_version.h`, index.json `modules` |
| Node-API supported | 1–10 | `src/node_version.h` |
| OpenSSL / libuv / npm | 3.5.9 / 1.52.1 / 11.20.0 | index.json |
| `node-v26.11.1.tar.xz` SHA-256 | `2c79a3c1095c7da4c549c84e90b2d28df5479315ab6d0aff9bc71dcf4c9df1e0` | `SHASUMS256.txt`. **Also recomputed locally on the downloaded file: match.** |
| `node-v26.11.1.tar.gz` SHA-256 | `9aae9ac942395f4cb1f4e3c430409f9878897573ade738e732a14a19b91b5c9c` | `SHASUMS256.txt` |
| `node-v26.11.1-linux-x64.tar.xz` (for M0) | `3883bfc73f9a680ca4eab04b196068aaaab1373ffa77d8fc1a4408222495b651` | `SHASUMS256.txt` |
| `node-v26.11.1-linux-arm64.tar.xz` | `0945e2cde6aa0f54d980f03874dfe5cf3a549ce714c7fb9019e591ce0accf282` | `SHASUMS256.txt` |
| GPG verification of `SHASUMS256.txt.asc` | **Not performed** (no `gpg`/`gpgv` on the dev machine). `.asc` and `.sig` both exist (HTTP 200) | — |
| Official build config of note | `v8_enable_pointer_compression: 0`, `v8_enable_sandbox: 0`, `v8_enable_temporal_support: 1`, `enable_lto: false`, `clang: 1`, `llvm_version: 20.1` | `include/node/config.gypi` from `node-v26.11.1-headers.tar.gz` (the producing platform is not stated in the file) |
| Linux toolchain minimum | GCC ≥ 13.2 or Clang ≥ 19.1 | `BUILDING.md` |
| Official Linux binaries built on | RHEL 8, Clang 20.1, gcc-toolset-14-libatomic-devel | `BUILDING.md` |
| Python accepted by `configure` | 3.10–3.14 | `configure` |
| Runtime deps | glibc ≥ 2.28, kernel ≥ 4.18, `libatomic` | `BUILDING.md` |

## 3. Fallback only (verified 2026-10-12). Used only if ADR-0003 revisit triggers fire

| Field | v24.21.0 | Source |
|---|---|---|
| Release date / line status | 2026-09-07 / Active LTS "Krypton" → Maintenance 2026-10-20, EOL 2028-04-30 | index.json, schedule.json |
| V8 | `13.6.233.17-node.53` | `v8-version.h` + `common.gypi` |
| `NODE_MODULE_VERSION` | 137 | `src/node_version.h` |
| OpenSSL / libuv / npm | 3.5.8 / 1.52.1 / 11.19.0 | index.json |
| `node-v24.21.0.tar.xz` SHA-256 | `a6f54defb6fd7c84f41dba13d61e78e9b4e0961712cf61f29715c05f5ced94fc` | `SHASUMS256.txt` (not recomputed locally) |
| `node-v24.21.0.tar.gz` SHA-256 | `622424efb5dc0c26c93fbb619ff10737ee289c605b837c88778e186925d82777` | `SHASUMS256.txt` |
| `node-v24.21.0-linux-x64.tar.xz` | `fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6` | `SHASUMS256.txt` |
| Linux toolchain minimum / official | GCC ≥ 12.2 / RHEL 8 with gcc-toolset-12 | `BUILDING.md` |
| Python accepted by `configure` | includes 3.9 | `configure` |

## 4. Pin procedure (Phase 1, task P1-01)

1. Confirm the target release is LTS-designated (`process.release.lts` is set on the official binary; `NODE_VERSION_IS_LTS 1` in source).
2. Download the tarball + `SHASUMS256.txt.asc`. Verify with `gpgv` against the `nodejs/release-keys` keyring at a recorded commit. Check the SHA-256.
3. Fill §1 and `version-lock.json`. Record the support window from `schedule.json`.
4. Open a PR referencing ADR-0003 with the decision-log status update.

## 5. History

| Date | Change | By |
|---|---|---|
| 2026-10-12 | Template created; v26 recommended, v24 fallback recorded | blueprint draft |
| 2026-10-12 | D-03 accepted: v26 LTS; arm64 first (D-04) | owner decision |
