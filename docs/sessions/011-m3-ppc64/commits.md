# Commits — session 011

Outer repo (`janet-darwin8-ppc`):

- `b15e2e1` — session 011: M3 ppc64 — TIGER_ARCH=g5-ppc64 build pipeline

Inner repo (`external/janet/`, darwin-ppc branch):

- No new patches in the canonical set this session.  We prototyped
  a 7th patch (NANBOX_64 on ppc64), exercised it on a build, hit a
  real big-endian bug in upstream's NANBOX_64 path, and parked the
  patch in [`nanbox64-investigation/`](nanbox64-investigation/) for
  future upstream submission.  The canonical patch stack remains 6.

Release:

- Tag `v0.2.2` on outer repo `main`
  (https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.2)
- GitHub release with three tarballs:
  - `janet-1.41.3-dev-r4-tiger-g3.tar.gz`
  - `janet-1.41.3-dev-r4-tiger-g3-byo.tar.gz`
  - `janet-1.41.3-dev-r4-tiger-g5-ppc64.tar.gz`
- Mirrored at `http://leopard.sh/misc/beta/` (direct + via mini10v).
