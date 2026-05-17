# Commits — session 010

Outer repo (this project), in chronological order.

- *(landing commit, to be assigned at commit time)* — **session
  010: M3 G5 userland + native build verified, no release**.
  Single landing commit for the session.

  Adds [`docs/sessions/010-m3-g5-bootstrap/`](.) with the full
  narrative ([`README.md`](README.md)), the up-front source dive on
  what ppc64 actually buys Janet
  ([`ppc64-value-representation.md`](ppc64-value-representation.md)),
  the next-session primer ([`HANDOFF.md`](HANDOFF.md)), and the
  smoke / bench / build logs from pmacg5 under
  [`build-logs/`](build-logs/).

  [`README.md`](../../../README.md): G5 Tiger row flipped from
  ❌ M3 to ✅ M3 (userland + build) with bench numbers and the
  byte-identical-binaries finding inline (with the
  `TIGER_ARCH=g3`/no-`-mcpu` precondition called out).  ppc64 row still ❌ but
  with re-scoped notes pointing at the `JANET_NANBOX_64`
  auto-detect gap.  G3 row note updated to reflect that G3-built
  tarballs have now been verified on G3/G4/G5 across sessions
  007/009/010.

  [`docs/roadmap.md`](../../roadmap.md): item 11 marked ✅ (G5
  userland + build verified, no workaround needed).  Item 12
  scope expanded to four bullets — toolchain plumbing, ppc64
  mlsupport, `JANET_NANBOX_64` upstream patch, benchmark — with
  the source-dive doc cited.

No `patches/` change this session (patch stack stays at 6 from
session 008).  No new release tag (decision consistent with M2 /
session 009: the G5-built tarball is byte-equivalent to the
G3-built v0.2.1 r3 tarball, so there's nothing user-visible to
ship).

Local artifact (gitignored, not in tree):
`releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz` — the
G5-built tarball, kept locally to prove the build works.
Re-buildable any time via `TIGER_HOST=pmacg5 TIGER_ARCH=g3 bash
scripts/build-tiger.sh`.
