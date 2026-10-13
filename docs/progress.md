# PINI — Progress

| | |
|---|---|
| **Doc #** | 10 (see [architecture.md §0](architecture.md#0-document-map-master-index)) |
| **Current phase** | **Phase 0: Foundation, in progress** |
| **Last updated** | 2026-10-12 |
| **Plan reference** | Task IDs refer to [project-plan.md](project-plan.md) Part B |

---

## Status at a glance

| Phase | State | Exit criterion met? |
|---|---|---|
| 0 Foundation | In progress | No |
| 1 Upstream baseline | Not started (waiting on the v26 LTS release, ≥ 2026-10-28, and OCI A1 provisioning) | — |
| 2–8 | Not started | — |

## Done

- 2026-10-12: Charter `docs/vision.md` rewritten (owner).
- 2026-10-12: Full pre-code doc set drafted: architecture, memory-strategy, benchmark-methodology, compatibility-matrix, security-policy, test-strategy, deployment, release-process, decision-log, project-plan, progress, context, `upstream/version-lock.md`, root README/SECURITY/CONTRIBUTING stubs. **Approved 2026-10-12 (P0-01 done).**
- 2026-10-12: Upstream facts verified and recorded (release schedule, V8 versions, toolchains, configure flags, tarball contents/hash for v26.11.1). Ledger in architecture.md §9 and version-lock.md §2.

- 2026-10-12: **Owner decisions accepted and applied across the docs:**
  - **D-01:** MIT + DCO.
  - **D-03:** first v26 LTS release; v24 fallback only.
  - **D-04:** no budget. OCI Always Free Ampere A1 (arm64, 4 OCPU / 24 GB total) is the build and benchmark host, so arm64 comes first. x64 builds and tests run on free GitHub Actions, with limited private-repo minutes.
  - **D-05:** solo developer. Reproduction = clean-VM rebuild + checksum comparison. Patch review = cooling-off self-review + code-reviewer agent + full test tier.
  - **D-06:** accepted as proposed.
  - **D-07:** private repo and private results.
  - **D-02:** security contact afa.hamdu@gmail.com.
  - **OCI:** A1 capacity confirmed. The owner has provisioned two 2 OCPU / 12 GB VMs (SUT + load generator).

## In progress

- None. Next up: P0-03 (P0-02 done 2026-10-13: `git init` on `main`, charter §15 skeleton, `.gitignore`, `artifacts/README.md`, `CHANGELOG.md`; not yet committed).

## Blockers / waiting on

| Item | Waiting on | Blocks |
|---|---|---|
| v26 LTS release (expected 2026-10-28) | Upstream | P1-01 |
| Linux build environment | P0-09 scripted OCI VM provisioning | P0-10 |

## Next (in order)

2. ~~P0-02 `git init` + skeleton~~ (done 2026-10-13); P0-04 MIT `LICENSE`; P0-05 **private** repo; P0-06 T0 CI (+ DCO check).
3. P0-11: dev-machine hygiene (update Node, install gpg).
4. P0-09: script provisioning of the two existing VMs (so they can be rebuilt after reclamation).
5. P0-10: riskiest-first arm64 build dry run of v26.11.1 on A1.
6. P0-12: OCI noise probe (A/A on the two-VM layout).

## Measurements

None yet. No benchmark has been run, and no memory claim exists.
