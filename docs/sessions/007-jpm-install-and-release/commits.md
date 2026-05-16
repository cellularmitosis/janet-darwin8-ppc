# Commits — session 007

Outer repo (this project).

- `b0b64c5` — **session 007: M1.b release (v0.2.0 — jpm install
  end-to-end, BYO mode)**.  One coarse commit bundling all of:
  - `scripts/build-tiger.sh` + `scripts/build-tiger-remote.sh` learn
    `BYO_MACPORTS_LEGACY=1` (skip bundle + install_name rewrite for
    libMacportsLegacySupport.dylib) and `RELEASE_REV=<rev>`
    (project-level revision marker for the tarball basename).
  - `demos/v0.2.0-jpm-install-lzo.{janet,sh}` + `demos/README.md`
    update — the one-command M1.b acceptance pipeline.
  - Outer `README.md` status / build-matrix / language / linking
    tables flipped to ✅ M1.b.
  - `docs/roadmap.md` items 8 / 9 / 10 marked ✅.
  - Session 007 `README.md`, `HANDOFF.md`, `commits.md`,
    `build-logs/`.
  - `.gitignore` gains `.claude/` (was already staged on arrival).
- `9eac6bd` — **session 007: README — Why-section + releases-table
  entry for v0.2.0**.  Stragglers from the first commit: past-tense
  the Why-section's posix_spawn paragraph and add a v0.2.0 row to
  the Releases table.

GitHub release: [v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0)
with both tarballs attached.  Pushed to `origin/main`
(`f988573..9eac6bd`).

External/janet branch: no patches changed this session.  Patch
series unchanged from session 006.
