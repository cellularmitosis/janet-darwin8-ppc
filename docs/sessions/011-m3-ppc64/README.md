# Session 011 — M3 ppc64 (released as v0.2.2)

## Status on arrival

Session 010 closed M3 item 11 by verification: building Janet on G5
doesn't crash anymore, so the roadmap's "needs bootstrap-on-G3
workaround" caveat was stale.  v0.2.1 G3 tarball remained the
canonical download for all PPC Macs.  M3's remaining substantive
work was [item 12](../roadmap.md#m3--g5--64-bit): a separate ppc64
tarball variant.

Scope (carried from session 010):
1. Toolchain plumbing — `-arch ppc64` through `CFLAGS`/`LDFLAGS`.
2. macports-legacy-support for ppc64 — bundle under `@loader_path/`.
3. `JANET_NANBOX_64` patch — extend upstream's auto-detect to
   include `__PPC64__`.  Verify 47-bit invariant on Tiger ppc64
   userland first.
4. Benchmark vs ppc32 on the same G5 hardware.

Background source dive:
[`../010-m3-g5-bootstrap/ppc64-value-representation.md`](../010-m3-g5-bootstrap/ppc64-value-representation.md).

## What happened

### Probe: 47-bit address-space invariant on Tiger ppc64

First-cut probe ([`probe-address-space.c`](probe-address-space.c))
showed stack pointers at bit 50 — the invariant the upstream
NANBOX_64 path comments rely on appears violated.  Second probe
([`probe-address-space-v2.c`](probe-address-space-v2.c)) narrowed
the check to *what Janet actually NaN-boxes*: heap allocations
(any size up to 256 MB), function pointers in main binary +
libSystem + libm + libMacportsLegacySupport, static `.data`/`.bss`/
`.rodata`, and mmap-anon regions.  Every one of those addresses
lives below 2^31 on Tiger ppc64.  Only the stack reaches bit 50,
and Janet doesn't NaN-box stack pointers.  Verdict: the invariant
holds for our use; we can use the default `JANET_NANBOX_64` layout
(shift=0, no pointer-alignment trick).

Probe logs:
- [`build-logs/probe-address-space-v1.log`](build-logs/probe-address-space-v1.log)
  (stack at bit 50 — alarming until you realize Janet doesn't wrap
  stack pointers)
- [`build-logs/probe-address-space-v2.log`](build-logs/probe-address-space-v2.log)
  (focused on Janet-wrappable pointers — all good)

### Toolchain plumbing

`scripts/build-tiger.sh` gained:
- New `TIGER_ARCH=g5-ppc64` preset → `CFLAGS_EXTRA="-m64"`.
- New `LDFLAGS_EXTRA` env var, plumbed through to the remote build
  (necessary because Janet's Makefile doesn't propagate `$CFLAGS`
  to `$LDFLAGS`, and `-m64` must reach the link step to produce a
  ppc64 binary).  `TIGER_ARCH=g5-ppc64` sets it to `-m64`.
- Auto-flip of `LEGACY_SUPPORT_PREFIX` to the `.ppc64` variant when
  `TIGER_ARCH=g5-ppc64` and the caller didn't override.

`scripts/build-tiger-remote.sh` accepts `LDFLAGS_EXTRA` and appends
it to the link line.  Otherwise unchanged.

`BOOT_CFLAGS` deliberately stays 32-bit — `janet_boot` is a build-
host-only tool, the G5 runs both bitnesses natively, so no
bootstrap juggling is needed.

### macports-legacy-support.ppc64

Already a packaged tigersh artifact: `tiger.sh
macports-legacy-support-20221029.ppc64` downloads a prebuilt 62 KB
binary tarball.  Installs to `/opt/macports-legacy-support-20221029.ppc64/`.
ppc64 build of the same library, depends on
`/usr/lib/libgcc_s_ppc64.1.dylib` (stock Tiger, Jan 2006).  Zero
project work needed here.

### Discovered: `JANET_NANBOX_64` on big-endian ppc64 is broken

Wrote [`patches/0007-janet.h-enable-JANET_NANBOX_64-on-ppc64.patch`](nanbox64-investigation/0007-janet.h-enable-JANET_NANBOX_64-on-ppc64.patch)
adding `__PPC64__` / `__ppc64__` to the auto-detect at
[`janet.h:313`](../../external/janet/src/include/janet.h).  Built
cleanly.  Smoke passed superficially:

- `(print "hello")` works.
- `int/s64`/`int/u64` constructors work.
- Type checks (`(type a)`, `(array? a)`, etc.) work.
- Reading: `(get arr 0)` works.

But under deeper probing:

```
(var x 42)        # x reads back as nil
(put @[10 20] 0 100)   # silent no-op
(array/push @[] 42)    # works
(put @{:a 1} :b 2)     # works (tables ok)
```

**Array `put` silently no-ops** on ppc64 + NANBOX_64.  Tables work.
Top-level `var` is broken as a consequence (its implementation uses
`put` on a 1-element array).  Function-local `var` (inside `do`,
`fn`, `let`) works because the compiler keeps it as a stack slot.

Sanity-checked all the obvious things:
- `janet/config-bits = 1` — NANBOX_BIT is set.
- `nm` shows `_janet_nanbox_to_pointer` — confirming NANBOX_64
  path is in the binary.
- Rebuilt ppc64 *without* the patch → falls back to upstream's
  16-byte non-nanbox struct → put works, var works, everything
  correct.

So this is a real **big-endian Janet bug** in the NANBOX_64 path.
We're the first to hit it because x86_64, aarch64, and RISC-V (the
only other architectures with NANBOX_64 enabled upstream) are all
little-endian by default.

