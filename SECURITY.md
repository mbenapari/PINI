# Security Policy

> **Stub, Phase 0.** PINI has no released artifacts yet. Internal requirements: [docs/security-policy.md](docs/security-policy.md).

## Reporting a vulnerability

**Private contact: afa.hamdu@gmail.com** (accepted 2026-10-12, decision D-02). Please email vulnerability reports privately to this address.

Include:
- the PINI version and build flavor (from `pini-manifest.json`, once releases exist), plus the upstream Node.js version;
- steps to reproduce, and the impact you observed or expect;
- whether you have told anyone else.

You will get an acknowledgement, then a determination of whether the issue is in PINI or upstream ([docs/security-policy.md §9](docs/security-policy.md#9-vulnerability-handling-pini-specific-bugs)).

Also:
- **Vulnerabilities in Node.js or V8 themselves:** report them upstream through the Node.js process (HackerOne, per https://github.com/nodejs/node/blob/main/SECURITY.md), not to PINI.
- **Do not** open public issues for suspected vulnerabilities, and never attach heap snapshots or diagnostic reports to public issues. They can contain secrets.

## Supported versions

None yet. Each PINI release will state its upstream Node.js/V8 base and its support status (`supported`, `security-only`, or `retired`).

## Upstream security updates

PINI tracks Node.js security releases (https://nodejs.org/en/blog/vulnerability). PINI triages each upstream security release within 2 business days. For High/Critical issues affecting the pinned line, a PINI release follows within 7 days; for other issues, within 30 days (accepted 2026-10-12; details in [docs/security-policy.md §8](docs/security-policy.md#8-upstream-security-tracking)).
