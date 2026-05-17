# Session 010 — M3 G5 bootstrap

## Status on arrival

Session 009 closed M2 (G4 + AltiVec) with no release: build pipeline
gained `TIGER_ARCH={g3,g4,g4-altivec}` knobs but benchmark showed
non-invasive AltiVec is a no-op on Janet's interpreter.  v0.2.1 G3
tarball remains the recommended download for all PPC Macs.

Roadmap had M3 split into two items:

- **Item 11** — G5 bootstrap workaround.  Get a working G5 story.
- **Item 12** — true ppc64 build, separate tarball.

Picked item 11 this session, with item 12 re-scoped (see below).

## What happened

### Pre-work: source dive on what ppc64 actually buys Janet

User asked an excellent up-front question: does native 64-bit
support buy Janet anything useful, given the language is nan-boxed?
Worth answering carefully before committing engineering time to
item 12.

Captured in
[`ppc64-value-representation.md`](ppc64-value-representation.md).
Headline findings:

- G3/G4/G5 all have hardware 64-bit doubles.  No software floats
  anywhere.  Janet's `number` type is always a hardware double
  regardless of pointer width.
- 32-bit Janet uses `JANET_NANBOX_32` (8-byte struct with split
  type/payload fields).  64-bit Janet uses `JANET_NANBOX_64` (the
  value lives in a single 64-bit register, with type encoded in
  NaN payload bits).  *Both* are 8 bytes.
- Upstream's auto-detect for `JANET_NANBOX_64` lists `__x86_64__`,
  `_WIN64`, `__riscv`, `__aarch64__`, `_M_ARM64` — **but not
  `__PPC64__`**.  Without a patch, a ppc64 build would silently
  fall back to the 32-bit nanbox layout and forfeit most of the
  win.
- Real ppc64 wins for Janet: native `int/s64`/`int/u64` arithmetic
  (single instruction vs multi-instruction carry chains), and
  single-register value manipulation throughout the interpreter
  inner loop (modest single-digit %).  No FP impact, no precision
  impact.

This shaped the revised scope for roadmap item 12 (see below).

### Item 12 scope expanded

Roadmap [`item 12`](../../roadmap.md#m3--g5--64-bit) re-written to
include a fourth bullet: a small upstreamable patch to add
`__PPC64__` to the `JANET_NANBOX_64` auto-detect at
[`janet.h:313`](../../../external/janet/src/include/janet.h).
Without that patch, the engineering work of producing a ppc64
tarball would yield only the `int/s64` win, not the interpreter
inner-loop win.  ~5 lines, same shape as our existing upstream-able
patches.

### Item 11.a: smoke v0.2.1 G3 tarball on pmacg5

**pmacg5 specs (probed via ssh):** PowerMac G5 (cpu_subtype 100 =
PPC 970), 2 GB RAM, Tiger 10.4.11 (BuildVersion 8S165), Darwin
8.11.0.  `hw.optional.64bitops = 1` confirms the chip's 64-bit ISA
is exposed.  `/opt` already has `gcc-4.9.4`, `gcc-10.3.0`,
`make-4.3`, `ld64-97.17-tigerbrew`, and
`macports-legacy-support-20221029` from prior tigersh installs.
No existing `/opt/janet*`.

Followed the README's curl one-liner verbatim:

```
cd /opt && curl -sSL http://leopard.sh/misc/beta/janet-1.41.3-dev-r3-tiger-g3.tar.gz \
    | gunzip | tar x
```

Tarball extracted to `/opt/janet-1.41.3-dev/`.  `file bin/janet` →
`Mach-O executable ppc`.  `otool -L bin/janet` shows only
`@loader_path/../lib/libMacportsLegacySupport.dylib` and
`/usr/lib/libSystem.B.dylib` — i.e., the standalone-tarball
invariant holds on G5 too.

Smoke ([`build-logs/smoke-pmacg5-g3-tarball.log`](build-logs/smoke-pmacg5-g3-tarball.log)):

- ✅ Basic eval (`hello from janet on tiger ppc — macos`)
- ✅ `janet/version` = 1.41.3-dev
- ✅ `int/s64` / `int/u64` math (sum of two 13-digit values; max
  u64 = `18446744073709551615`)
- ✅ Fiber yield/resume
- ✅ Marshal round-trip with nested table containing array + string
  + nested table
- ✅ PEG match (returns non-nil arrays)
- ✅ `os/execute` `["/bin/echo" ...]` — fork+execve fallback works
- ✅ `os/shell "uname -srm"` — shell-via-spawn works
- ✅ `os/spawn` with `{:out :pipe}`, reading `:all` from the pipe,
  then `os/proc-wait` — full pipe IPC works

### Item 11.b: bench on pmacg5 (best-of-5)

Ran [`tests/bench.janet`](../../../tests/bench.janet) via
[`scripts/run-bench.sh`](../../../scripts/run-bench.sh) — exact
same harness used in session 009.  Log:
[`build-logs/bench-pmacg5-g3-tarball.log`](build-logs/bench-pmacg5-g3-tarball.log).

All three columns below run the *same* v0.2.1 G3 binary; the only
difference is the CPU running it.

| Workload   | pmacg5 (G5 970, this session) | emac (G4 7450 @ 1.42 GHz, session 009) |
|---|---|---|
| fib        | 0.809 s | 1.690 s |
| mandelbrot | 0.407 s | 0.755 s |
| peg-match  | 0.206 s | 0.350 s |
| marshal    | 0.277 s | 0.492 s |
| **total**  | **1.701 s** | **3.288 s** |

(G4 numbers from
[`../009-m2-g4-altivec/build-logs/cross-arch-bench-emac.log`](../009-m2-g4-altivec/build-logs/cross-arch-bench-emac.log)
best-of-5.)

**G5 is ~1.93× faster than the G4 on the same binary.**  pmacg5 is
a PowerMac11,2 ("Power Mac G5 (Late 2005)") at 2.3 GHz × 2 cores
(Janet is single-threaded, so only one core matters).  Clock-speed
ratio alone would predict 2.3/1.42 ≈ 1.62× — actual is 1.93×, i.e.
~19% IPC win on top of the clock advantage.  Consistent with the
970's wider issue width, faster memory bus, and larger caches
helping the interpreter's dispatch loop.

### Item 11.c: can we build Janet natively on G5?

The leopard.sh 1.27.0 recipe died on G5 with `build/janet
tools/patch-header.janet ... → Bus error`.  But that recipe was
1.27.0 (early 2023), and Janet has had many releases since.  We're
on a much newer pinned SHA (1.41.3-dev).  Worth checking whether the
issue reproduces.

Ran the build pipeline with `TIGER_HOST=pmacg5 TIGER_ARCH=g3
scripts/build-tiger.sh`, exact same pipeline that builds on
ibookg38.  Build log:
[`build-logs/build-pmacg5-g3.log`](build-logs/build-pmacg5-g3.log).

**Build succeeded end-to-end with no intervention.**  The
`tools/patch-header.janet` step is still in modern Janet's
[`Makefile:236`](../../../external/janet/Makefile) (runs the
freshly-built `build/janet` to patch the public header) — it just
doesn't bus-error on our pinned SHA + our toolchain (gcc-4.9.4 +
ld64-97.17-tigerbrew + Tiger 10.4.11).  Tarball produced:
1,747,750 bytes (vs 1,747,915 bytes for the equivalent G3-built
`-r3` tarball — 165 bytes apart, well within expected per-build
timestamp/path-string variation).

