# Session 009 — M2 (G4 + AltiVec)

**Status on arrival.**  v0.2.1 shipped end of session 008 — bundled
G3 tarball is genuinely standalone (no `/opt` prereqs after
`-static-libgcc`), patch stack is 6, project at a stable resting
point.  M1 done.  This session picks up M2 from the
[roadmap](../../roadmap.md): G4-tuned tarball (`-mcpu=7450`) and a
second tarball with AltiVec turned on (`-mcpu=7450 -maltivec
-mabi=altivec`), with a G3 vs G4 vs G4+AltiVec benchmark on the same
G4 hardware.

## Fleet probe

Picked the build/test hosts by probing the G4s listed in
`~/.ssh/config` (`pbookg4`, `pbookg42`, `mdd`, `emac`, `emac2`,
`emac3`).

| Host | OS | Model | RAM | CPU | Load | tigersh toolchain | Notes |
|---|---|---|---|---|---|---|---|
| `pbookg4` | offline | — | — | — | — | — | timed out |
| `pbookg42` | Leopard 10.5.8 | PowerBook5,2 | 1 GB | 1.25 GHz G4 | 0.00 | partial (gcc-4.9.4 + mlsupport) | Leopard test host |
| `mdd` | Leopard 10.5.8 | PowerMac3,6 | 1 GB | 1.25 GHz G4 | 1.06 | partial (gcc-4.9.4 + make-4.3, has leopard.sh) | Leopard / leopard.sh test case |
| `emac` | **Tiger 10.4.11** | PowerMac6,4 | 1 GB | **1.42 GHz G4** | 0.00 | **full** (gcc-4.9.4 + make-4.3 + ld64-97.17-tigerbrew + mlsupport-20221029) | **build host** (only Tiger G4 with full toolchain) |
| `emac2` | offline | — | — | — | — | — | timed out |
| `emac3` | offline | — | — | — | — | — | timed out |

