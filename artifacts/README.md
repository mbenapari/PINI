# artifacts/

Local build outputs: binaries, tarballs, images, and `result.json` files. This directory is gitignored except for this README. No binaries or large build outputs are committed (charter §15).

Every artifact here must be reproducible from the repository: the upstream lock (`upstream/version-lock.md`), a build flavor (`config/build/`), and its release manifest (doc 07 §3). Any number quoted in a doc links to a `result.json` with a manifest (doc 02 §7).
