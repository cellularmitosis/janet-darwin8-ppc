# HANDOFF — session 010 → 011

## Where things stand

**M3 item 11 closed; no release.**  Actual novel finding from the
session is narrow: **building Janet on G5 doesn't crash anymore.**
The roadmap had carried a "needs bootstrap-on-G3 workaround"
caveat since session 001, based on leopard.sh 1.27.0's
`build/janet tools/patch-header.janet → Bus error` on G5.  That
caveat is stale on our pinned SHA (1.41.3-dev) + toolchain
(gcc-4.9.4 + ld64-97.17-tigerbrew): `TIGER_HOST=pmacg5
scripts/build-tiger.sh` runs end-to-end and produces a working
tarball.  No workaround needed.

Confirmed-but-not-novel along the way:

- v0.2.1 G3 tarball runs on pmacg5 (PowerMac G5 970, 2.3 GHz dual,
  Tiger 10.4.11) — full smoke including `os/spawn`, PEG, fibers,
  marshal, `int/s64`.  Expected from PPC ISA forward-compat; worth
  verifying once.
- G3-built and G5-built tarballs are bit-identical for the default
  `TIGER_ARCH=g3` (no-`-mcpu`) build.  Expected from "same gcc +
  same flags = same bytes" — both hosts run the same
  tigersh-prebuilt gcc-4.9.4, so the compiler is asked to produce
  the same output and dutifully does.  Useful sanity check that
  nothing host-fingerprint-y is leaking into the build; not a
  project property.
- G5 is faster than G4 (1.701 s vs 3.288 s total on the same
  binary, ~1.93×).  Useful data point for the eventual item 12
  ppc64-vs-ppc32 comparison on the same hardware.

v0.2.1 G3 tarball remains the recommended download for **all PPC
Macs** — now verified on G3 (session 007 on ibookg37), G4 (session
009 on emac/pbookg42/mdd), and G5 (this session on pmacg5).
Project README's G5 Tiger row flips from ❌ M3 to ✅ M3 (userland
+ build).

Patch stack unchanged at 6.  Same stable resting point as after
session 009.  M3 ppc64 (item 12) remains as the substantive M3 work,
with re-scoped to include a small upstream `JANET_NANBOX_64` patch.

## Suggested next moves

All carry-forward from session 009, with M3-item-11 now closed.
The numbered identity scheme from 009's HANDOFF stays.

**A. Upstream PR for the posix_spawn patches.**  (Carry-forward from
sessions 007, 008, 009.)  User has indicated upstream conversation is
ongoing; not for us to drive in-project.  Track in
[`deferred.md`](../deferred.md).

**B. ~~M2 — G4 + AltiVec.~~** *Closed session 009.*