**Build host:** `emac` — forced; only Tiger G4 with the full tigersh
toolchain.  Step up from ibookg38 (G3, 384 MB → 1 GB; 700 MHz G3 →
1.42 GHz G4).
**Primary test host:** `pbookg42` — Leopard G4, AltiVec-capable,
idle.  Validates Tiger-built tarball runs on Leopard too (forward-
compat).
**Bonus test host:** `mdd` — Leopard G4, runs leopard.sh.  Different
model (PowerMac3,6 MDD vs pbookg42's PowerBook5,2), different mlsupport
situation (mdd has none at `/opt/macports-legacy-support-20221029`).

Caveat: no second *Tiger G4* host online (emac2, emac3, pbookg4 all
timed out).  Means we cannot verify "dep-free on fresh Tiger" by
moving to a different machine — best we can do is move
`/opt/gcc-4.9.4` aside on emac itself before re-running, like we did
on ibookg37 in session 008.

## Plan

1. Plumb `CFLAGS_EXTRA` (and matching tarball-suffix) through
   `scripts/build-tiger.sh` + `build-tiger-remote.sh`.  G3 mode
   continues to set nothing (defaults); G4 modes pass `-mcpu=7450`
   (+ optional `-maltivec -mabi=altivec`).
2. Build `janet-X.Y.Z-r3-tiger-g4.tar.gz` on emac (non-AltiVec,
   `-mcpu=7450`).
3. Smoke test: emac (with `/opt/gcc-4.9.4` moved aside), pbookg42,
   mdd.
4. Build `janet-X.Y.Z-r3-tiger-g4-altivec.tar.gz` on emac
   (`-mcpu=7450 -maltivec -mabi=altivec`).
5. Smoke test same three hosts.
6. Run a quick benchmark on emac of the three tarballs (G3, G4,
   G4+AltiVec) — pick a Janet workload that hits the inner loop
   that's most likely to be code-genned differently by these flags.

## Build-script plumbing

Added a `CFLAGS_EXTRA` env knob to `scripts/build-tiger-remote.sh`
(appends to the default `-O2 -g`).  In `scripts/build-tiger.sh`, a
`TIGER_ARCH` preset auto-fills it:

| `TIGER_ARCH=` | `CFLAGS_EXTRA` | Tarball suffix |
|---|---|---|
| `g3` (default) | (empty) | `-tiger-g3.tar.gz` |
| `g4` | `-mcpu=7450` | `-tiger-g4.tar.gz` |
| `g4-altivec` | `-mcpu=7450 -maltivec -mabi=altivec -ftree-vectorize` | `-tiger-g4-altivec.tar.gz` |

The `-ftree-vectorize` in the AltiVec preset is deliberate: gcc-4.9
doesn't enable auto-vectorization at `-O2` by default, so without it
`-maltivec` only matters for hand-written intrinsics — and Janet has
none.  Adding `-ftree-vectorize` lets gcc actually try AltiVec on
scalar loops, giving an honest "AltiVec compiler flags only" A/B.

Caller-set `CFLAGS_EXTRA` wins over the preset, so future variants
(`-O3`, profile-guided, etc.) compose cleanly.

`BOOT_CFLAGS` in Janet's Makefile is independent of `CFLAGS`, so the
bootstrap binary `janet_boot` stays generic-PPC `-O0` even under a
G4+AltiVec build — fine, since it only runs on the build host
during the build.

## Builds

Both clean on emac.  Bundled mode, `-static-libgcc`, identical to the
G3 v0.2.1 recipe except for `CFLAGS_EXTRA`.

| Tarball | Size | `bin/janet` | `libjanet.dylib` |
|---|---|---|---|
| `janet-1.41.3-dev-r3-tiger-g4.tar.gz` | 1,748,206 B | 749,412 B | 1,701,632 B |
| `janet-1.41.3-dev-r3-tiger-g4-altivec.tar.gz` | 1,748,641 B | 749,412 B | 1,701,236 B |
| (reference) `…-r3-tiger-g3.tar.gz` | 1,747,915 B | 749,412 B | 1,699,604 B |

All three `bin/janet` happen to be exactly 749,412 bytes (coincidence —
md5sums differ).  `libjanet.dylib` grows by ~2 KB under `-mcpu=7450`
and shrinks by ~400 B back under `-maltivec -ftree-vectorize`
(auto-vec finds tiny scalar→vector wins).

`otool -L bin/janet` is identical to G3 v0.2.1:

```
@loader_path/../lib/libMacportsLegacySupport.dylib (compatibility version 1.0.0, current version 1.0.0)
/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 88.1.12)
```

No `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib` (the `-static-libgcc`
bundling carries over from session 008).

## Cross-host smoke

Both G4 tarballs smoked clean on three hosts in parallel:

| Host | OS | CPU | G4 | G4+AV | Note |
|---|---|---|---|---|---|
| `emac` (build host) | Tiger 10.4.11 | 1.42 GHz G4 | ✅ | ✅ | `otool -L` confirms no `/opt/gcc-4.9.4` ref |
| `pbookg42` | Leopard 10.5.8 | 1.25 GHz G4 | ✅ | ✅ | Has mlsupport at `/opt`; forward-compat check |
| `mdd` | Leopard 10.5.8 | 1.25 GHz G4 | ✅ | ✅ | **No mlsupport at `/opt`** — `@loader_path` bundling is doing real work here |

`mdd` is the strongest standalone-ness evidence — its `/opt/` has
gcc-4.9.4, make-4.3, leopard.sh, but **no
`/opt/macports-legacy-support-20221029`**.  Bundled tarball still
runs.  Stronger than session 008's "move /opt/gcc-4.9.4 aside on
ibookg37" check, because we never had to touch anything.

Tiger G4 (build host) `otool -L` was sufficient for the first pass;
attempted to also do the "move /opt aside" check on emac itself but
sudo on emac is password-required, so swapped to mdd instead.  Better
result — empirical absence vs. moved-aside.

## G3 SIGILL test (compatibility matrix)

Ran both G4 tarballs on ibookg37 (Tiger G3, PowerBook4,3).  **Both
fail at `dyld` load time** with:

```
dyld: incompatible cpu-subtype
```

This is a load-time refusal, not a mid-execution SIGILL.  Better
behavior than a crash — the user can't accidentally pick up a G4
binary on a G3 box; the OS bounces it before any code runs.  Notable:
**plain `-mcpu=7450` alone is enough to flip the Mach-O `cpu-subtype`
to G4** — `-maltivec` isn't a separate gate.

Compatibility matrix that we now have empirical evidence for:

| Tarball builds with | G3 | G4 | G5 (presumed) |
|---|---|---|---|
| G3 (no `-mcpu`) | ✅ | ✅ (verified on emac) | ✅ (PPC fwd-compat) |
| G4 (`-mcpu=7450`) | ❌ dyld | ✅ | ✅ (PPC fwd-compat) |
| G4 + AltiVec | ❌ dyld | ✅ | ✅ (PPC fwd-compat) |

## Benchmark — G3 vs G4 vs G4+AltiVec on emac

5 runs per binary, run-bench.sh + tests/bench.janet.  Workloads:
fib(30) recursive (VM dispatch), Mandelbrot 200×150/100-iter (FP),
PEG match × 200 over 10.2 KB text (integer/byte loop), marshal/
unmarshal × 80 of a depth-7 fanout-3 nested struct (table walk + GC).

Best of 5 runs (lower = faster):

| Workload | G3 baseline | G4 (`-mcpu=7450`) | G4+AltiVec | Δ G4 vs G3 | Δ G4+AV vs G3 |
|---|---|---|---|---|---|
| fib | 1.690 s | 1.700 s | 1.700 s | +0.6% slower | +0.6% slower |
| mandelbrot | 0.755 s | 0.735 s | 0.735 s | **−2.6%** | −2.6% |
| peg-match | 0.350 s | 0.357 s | 0.355 s | +2.0% slower | +1.4% slower |
| marshal | 0.492 s | 0.489 s | 0.492 s | −0.6% | 0.0% |
| **total** | **3.288 s** | **3.281 s** | **3.283 s** | **−0.2%** | **−0.2%** |

Within-run spread (max − min of 5 runs): G3 total 0.008s (0.25%), G4
total 0.043s (one outlier first run, four clustered), G4+AV total
0.032s (same shape).  Tight enough to trust the ranking but the
individual workload deltas are sub-percent and partly noise.

emac load before the bench: not freshly captured (we'd done two
builds + smoke tests in the prior 30 min), though the initial fleet
probe showed 0.00 and post-bench `uptime` showed 1m=0.00, 5m=0.04
(consistent with our own activity, not external).  Within-run spread
is the better evidence the bench wasn't disturbed mid-run.

### Findings

1. **Net total runtime: indistinguishable.**  G4 / G4+AltiVec vs G3
   on G4 hardware: −0.2% on the total.  Within noise; calling it
   a wash.

2. **Mandelbrot is the only clear win for G4 codegen (−2.6%).**
   FP-heavy inner loop — gcc-4.9 with `-mcpu=7450` produces tighter
   scheduling for the 7450's pipeline on FMA / FP-multiply sequences.
   Sub-1% gain on the total because mandelbrot is only ~22% of the
   bench wall-clock.

3. **G4+AltiVec is indistinguishable from plain G4.**  All four
   workloads within ±0.002 s (and the dylibs differ by only ~400 B
   of codegen).  gcc-4.9's auto-vectorizer at `-O2 -ftree-vectorize`
   finds essentially nothing to AltiVec in Janet's scalar bytecode
   interpreter.  The AltiVec build is effectively a no-op vs the G4
   build.

4. **`-mcpu=7450` slightly regresses fib (+0.6%) and peg-match
   (+2.0%).**  Both are tight scalar-loop workloads; 7450's deeper
   pipeline tuning probably costs us a little when the critical path
   is single-issue branchy interpreter dispatch.

5. **Empirically settles roadmap item 10 (AltiVec source patches).**
   The deferred item read: "AltiVec source patches if M2's
   non-invasive AltiVec doesn't get us most of the win."  Non-
   invasive gave us 0% — no surprise that's not where to spend
   effort.  Hand-rolled AltiVec intrinsics in Janet's VM would be
   speculative work with no obvious target (interpreter dispatch
   isn't SIMD-shaped) and would conflict with upstream's `vector.h`
   stretchy-buffer macros (cosmetic — names collide).  Closing.

### Methodology caveats (honest)

- 5 runs per binary, single batch (all-G3-then-all-G4-then-all-AV)
  instead of interleaved.  Cache state biases toward later arches
  (G4, G4+AV) on the run-bench.sh harness reading the same
  binary 5× in a row.  Effect is probably <0.1% but unmeasured.
- emac load wasn't captured immediately before the bench
  (`uptime` was 0.00 at the very start of session but a lot of
  build activity intervened).  Within-run spread (sub-1%) is the
  proxy.  Bench can be re-run with `uptime` capture per phase +
  interleaved runs + 10 iters if a tighter measurement matters
  later.
- Benchmark covers VM dispatch / FP / integer loops / GC.  Doesn't
  cover hand-written SIMD-friendly extensions (image processing,
  matrix math, signal processing) — anyone with a Janet C
  extension doing dense FP work might still see a G4+AltiVec
  win.

## Release decision

**No release this session.**  v0.2.1 stays as the public face.  M2
explored, conclusion documented; user-facing surface (a g4 or g4-av
tarball at leopard.sh / GitHub) would advertise a no-op variant.
The G4 / G4+AltiVec tarballs in `releases/` are session artifacts;
they prove the build pipeline works and back the writeup.  Anyone
who wants them can re-build via `TIGER_ARCH=g4 scripts/build-tiger.sh`.

## Status on exit

M2 explored end-to-end.  Build infrastructure now supports G3, G4,
and G4+AltiVec via a single env knob.  Empirical finding: AltiVec
compiler flags give essentially zero gain on Janet's standard
workload, so AltiVec source patches (deferred item) drop off the
table.  M1 release artifacts unchanged; v0.2.1 remains the
recommended download for all PPC Macs (G3, G4, G5).  Next-session
center of gravity probably swings to upstream PRs (A, E from session
008 HANDOFF) or M3 (G5 / ppc64).

