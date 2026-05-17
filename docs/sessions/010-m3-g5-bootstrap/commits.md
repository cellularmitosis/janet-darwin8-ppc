# Commits — session 010

Outer repo (this project), in chronological order.

- `bf6bf38` — **session 010: M3 G5 native build verified, no
  release**.  Initial landing commit.  Adds
  [`docs/sessions/010-m3-g5-bootstrap/`](.) with the session
  narrative ([`README.md`](README.md)), the up-front source dive on
  what ppc64 actually buys Janet
  ([`ppc64-value-representation.md`](ppc64-value-representation.md)),
  the next-session primer ([`HANDOFF.md`](HANDOFF.md)), and the
  smoke / bench / build logs from pmacg5 under
  [`build-logs/`](build-logs/).

  [`README.md`](../../../README.md): G5 Tiger row flipped from
  ❌ M3 to ✅ M3 (userland + build).  ppc64 row still ❌ but with
  re-scoped notes pointing at the `JANET_NANBOX_64` auto-detect
  gap.  G3 row note updated to reflect G3-built tarballs now
  verified on G3/G4/G5 across sessions 007/009/010.

  [`docs/roadmap.md`](../../roadmap.md): item 11 marked ✅ (G5
  native build works, no workaround needed).  Item 12 scope
  expanded to four bullets — toolchain plumbing, ppc64 mlsupport,
  `JANET_NANBOX_64` upstream patch, benchmark — with the
  source-dive doc cited.

- `7ae1408` — **clarify byte-identical-binaries precondition**.
  The G3-built vs G5-built bit-identicality is conditioned on the
  `TIGER_ARCH=g3` (no-`-mcpu`, generic-powerpc) build, not a
  property of the build hosts.  Both hosts run the same
  tigersh-prebuilt gcc-4.9.4; with no `-mcpu`, the compiler emits
  the same code regardless of which chip it's running on.
  `TIGER_ARCH=g4` / `g4-altivec` builds (which pass `-mcpu=7450`)
  would NOT exhibit this invariant.  Wording tightened across
  session README, HANDOFF, commits.md, roadmap, and project
  README.

- *(later commit on this date)* — **demote
  byte-identicality from headline finding to sanity check**.
  Naming what was actually novel from the session: only the
  "G5 native build doesn't bus-error anymore" finding is a real
  delta.  G3 tarball running on G5 follows from PPC forward-compat;
  byte-identical binaries follow from "same gcc + same flags =
  same bytes" (a property of gcc, not of this project); G5 being
  faster than G4 was known a priori.  Wording tightened across
  session README ("Findings" rewritten), HANDOFF ("Where things
  stand" + "Gotchas" + starting prompt), roadmap (item 11 shrunk
  to a single paragraph), and project README G5 row.

No `patches/` change this session (patch stack stays at 6 from
session 008).  No new release tag.

Local artifact (gitignored, not in tree):
`releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz` — the
G5-built tarball, kept locally to prove the build works.
Re-buildable any time via `TIGER_HOST=pmacg5 TIGER_ARCH=g3 bash
scripts/build-tiger.sh`.
