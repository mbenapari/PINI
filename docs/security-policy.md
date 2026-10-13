# PINI — Security Policy (internal requirements)

| | |
|---|---|
| **Status** | Approved 2026-10-12. D-02 (security contact), D-05, D-06 and D-07 were accepted on 2026-10-12 and are applied. |
| **Doc #** | 04 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Covers** | Security requirements for source, build, patches, diagnostics, CI, releases; upstream tracking; vulnerability handling. The public reporting policy is the root [SECURITY.md](../SECURITY.md) |
| **Charter refs** | vision.md §5.1, §11.2, §12, §17 |

---

## 1. Threat surfaces

| Surface | Threat | Control (section) |
|---|---|---|
| Upstream source | Tampered tarball, wrong version | §2 |
| Build environment | Compromised toolchain/image, non-hermetic inputs | §3 |
| Downstream patches | Memory-safety bugs in GC/layout/native interface | §4 |
| Diagnostics output | Leaking secrets, user data, heap contents | §5 |
| CI / release pipeline | Credential theft, unauthorized release | §6 |
| Published artifacts | Substituted binaries/images | §7 |
| Staying on vulnerable upstream | Known CVEs in shipped runtime | §8 |
| Tooling deps (npm) | Supply-chain compromise of harness | §3.3 |

## 2. Source integrity (UP-AC)

- Upstream comes in only as an official release tarball (ADR-0002).
- Verification, per upstream README "Verifying binaries": fetch `SHASUMS256.txt.asc` and verify it with `gpgv` against the keyring from `nodejs/release-keys` (`gpg/pubring.kbx`). Then `shasum -a 256 --check` the tarball. Then compare with the SHA-256 in `upstream/version-lock.md`. **All three must pass, or the build aborts.**
- The release-keys keyring is itself pinned by commit hash in the lock (so a key change is a reviewed diff).
- **UP-AC-1** The fetch script refuses to proceed if any check fails, and CI has a negative test that feeds it a corrupted tarball.
- **UP-AC-2** The lock records tarball SHA-256, `SHASUMS256.txt.asc` SHA-256, the release-keys commit, and the signing key fingerprint that verified it.

## 3. Build security