Saved as
[`releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz`](../../../releases/janet-1.41.3-dev-pmacg5-built-tiger-g3.tar.gz)
(not a release artifact — kept under that name to make the build
host unambiguous).

### Item 11.d: sanity-check G5-built tarball

Extracted both tarballs and ran the G5-built binary on G5.  Smoke
all green.  Bench best-of-5: 1.682 s total vs 1.701 s for the
G3-built tarball on the same hardware — ~1% delta, within noise.
Log:
[`build-logs/bench-pmacg5-g5built.log`](build-logs/bench-pmacg5-g5built.log).

As an aside, `cmp` says the two tarballs' `bin/janet`,
`libjanet.dylib`, `libMacportsLegacySupport.dylib`, `janet.h`, and
man page are all bit-for-bit identical (`libjanet.a` differs only
in `ar` archive timestamps).  Not surprising: both builds used
`TIGER_ARCH=g3` (no `-mcpu`, generic-powerpc target), and both
hosts run the same tigersh-prebuilt gcc-4.9.4 — so the compiler is
asked to produce the same output and dutifully does.  Useful
sanity check (confirms nothing host-specific leaks into the
build); not a project property.

## Findings

The actual novel finding is narrow:

1. **Building Janet on G5 doesn't crash.**  The roadmap had carried
   a "needs bootstrap-on-G3 workaround" caveat since session 001,
   based on leopard.sh 1.27.0's `build/janet tools/patch-header.janet
   → Bus error` on G5.  That caveat no longer applies to our pinned
   SHA (1.41.3-dev) + toolchain (gcc-4.9.4 + ld64-97.17-tigerbrew).
   Either upstream fixed the underlying bug between 1.27.0 and our
   SHA, or it was specific to a toolchain combination we don't use.
   Either way: G5 native builds Just Work, no workaround needed.
   Roadmap item 11 closes by verification.

Things confirmed-but-not-novel along the way:

- v0.2.1 G3 tarball runs on G5 (expected from PPC ISA forward-compat;
  worth verifying once, but no surprise).
- G3-built and G5-built binaries are bit-identical for the default
  no-`-mcpu` build (expected from "same gcc + same flags = same
  bytes"; useful sanity check that nothing host-fingerprint-y leaks
  into the build).
- G5 is faster than G4 (known a priori; nice to have the bench
  numbers for future ppc64 comparisons — 1.701 s G5 vs 3.288 s G4
  on the same binary, ~1.93× including IPC + clock).

**No new release this session.**  Item 11 closed by verification,
not by a new artifact.  v0.2.1 G3 tarball remains the recommended
download for all PPC Macs (G3, G4, G5).  Same precedent as M2 /
session 009.

Separately, the pre-work source dive on Janet's value representation
([`ppc64-value-representation.md`](ppc64-value-representation.md))
expanded the scope of *item 12* (ppc64, M3's remaining work) to
include a small upstream `JANET_NANBOX_64` patch: upstream's
auto-detect at `janet.h:313` doesn't list `__PPC64__`, so without a
patch a ppc64 build would silently fall back to the 32-bit nanbox
and forfeit the inner-loop win.  Roadmap item 12 rewritten to
include this alongside toolchain plumbing, ppc64 mlsupport, and
benchmarking.

## Status on exit

M3 item 11 closed by verification: the "needs G5 bootstrap
workaround" caveat the roadmap had carried since session 001 is
stale.  G5 native builds work; no workaround needed.  No new
release artifact (v0.2.1 G3 tarball still the canonical download).
The implementation-status table in the project README flips the
G5 Tiger row from "❌ M3" to "✅ M3 (userland + build)"; item 12
(ppc64) stays ❌ until that engineering work lands.

Roadmap item 12 scope expanded to include the `JANET_NANBOX_64`
upstream patch as the centerpiece of the perf story for ppc64.
That, plus toolchain plumbing for `-arch ppc64`, plus a ppc64
mlsupport build, is the work to do whenever M3 is resumed.
