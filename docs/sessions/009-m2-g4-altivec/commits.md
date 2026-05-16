# Commits — session 009

Outer repo (this project), in chronological order.

- `7839ad4` — **session 009: M2 — G4 + AltiVec explored, no release**.
  Single landing commit for the session.  Adds `CFLAGS_EXTRA` env
  knob to [`scripts/build-tiger-remote.sh`](../../../scripts/build-tiger-remote.sh)
  + `TIGER_ARCH={g3,g4,g4-altivec}` presets in
  [`scripts/build-tiger.sh`](../../../scripts/build-tiger.sh).  New
  [`tests/bench.janet`](../../../tests/bench.janet) (fib / mandelbrot /
  PEG / marshal, Tiger-portable) +
  [`scripts/run-bench.sh`](../../../scripts/run-bench.sh) (no `seq`,
  no `pipefail` — bash 2.05b on Tiger).
  [`README.md`](../../../README.md): adds G4 Tiger / G4+AltiVec Tiger
  / G4 Leopard rows to the build matrix (🟡 explored), drops the
  ❌-marked AltiVec rows in the language/libraries table.
  [`docs/roadmap.md`](../../roadmap.md): M2 marked ✅ explored with
  benchmark numbers; item 10 (AltiVec source patches) closed.
  [`docs/deferred.md`](../../deferred.md): "AltiVec source patches"
  struck through with link to session 009 findings.

No patches/ change this session (the patch stack stays at 6 from
session 008).  No new release tag (decision: M2 didn't produce a
user-visible artifact worth shipping).

Local artifacts (gitignored, not in tree): `releases/janet-1.41.3-
dev-r3-tiger-g4.tar.gz` and `releases/janet-1.41.3-dev-r3-tiger-g4-
altivec.tar.gz`.  Re-buildable any time via `TIGER_HOST=emac
TIGER_ARCH=g4 RELEASE_REV=r3 bash scripts/build-tiger.sh` (and
`TIGER_ARCH=g4-altivec` for the AltiVec variant).