Suspect: the `Janet` union (`uint64_t u64; int64_t i64; double
number; void *pointer;`) being passed by value through the
`janet_nanbox_to_pointer` / `janet_nanbox_from_pointer` functions
hits a Darwin ppc64 ABI corner case around integer/float-mixed
unions.  But the precise mechanism is untested.  Full writeup +
parked patch in
[`nanbox64-investigation/`](nanbox64-investigation/).

**Decision: ship without `JANET_NANBOX_64`.**  The no-nanbox build
is correct and still 15% faster than ppc32 (per below).  The
NANBOX_64 patch and the bug become a future upstream contribution.

### Bench (final, on imacg52)

Initial bench on pmacg5 showed noisy and counter-intuitive numbers
(ppc64 *slower* than ppc32).  User pointed out pmacg5 is shared
with sibling projects and saved a project memory preferring
imacg52 — an iMac G5 (1.42 GHz... actually 2.0 GHz dual G5 970,
2 GB RAM, Tiger 10.4.11) dedicated to this project.

Re-benched on imacg52 (5 runs each, best-of, all same hardware,
same workload):

| Workload   | ppc32 r4 (G3-tuned, run on G5) | ppc64 r4 (no-nanbox) | Δ |
|---|---|---|---|
| fib        | 0.878 s | 0.773 s | −12.0% |
| mandelbrot | 0.469 s | 0.309 s | −34.1% |
| peg-match  | 0.237 s | 0.250 s | +5.5% |
| marshal    | 0.366 s | 0.317 s | −13.4% |
| **total**  | **1.951 s** | **1.656 s** | **−15.1%** |

Log: [`build-logs/bench-imacg52-r4-final.log`](build-logs/bench-imacg52-r4-final.log).

The mandelbrot win (~34%) dominates and matches the source-dive
prediction: G5's wider FP pipeline, more registers, and the 64-bit
register set let gcc-4.9 emit much tighter FP-heavy inner loops.
fib + marshal wins (~12-13%) come from the VM dispatch loop holding
fewer values in stack memory thanks to native 64-bit registers.
PEG slows down by ~5% — probably the doubled struct/pointer size in
its inner loops costs more L1 traffic than ppc64 buys back.

We measured a separate broken NANBOX_64 build at 1.634 s total —
only 1.4% faster than no-nanbox, mostly noise.  Strong evidence
the ppc64 win is from *being 64-bit*, not from the NANBOX_64
layout per se.  (Which makes sense — the bench doesn't exercise
`int/s64`, which is where NANBOX_64's other claimed win would
materialize.  We tried an `int/s64` bench but ran into the put bug
in the NANBOX_64 build before getting clean numbers.)

### v0.2.2 release

Cut as the M3-completing release.  Tarballs (all `r4`):
- `janet-1.41.3-dev-r4-tiger-g3.tar.gz` — bundled G3 (same Janet
  behavior as v0.2.1 r3; rev bump for release consistency).
- `janet-1.41.3-dev-r4-tiger-g3-byo.tar.gz` — BYO G3 (same).
- `janet-1.41.3-dev-r4-tiger-g5-ppc64.tar.gz` — **NEW.**

The G3 tarballs are byte-equivalent to v0.2.1's r3 modulo gzip
timestamps; we keep them in the release for "one URL prefix per
release version" cleanliness.

Distribution: GitHub release, scp to `mini10v:` (source of truth)
and `leopard.sh:` (direct, for immediate visibility).

## Status on exit

M3 closed: roadmap items 11 (G5 bootstrap, session 010) and 12
(ppc64, this session) both ✅.  v0.2.2 is the current recommended
release — G3 tarball remains the universal "works on every PPC Mac"
download; G5 owners get a 15% faster variant they can install with
the same one-liner.

Project's release pipeline now handles three architectures (G3
default, G4-tuned variants explored, G5 ppc64 shipped) through the
single `TIGER_ARCH={g3,g4,g4-altivec,g5-ppc64}` knob.  Patch stack
stays at 6 (no NANBOX_64).  The parked NANBOX_64 work is upstream
material; we're not blocked on it.
