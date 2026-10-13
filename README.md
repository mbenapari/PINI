# PINI

> **Status: Phase 0 (Foundation).** No code or binaries exist yet. These are planning docs only (approved 2026-10-12).

PINI is a memory-efficient JavaScript runtime built as a **downstream distribution of Node.js** and the V8 bundled with it. It does not build a new engine or garbage collector. It focuses on reproducible builds, evidence-based memory defaults, memory diagnostics, and a small set of carefully measured patches, for server workloads (HTTP APIs, Express apps, workers, containers).

**No memory improvements are claimed.** Every future claim will link to reproducible benchmark results.

## Read next

| If you want to... | Read |
|---|---|
| Understand the vision and scope | [docs/vision.md](docs/vision.md) |
| See all docs and the architecture | [docs/architecture.md](docs/architecture.md) |
| Know what's happening now | [docs/progress.md](docs/progress.md) |
| See open decisions | [docs/decision-log.md](docs/decision-log.md) |
| Contribute | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Report a vulnerability | [SECURITY.md](SECURITY.md) |

## Upstream base

Node.js **v26 LTS** (the first v26 LTS release, on or after 2026-10-28). Not pinned yet. See [upstream/version-lock.md](upstream/version-lock.md). First platform: Linux arm64. PINI version numbers are independent of Node.js and V8 versions, and every artifact states the upstream versions it is built from.

## License

MIT, with contributions under DCO sign-off (accepted 2026-10-12, ADR-0011). The `LICENSE` file will be added in task P0-04. Upstream Node.js is MIT-licensed, and its license notices (including third-party ones) ship with every PINI binary.
