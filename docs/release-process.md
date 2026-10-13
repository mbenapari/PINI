# PINI — Release Process

| | |
|---|---|
| **Status** | Approved 2026-10-12 |
| **Doc #** | 07 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Versioning, channels, release manifest, upstream-upgrade runbook, security fast-track, packaging/signing, retirement, rollback |
| **Charter refs** | vision.md §12, §11.2, §14.4 |

---

## 1. Versioning

- **PINI SemVer** describes only PINI's own contract (charter §12): major = breaking PINI-specific behavior; minor = compatible features or defaults; patch = fixes, maintenance, security.
- **Pre-1.0:** `0.y.z`, where minor bumps may break, per SemVer. The first internal artifact is `0.1.0` (Phase 2).
- **Upstream line changes** (e.g. moving from 26.x to 28.x) are at least a PINI **minor**. They are a **major** if they remove an upstream API that PINI's contract guarantees. *Proposed rule; needs sign-off (doc 08 Q-03).*
- Upstream versions are **never** encoded in or inferred from the PINI version. They appear only in the manifest and release notes.

## 2. Channels

`development` (every main build, internal) → `experimental` (`pini-exp-*` flavors, never presented as stable) → `release-candidate` → `stable`. Experimental features enter stable only through an accepted EXP/ADR and a minor release (charter §12).

## 3. Release manifest (`pini-manifest.json`, schema `pini.release-manifest/v0`)

| Field | Example / source |
|---|---|
| `pini.version` | `0.1.0` |
| `pini.commit` | git SHA |
| `pini.channel` | `development` |
| `flavor` | `pini` |
| `upstream.node.version` | from version-lock |
| `upstream.v8.version` | e.g. `14.6.202.34-node.37` (`process.versions.v8` format) |
| `upstream.tarball.sha256` | version-lock |
| `upstream.supportWindow` | `{ line, phase, maintenanceStart, eol }` from schedule.json |
| `patches.seriesRevision`, `patches.items[]` | id, file SHA-256, upstream status |
| `build.configure` | full `configure` argv |
| `build.image` | OCI image digest (ADR-0004) |
| `build.toolchain` | compiler + versions, Python, rustc |
| `platform` | `linux-x64` |
| `securityStatus` | `supported` / `security-only` / `retired` |
| `artifacts[]` | name, sha256 |

This manifest is the single source for release notes, the memory report's `runtime.pini`/`flavor`, and doc 02 result manifests.

## 4. Upstream upgrade runbook (charter §12)

Two kinds: **patch-level** within the pinned line (frequent, often security), and **line migration** (e.g. 26 → 28, at least yearly).

1. Update `upstream/version-lock.md` with the new version, tarball SHA-256, V8 version, and support window.
2. Fetch and verify (doc 04 §2).
3. Re-apply the patch series. Any conflict → per-patch decision: rebase, drop, or block (security upgrades are never blocked; drop the patch).
4. Build all supported flavors.
5. T1 → T2 → T3 (doc 05), with differential triage against the new M1.
6. Security review of the upstream changelog for areas touched by PINI patches.
7. Benchmarks: new M1 vs previous M1 (upstream drift) and new M3 vs new M1 (PINI effect). Re-calibrate rates if M1 saturation moved (doc 02 §4.2), and record it.
8. Release notes, including upstream changelog highlights and the security fixes included.
9. Rollback plan: the previous release stays available and is named in the notes.

**Line migration planning:** start when the pinned line enters Maintenance, and complete before EOL with ≥ 3 months' margin (proposed). For v26: start by 2027-10-20, finish by 2029-01-31. Note the new upstream model: from v27 every major becomes LTS, so migration targets will be v28 (or v27) per ADR-0003 revisit conditions.

## 5. Packaging, checksums, signing, provenance

- Artifacts: see doc 06 §1. Proposed name pattern `pini-<piniVersion>-<platform>.tar.xz`. Upstream version is in the manifest, not the filename (*open*, doc 08 Q-04: some operators may want it in the filename).
- `SHASUMS256.txt` over all artifacts.
- Signature + provenance per **ADR-0009 (open)**. Options: GPG-signed SHASUMS (mirrors upstream, offline-verifiable) and/or Sigstore keyless signing plus build-provenance attestations. Default assumption for Phase 2 internal builds: checksums only, no public distribution.
- Licenses: ship upstream `LICENSE` (it includes third-party dependency licenses) plus PINI's own license (doc 08 D-01).

## 6. Security fast-track

Triggered by doc 04 §8 (High/Critical upstream release affecting the pinned line):
bump → fetch/verify → patches (drop if conflicting) → build → T1 + T3 + targeted T2 (suites touching the fixed area) → W1/W2 smoke benchmark (no full matrix) → release with advisory. The skipped steps (full T2, full matrix) run afterwards, and any regression found triggers a follow-up patch release.

## 7. Retirement

A PINI release becomes `retired` when its upstream base has an unpatched security issue fixed in a newer PINI release, or when the upstream line reaches EOL. Retired releases stay downloadable, are marked in the manifest index, and get no fixes.

## 8. Acceptance criteria (REL-AC)

- **REL-AC-1** Every build in CI produces a manifest that validates against `pini.release-manifest/v0`.
- **REL-AC-2** A rehearsal patch-level upgrade (e.g. v26.11.1 → the LTS-designated v26 release) is executed end-to-end using §4 and logged (Phase 2).
- **REL-AC-3** Release artifacts have checksums, and from Phase 6 also a signature and provenance per ADR-0009, verifiable with documented commands.
- **REL-AC-4** The release workflow enforces doc 05 §6 gates as a checklist with evidence links.
- **REL-AC-5** A security fast-track dry run is completed before Phase 6 (with SEC-AC-5).