**C. M3 — ppc64.**  (Carry-forward, scope expanded session 010.)
This is the substantive M3 work now.  Roadmap item 12 was rewritten
this session
([`../roadmap.md`](../roadmap.md#m3--g5--64-bit)) to include four
bullets:

  1. Toolchain plumbing — `-arch ppc64` in `CFLAGS`/`LDFLAGS`,
     `BOOT_CFLAGS` can stay 32-bit (bootstrap runs on build host
     only).
  2. macports-legacy-support for ppc64 — build the dylib with
     `-arch ppc64`, bundle in tarball under `@loader_path/`.
  3. `JANET_NANBOX_64` patch — upstream's
     [`janet.h:313`](../../external/janet/src/include/janet.h)
     auto-detect lists `__x86_64__` / `_WIN64` / `__riscv` /
     `__aarch64__` / `_M_ARM64` but not `__PPC64__`.  Without
     intervention, ppc64 builds fall back to 32-bit nanbox.  ~5
     lines, upstreamable shape.  **Verify the 47-bit-address-space
     invariant holds for Tiger ppc64 userland first** — if not, use
     the `JANET_NANBOX_64_POINTER_SHIFT` variant the aarch64 path
     uses.
  4. Benchmark — same methodology as M2 / session 009.  Expect
     modest single-digit-% interpreter wins + a real win on
     `int/s64`-heavy paths.  No FP impact (G5 doubles are the
     same as G3 doubles, hardware-wise).  Ship the variant only if
     measurable.

  See
  [`ppc64-value-representation.md`](ppc64-value-representation.md)
  for the source dive that established this scope.

**D. Tiger-specific test failures.**  (Carry-forward.)  Two parked
items in [`deferred.md`](../deferred.md):
  - `os/realpath` doesn't error on nonexistent paths.
  - `suite-filewatch.janet` 17/23 on Tiger.

**E. Upstream patch 0006 (`:cd` tests) as a small PR.**  (Carry-
forward.)  User indicated upstream is being handled out-of-band.

**F. macports-legacy-support: add `CLOCK_PROCESS_CPUTIME_ID`.**
(Carry-forward.)  Out-of-project (mlsupport's repo).  Would
unblock the reverted #937 simplification.

**G. `-static-libgcc` for sister Tiger projects.**  (Carry-forward.)
Apply session 008's `-static-libgcc` trick to leopard.sh / other
sister projects.

**H. Stress-test the bench under varied workloads.**  (New from
session 009.)  If a real user surfaces a Janet workload that's
plausibly AltiVec- or ppc64-friendly, expand `tests/bench.janet`.

The natural pick for an in-project session is **C** — it's the
remaining substantive M3 work and the bitness source-dive in
[`ppc64-value-representation.md`](ppc64-value-representation.md)
already set the table.

## Where canonical artifacts live after this session

- [`docs/sessions/010-m3-g5-bootstrap/ppc64-value-representation.md`](ppc64-value-representation.md) —
  source-dive findings on what ppc64 buys Janet (the `JANET_NANBOX_*`
  layouts, what's hardware-FPU-native on G3 vs ppc64, where the
  real wins live).  Drives the scope of item 12.
- [`docs/sessions/010-m3-g5-bootstrap/README.md`](README.md) — full
  narrative of this session.
- [`docs/sessions/010-m3-g5-bootstrap/build-logs/`](build-logs/) —
  smoke / bench / build logs from pmacg5.
- [`docs/roadmap.md`](../../roadmap.md) — item 11 marked ✅; item
  12 scope expanded to include `JANET_NANBOX_64` patch.
- [`README.md`](../../../README.md) — G5 Tiger row flipped to ✅
  M3 (userland + build); ppc64 row still ❌ but with re-scoped
  notes.  G3 row note updated to reflect G3-built tarballs now
  verified on G3/G4/G5.
- [`releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz`](../../../releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz)
  — G5-built tarball.  **Not a release artifact.**  Kept locally to
  prove the G5 build works; functionally byte-equivalent to the
  G3-built v0.2.1 r3 tarball.

## Gotchas not to re-step on

**All sessions 003-009 gotchas still apply.**  New from this session:

- **The `tools/patch-header.janet` Bus error from leopard.sh 1.27.0
  does not reproduce on Janet 1.41.3-dev** with gcc-4.9.4 +
  ld64-97.17-tigerbrew on G5.  The roadmap's "bootstrap on G3, scp
  to G5" workaround is therefore not needed.  Don't waste effort on
  it.  If a future release re-introduces a G5-specific crash, that's
  new work — investigate with `gdb` against the actual binary, not
  by re-trying the 1.27.0-era workaround.

- **G3-built vs G5-built bit-identicality is a sanity check, not a
  project property.**  For `TIGER_ARCH=g3` (no `-mcpu`,
  generic-powerpc target), the two tarballs' `bin/janet`,
  `libjanet.dylib`, `libMacportsLegacySupport.dylib`, and `janet.h`
  are byte-for-byte equal; only `libjanet.a` differs (and only in
  `ar` archive timestamps).  That follows from "same gcc-4.9.4
  prebuilt + same source + same flags = same bytes" — both hosts
  run the identical tigersh prebuilt.  Useful confirmation that
  nothing host-specific leaks into the build (e.g. no `__DATE__`,
  no host fingerprint in a static string).  If a future
  default-tuning build *isn't* bit-identical between hosts, that's
  a real signal worth chasing.  But the invariant does NOT extend
  to `TIGER_ARCH=g4` / `g4-altivec` (where `-mcpu=7450`
  intentionally changes codegen).

- **`int/s64` is a Janet builtin — no `import` needed.**  Spent two
  minutes confused why `(import _system :prefix "")` errored.  The
  64-bit-integer types `int/s64` and `int/u64` are in the prelude.

- **PEG `peg/match` matches from position 0** and returns `nil` on
  no-match.  `(peg/match :d+ "abc12345xyz")` returns nil — `:d+`
  doesn't match the leading "abc".  Use `(peg/find :d+ "...")` to
  find anywhere, or anchor with `(any (+ (capture :d+) 1))` for
  "find all".  This is documented but easy to forget; cost me a
  re-run.

- **`print` on PEG-match results shows `<array 0x...>`, not the
  contents.**  Use `pp` or `(string/format "%q" ...)` to see the
  actual matched values.  Doesn't affect functionality but can
  fool an interactive smoke into looking like it failed.

- **`tools/patch-header.janet` is still in modern Janet's
  Makefile** ([line 236](../../external/janet/Makefile)).  It runs
  the freshly-built `build/janet` — not `janet_boot`.  If a future
  Janet release introduces something that triggers a Bus error in
  this step, you'd see "make" stop somewhere between the
  `build/janet` link and the final tarball assembly.  Look for the
  exact `./build/janet tools/patch-header.janet` invocation in the
  build log.

- **pmacg5 has 2 GB RAM and is a Late 2005 PowerMac11,2.**  No need
  to baby it on memory like ibookg38 (384 MB).  Build runs at full
  speed; bench is reproducible to ±0.005 s on `total`.

- **The 2.3 GHz G5 vs 1.42 GHz G4 perf ratio is 1.93×, not 1.62×
  (clock ratio).**  The ~19% IPC win on top of clock is consistent
  across all four bench workloads.  Worth knowing when reasoning
  about whether a G5-specific build is worth shipping: a lot of the
  perf is "the chip is just faster," not "the binary was tuned for
  it."  Item 12's ppc64 question is *separately* about whether
  Janet specifically can extract more wins from native 64-bit
  registers / nanbox — not about whether G5 is fast in general.

- **`hw.optional.64bitops = 1` on pmacg5** confirms ppc64 userland
  is supported on this hardware.  Necessary precondition for item
  12; we have it.

- **Avoid asserting hardware specs without verifying.**  Spent a
  re-edit cycle changing "2.0 GHz dual" → "2.3 GHz dual" after
  actually running `sysctl hw.cpufrequency`.  When writing perf
  comparisons into docs, run the `sysctl` first.

## Starting prompt for session 011

```
Starting session 011.  Read docs/sessions/010-m3-g5-bootstrap/
HANDOFF.md and README.md.

Session 010 closed M3 item 11 by verification: **building Janet
on G5 doesn't crash anymore.**  The roadmap's
"needs-bootstrap-on-G3 workaround" caveat — from leopard.sh 1.27.0's
G5 Bus error — is stale on our pinned SHA + toolchain.  G5 native
builds Just Work, no workaround needed.  v0.2.1 G3 tarball also
runs cleanly on pmacg5 (expected from PPC forward-compat).  No new
release artifact.

Item 12 scope expanded in session 010 to include a small upstream
`JANET_NANBOX_64` patch — see docs/sessions/010-m3-g5-bootstrap/
ppc64-value-representation.md for the source dive.

Pick one (carry-forward from 009 + 010):
  C. M3 — ppc64 build with JANET_NANBOX_64 enabled
     (toolchain plumbing → ppc64 mlsupport → nanbox patch →
      benchmark vs ppc32 on same G5 hardware → decision on
      shipping the variant).  Substantive M3 work, mostly novel.
  D. Tiger test failures parked in docs/deferred.md
     (os/realpath, suite-filewatch.janet)
  F. macports-legacy-support: add CLOCK_PROCESS_CPUTIME_ID
  G. Apply -static-libgcc to sister Tiger projects
  H. (Stretch) Stress-test bench under varied workloads

Each has its own writeup in HANDOFF.md "Suggested next moves".
```
