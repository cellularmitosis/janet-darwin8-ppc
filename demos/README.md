# demos/

One runnable Janet program per release, showcasing what that release
unlocked.  Pattern borrowed from sister projects
[`tcc-darwin8-ppc/demos/`](../../tcc-darwin8-ppc/demos/) and
[`ghc-darwin8-ppc/demos/`](../../ghc-darwin8-ppc/demos/).

Naming: `vX.Y.Z-<slug>.{janet,sh}`.  The shell variants exist when
the demo needs a curl + tarball-install preamble.

Empty for now.  The first demo will ship with v0.1.0:

- `v0.1.0-hello.janet` — bare `(print "hello from janet on tiger ppc")`,
  the smallest-possible "it works" artifact.
- `v0.1.0-lzo.sh` — install Janet + janet-lzo on a clean Tiger box via
  curl one-liners, then round-trip a small string through LZO.  The
  acceptance-gate demo for M1.

Pick a tiny program that compiles and runs end-to-end on a real Tiger
box; the goal is "someone landing on the release tag can paste a one-
liner and see it work."
