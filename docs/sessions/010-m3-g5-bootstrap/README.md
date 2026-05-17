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

### Item 11.d: G3-built vs G5-built byte-comparison

Extracted both tarballs and compared the install trees:

| File | G3-built vs G5-built |
|---|---|
| `bin/janet` | ✅ byte-identical |
| `lib/libjanet.1.41.3-dev.dylib` | ✅ byte-identical |
| `lib/libMacportsLegacySupport.dylib` | ✅ byte-identical |
| `include/janet/janet.h` | ✅ byte-identical |
| `share/man/man1/janet.1` | ✅ byte-identical |
| `lib/libjanet.a` | differs *only* in `ar` archive timestamps; the embedded `janet.o`, `shell.o`, and `__.SYMDEF SORTED` blobs are byte-identical |

**Janet's build is bit-deterministic across G3 and G5 build hosts**
with our toolchain.  Same gcc-4.9.4 + same Janet source + same
mlsupport headers = same binary, modulo `ar` timestamps.

### Item 11.e: bench G5-built tarball on G5

Same harness as 11.b.  Log:
[`build-logs/bench-pmacg5-g5built.log`](build-logs/bench-pmacg5-g5built.log).
Best-of-5: total 1.682 s vs 1.701 s for the G3-built tarball on
the same hardware.  ~1% delta, within noise — expected, since
the binaries are bit-identical.

## Findings

1. **The G3 tarball already covers G5 users.**  `bin/janet`,
   `os/spawn`, PEG, fibers, marshal, `int/s64`, the whole stack
   works.  The v0.2.1 curl one-liner from the project README runs
   verbatim on pmacg5 and produces a working `/opt/janet-1.41.3-dev/`.

2. **No G5 bootstrap workaround is needed.**  Janet 1.41.3-dev
   builds natively on G5 with our pipeline.  The leopard.sh
   1.27.0-era Bus error does not reproduce — either it was fixed
   upstream between Janet 1.27.0 and 1.41.3-dev, or it was specific
   to a different toolchain combination (different gcc / different
   `ld64` / different `mlsupport` than what we use).  Either way,
   the "build a bootstrap janet on G3, scp it to G5" plan from the
   roadmap is unnecessary.

3. **G3-built and G5-built binaries are bit-identical** with our
   toolchain — same compiler, same mlsupport, same source → same
   output bytes.  Useful invariant for build reproducibility.

4. **G5 is ~1.93× faster than the 1.42 GHz G4** on the same Janet
   binary (~19% IPC win on top of the 1.62× clock-speed ratio).

5. **No new release this session.**  Item 11 closed by verification,
   not by a new artifact.  v0.2.1 G3 tarball remains the recommended
   download for all PPC Macs (G3, G4, G5).  Same precedent as M2 /
   session 009: we don't ship variant tarballs unless they offer
   something measurably different from what we already publish.

6. **Item 12 (ppc64) is now the substantive M3 work.**  The bitness
   source dive
   ([`ppc64-value-representation.md`](ppc64-value-representation.md))
   established that the real ppc64 win for Janet requires patching
   the upstream `JANET_NANBOX_64` auto-detect at `janet.h:313` to
   include `__PPC64__`.  Without that patch a ppc64 build would
   silently fall back to the 32-bit nanbox and forfeit the
   inner-loop win.  Roadmap item 12 re-written to include this as
   a fourth bullet alongside toolchain plumbing, mlsupport-ppc64,
   and benchmarking.

## Status on exit

M3 item 11 closed by verification (no new artifact).  Project
status unchanged user-side: v0.2.1 G3 tarball remains the
recommended download — but now empirically verified on the full
G3/G4/G5 spread (G3 verified in session 007 on ibookg37; G4 in
session 009 on emac/pbookg42/mdd; G5 in this session on pmacg5).
The implementation-status table in the project README gets a row
flipped from "❌ M3" to "✅ M3 (userland)" for G5, with item 12
(ppc64) staying ❌ until that engineering work lands.

Roadmap item 12 scope expanded to include the `JANET_NANBOX_64`
upstream patch as the centerpiece of the perf story for ppc64.
That, plus the toolchain plumbing for `-arch ppc64`, plus a
ppc64 mlsupport build, is the work to do whenever M3 is resumed.
