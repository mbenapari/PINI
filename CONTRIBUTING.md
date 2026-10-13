# Contributing to PINI

> **Stub, Phase 0.** The project is not accepting outside code contributions yet. The pre-code doc set was approved on 2026-10-12.

## Before changing anything

1. Read [docs/context.md](docs/context.md), [docs/progress.md](docs/progress.md), and the doc that owns the area you're touching (index: [docs/architecture.md §0](docs/architecture.md)).
2. Follow the locked decision ADR-0001: PINI is a Node.js distribution, not a new engine.
3. Never invent flags, APIs, files, or build steps. Verify them against the pinned upstream source and cite it.

## Change rules (from the charter, vision.md §14)

- **Docs:** accurate, assumptions flagged, related docs updated in the same change.
- **Runtime changes / patches:** reviewed; correctness and compatibility tests pass; security assessed; memory and performance measured; build still reproducible. Patch header format: [docs/security-policy.md §4](docs/security-policy.md).
- **Optimizations:** reproducible bottleneck, a baseline, a narrow change, a measured effect, recorded trade-offs, and an experiment record ([docs/memory-strategy.md §5](docs/memory-strategy.md)).
- **Decisions:** record them in [docs/decision-log.md](docs/decision-log.md).
- **Progress:** update [docs/progress.md](docs/progress.md).

## Sign-off and license

PINI is MIT-licensed (accepted 2026-10-12, ADR-0011). Every commit must carry a **Developer Certificate of Origin** sign-off (`git commit -s`, which adds `Signed-off-by:`). CI will enforce this.

PINI currently has one maintainer. Patches go through the solo review protocol in [docs/security-policy.md §4](docs/security-policy.md): self-review after a cooling-off period, a code-reviewer agent pass, and the full test tier.
