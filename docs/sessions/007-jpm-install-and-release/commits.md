# Commits — session 007

Outer repo (this project), in order of intent.  Backfilled with the
real SHA after each commit lands.

- (TBD) `session 007: BYO macports-legacy-support build mode +
  RELEASE_REV tarball naming` — `scripts/build-tiger.sh` and
  `scripts/build-tiger-remote.sh` learn `BYO_MACPORTS_LEGACY=1`
  (skip bundle + install_name rewrite for libMacportsLegacySupport.dylib)
  and `RELEASE_REV=<rev>` (append a project-level revision marker
  to the tarball basename so we can cut multiple releases at the
  same pinned upstream SHA without filename collision).
- (TBD) `session 007: v0.2.0 demo (jpm install janet-lzo end-to-end)` —
  `demos/v0.2.0-jpm-install-lzo.{janet,sh}` + demos/README.md update.
  The `.sh` is a one-command pipeline (tigersh prereqs → curl tarball
  → bootstrap jpm with a Tiger-specific config → `jpm install
  https://github.com/cellularmitosis/janet-lzo` → run the `.janet`).
  The `.janet` does an `os/spawn` round-trip + an lzo round-trip
  through the jpm-installed module.
- (TBD) `session 007: v0.2.0 release notes + README/roadmap updates` —
  outer README's status, releases table, and build-matrix flipped
  for M1.b.  Roadmap items 8 / 9 / 10 marked ✅.

External/janet branch: no patches changed this session.  Patch
series unchanged from session 006.