1. Builds run in a pinned OCI image referenced **by digest** (ADR-0004). The digest is recorded in every artifact manifest.
2. Build-time network access is limited to the source fetch step (*goal; feasibility verified in Phase 1*: Temporal's Rust crates are vendored under `deps/crates` in the v26 tarball (verified dir exists), so cargo may not need network. Not yet tested).
3. **Tooling dependencies:** minimal. Lockfiles committed. Automated dependency/vulnerability scanning in CI (tool chosen in Phase 0, task P0-08). No install scripts for harness deps unless reviewed.
4. Reproducibility: the "reproducible where practical" goal (charter §11.2). Phase 2 measures whether two builds of the same inputs produce identical binaries. If not, the differing sections are documented. Bit-for-bit reproducibility is not a Phase 1 gate.

## 4. Patch security

- Every patch in `patches/` has a header: purpose, EXP/ADR link, upstream status (sent/not sent), author, reviewer, and the tests that cover it.
- **Solo-maintainer review protocol** (D-05, accepted 2026-10-12; replaces two-person review). Every patch goes through these steps in order, and each one is recorded in the patch header:
  1. **Self-review after a cooling-off period.** The author re-reviews the full diff at least **48 hours** after writing it (*proposed duration*), against a written checklist covering memory safety, lifetimes, error paths, and ABI/layout impact.
  2. **Code-reviewer agent pass** on the diff, with its findings and how each was resolved recorded in the PR.
  3. **Full test tier.** T2 full upstream suite + T3, plus T4 ASan for any patch in the high-scrutiny areas below.

  High-scrutiny areas (charter §11.2 "extra scrutiny") get the longest cooling-off period and a mandatory ASan run: GC, heap layout, object representation, `src/` native bindings, Buffer/ArrayBuffer allocation, crypto/TLS, and the add-on interface. If a second maintainer ever joins, two-person review is reinstated for these areas.
- Patched builds must pass the T2 full upstream suite and, for patches touching memory allocation, an ASan build run (`configure --enable-asan` exists, verified) of the relevant suites.

## 5. Diagnostics privacy (charter §11.2)

Verified upstream facts that drive these rules:
- The Node diagnostic report includes `environmentVariables` and `header.networkInterfaces` **by default**. `--report-exclude-env` and `--report-exclude-network` (and `process.report.excludeNetwork`) exist to drop them (v26.11.1 `doc/api/cli.md`, `doc/api/report.md`; flags present in local `node --help`).
- Heap snapshots (`--heapsnapshot-signal`, `--heapsnapshot-near-heap-limit`, `v8.writeHeapSnapshot`) and heap profiles contain **all string contents** of the heap, including any secrets in memory.

Rules:
1. PINI's memory report (doc 01 §7) never includes env var values, argument values, heap contents, or network interfaces. Enforced by DG-AC-3.
2. When PINI tooling triggers a Node diagnostic report, it passes the exclude-env and exclude-network options.
3. Heap snapshots and profiles are **confidential artifacts**. They are never uploaded by CI, never attached to public issues, and are stored only on the machine that produced them unless a maintainer moves them. They are deleted when the investigation closes. Issue templates (Phase 6) say this explicitly.
4. Benchmark workloads use synthetic data only.

## 6. CI and release pipeline

- Least privilege: build/test jobs have no publish credentials. Publishing runs in a separate protected workflow/environment that needs manual approval by a maintainer.
- The repository is **public** (D-07, amended 2026-10-13). Never commit secrets, heap snapshots, or raw diagnostics. All the rules here still apply.
- Third-party CI actions are pinned by commit SHA.
- Signing keys or OIDC trust are scoped to the release workflow only (mechanism: ADR-0009).
- The benchmark host (self-hosted, ADR-0007) never runs untrusted PR code. Benchmarks run only on maintainer-approved refs.

## 7. Artifact integrity

Every release publishes SHA-256 checksums, a signature, and build provenance (doc 07 §5; mechanism per ADR-0009). Container images are referenced by digest in docs.

## 8. Upstream security tracking

**Channels (from upstream `SECURITY.md`, verified):** `https://groups.google.com/group/nodejs-sec` and `https://nodejs.org/en/blog/vulnerability`. Also V8 security fixes as they arrive via Node.js releases (PINI consumes V8 only through Node).

Context worth knowing (verified, 2026): the Node.js project **no longer runs a bug bounty** (announcement 2026-04-02; `SECURITY.md`: "The Node.js project no longer has a bug bounty program"). Upstream issues CVEs and typically sets an embargo date 72 hours after the CVE is issued (upstream `SECURITY.md`).

**Per upstream security release, PINI records in `docs/security-log.md` (created on the first event):**
1. Date seen; upstream versions; CVEs.
2. Affected? (Is the pinned line in the affected set?)
3. Do PINI patches still apply on the fixed version?
4. Decision: emergency release / next scheduled release / not affected. Plus the target date.

**Response targets (accepted 2026-10-12, D-06):** triage within **2 business days** of the upstream release. Upstream severity High/Critical: PINI release within **7 days**. Others: next scheduled release, max 30 days. The doc 07 §6 fast-track applies.

**Hard rule (charter §11.2):** a vulnerable upstream version is never held to protect a benchmark or a patch. If a patch blocks the upgrade, the patch is dropped from that release.

**Pinned-line end of life:** migration to the next LTS line must be *complete* before the pinned line reaches EOL (doc 07 §4). For the recommended v26 that is 2029-04-30. Planning starts no later than when the line enters Maintenance (2027-10-20).

## 9. Vulnerability handling (PINI-specific bugs)

Intake per root [SECURITY.md](../SECURITY.md) → acknowledge → determine whether the issue is upstream (report to Node.js via HackerOne per upstream policy, coordinate) or PINI-only (patch/config/tooling) → fix privately → release → advisory → retire affected versions (doc 07 §7). Every release states its support status and upstream base (charter §11.2).

## 10. Acceptance criteria (SEC-AC)

- **SEC-AC-1** UP-AC-1 and UP-AC-2 hold (§2).
- **SEC-AC-2** CI publish credentials are unavailable to PR-triggered jobs. Verified by workflow review checklist in Phase 2.
- **SEC-AC-3** Dependency scanning runs on every PR touching lockfiles.
- **SEC-AC-4** DG-AC-3 (diagnostics privacy test) passes.
- **SEC-AC-5** A dry-run of the §8 process, using the most recent upstream security release for the pinned line, is completed and logged before Phase 6.
- **SEC-AC-6** Root SECURITY.md lists a working private contact: **afa.hamdu@gmail.com** (D-02, accepted 2026-10-12). Before any artifact leaves the private repo, send a test email to confirm it is monitored.
