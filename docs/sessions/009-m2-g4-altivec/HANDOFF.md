# HANDOFF — session 009 → 010

## Where things stand

**M2 explored end-to-end; no release.**  Build scripts now support
G3 / G4 / G4+AltiVec via `TIGER_ARCH={g3,g4,g4-altivec}`.  Both G4
tarballs were built, verified standalone (including on `mdd` which
has no mlsupport at `/opt`), and benchmarked against the v0.2.1 G3
tarball on the same G4 hardware.

**Headline finding: non-invasive AltiVec is a no-op for Janet.**  G4
/ G4+AltiVec vs G3 on G4 hardware: −0.2% total (within noise).
Mandelbrot −2.6% (the only clear FP gain from `-mcpu=7450` codegen);
fib +0.6%, peg +2.0% slower (interpreter dispatch microscopically
regresses).  G4 vs G4+AltiVec are indistinguishable — gcc-4.9
auto-vec at `-O2 -ftree-vectorize` finds nothing in Janet's scalar
bytecode interpreter.  Empirically settles deferred-item "AltiVec
source patches" as not worth pursuing.

v0.2.1's G3 tarball remains the recommended download for all PPC
Macs (G3, G4, G5 alike).  Patch stack unchanged at 6.  Project at
the same stable resting point as after session 008 — the M2
exploration moved a roadmap milestone (M2 ✅) and added build-script
capability, but no user-facing artifact changed.

## Compatibility matrix (now empirically grounded)

| Tarball built with | Runs on G3 | Runs on G4 | Runs on G5 (presumed) |
|---|---|---|---|
| G3 (no `-mcpu`) | ✅ | ✅ (verified, emac) | ✅ (PPC forward-compat) |
| G4 (`-mcpu=7450`) | ❌ `dyld: incompatible cpu-subtype` | ✅ | ✅ (PPC forward-compat) |
| G4 + AltiVec | ❌ same | ✅ | ✅ (PPC forward-compat) |

Important: `-mcpu=7450` alone — without `-maltivec` — is enough to
flip the Mach-O `cpu-subtype` to G4.  G3's `dyld` refuses to load
the binary at all, before any code runs.  Better than a SIGILL
because it's deterministic and pre-execution.

## Suggested next moves

All carry-forward from session 008, minus M2 which we just closed.
Plus one new track from this session.

**A. Upstream PR for the posix_spawn patches.**  (Carry-forward
from sessions 007 + 008.)  Out-of-band.  Patches 0002 / 0003 / 0004
are upstreamable in shape.  ~1 hour of prose polishing +
`git format-patch --base` rebase.  Similar to merged PRs #432
(O_CLOEXEC) and #436 (arc4random_buf).  Probably the highest-
leverage piece on the board right now: contributes the work back
to upstream Janet, makes the patch stack one notch smaller.

**B. ~~M2 — G4 + AltiVec exploration.~~** *Done.  See above.*

**C. M3 — G5 / 64-bit.**  (Carry-forward.)  Roadmap items 11-12.
G5 hardware (`pmacg5`) is in the fleet but wasn't touched this
session.  Bootstrap-on-G3 workaround for the
`tools/patch-header.janet` Bus error is the recommended starting
point; root-causing the Bus error is more work but more interesting.

**D. Tiger-specific test failures in `docs/deferred.md`.**  (Carry-
forward.)  Two parked items:

- `os/realpath` doesn't error on nonexistent paths (mlsupport's
  `realpath` shim semantics).
- `suite-filewatch.janet` reports 17/23 on Tiger
  (`EVFILT_VNODE` flag mapping looks wrong in
  `src/core/filewatch.c`).

**E. Upstream patch 0006 (`:cd` tests) as a small PR.**  (Carry-
forward from 008.)  Smallest scope (~30 min), single test-file
addition exercising `JANET_SPAWN_CHDIR` across all backends.  Good
warm-up for the posix_spawn PR (E first, then A).

**F. macports-legacy-support: add `CLOCK_PROCESS_CPUTIME_ID`.**
(Carry-forward from 008.)  Out-of-project (mlsupport's repo).
Would unblock the reverted #937 simplification.

**G. `-static-libgcc` for sister Tiger projects.**  (Carry-forward
from 008.)  Apply session 008's `-static-libgcc` trick to
leopard.sh / other sister projects so their tarballs are similarly
standalone.

**H. (New from session 009.)  Stress-test the bench under varied
workloads.**  Our bench (fib / mandel / peg / marshal) is a "general
workload" sample; it doesn't include matrix math, image processing,
or any hand-written SIMD-friendly C extension.  If a future user
reports an actual workload where G4+AltiVec helps, expand
`tests/bench.janet` and re-benchmark — the M2 capability is in the
build scripts even if we don't ship a tarball variant for it.

## Where canonical artifacts live after this session

- `scripts/build-tiger.sh` — adds `TIGER_ARCH=g4` and `TIGER_ARCH=
  g4-altivec` presets that set `CFLAGS_EXTRA` automatically.
  Caller-set `CFLAGS_EXTRA` wins over the preset (composes with
  future `-O3` / PGO variants).
- `scripts/build-tiger-remote.sh` — accepts `CFLAGS_EXTRA` env;
  exports `CFLAGS="-O2 -g $CFLAGS_EXTRA"` so Janet's
  `CFLAGS?=-O2 -g` default still applies to the base, our extras
  tack on, and `BOOT_CFLAGS` (bootstrap binary) is unaffected
  (stays generic-PPC `-O0`).
- `scripts/run-bench.sh` — Tiger-portable bench harness (5 runs;
  no `seq`, no `pipefail` — Tiger's stock /bin/bash is 2.05b).
- `tests/bench.janet` — fib(30) + Mandelbrot 200×150 + PEG match
  × 200 over 10.2 KB + marshal round-trip × 80.  ~3.3 s on a 1.42
  GHz G4.
- `releases/janet-1.41.3-dev-r3-tiger-g4.tar.gz` — G4 tarball
  (local; **not published** as a release).
- `releases/janet-1.41.3-dev-r3-tiger-g4-altivec.tar.gz` — G4+AltiVec
  tarball (local; **not published**).
- `docs/sessions/009-m2-g4-altivec/build-logs/` — full build +
  smoke + bench logs from this session.
- `docs/roadmap.md` — M2 marked ✅ explored; items 8 + 9 + 10
  closed with the findings inline.
- `docs/deferred.md` — "AltiVec source patches" item struck through
  with link to session 009 findings.
- `README.md` — implementation-status table grew two new rows for
  G4 Tiger and G4+AltiVec (both 🟡 explored).  G4 Leopard row also
  added (🟡 smoked).

## Gotchas not to re-step on

**All sessions 003-008 gotchas still apply.**  New from this
session:

- **`-mcpu=7450` alone flips Mach-O cpu-subtype to G4** — not just
  `-maltivec`.  Means a G4-tuned-but-no-AltiVec binary still won't
  load on G3.  This is *good* (deterministic load-time refusal vs
  SIGILL mid-execution), but worth knowing when reasoning about
  what's safe to deploy where.

- **gcc-4.9 doesn't auto-vectorize at `-O2` by default.**  Need
  `-ftree-vectorize` (or `-O3`) for `-maltivec` to do anything
  beyond enabling hand-written intrinsics.  If you find yourself
  saying "I added `-maltivec` and nothing got faster," check
  whether the vectorizer is even running.

- **Janet's bootstrap binary (`janet_boot`) uses `BOOT_CFLAGS`,
  not `CFLAGS`.**  So setting `CFLAGS="-O2 -g -mcpu=7450 …"` in
  the build env does *not* propagate to `janet_boot` — which is
  fine, because `janet_boot` only runs on the build host and
  generic-PPC code works there.  But it means a "compiled with
  -mcpu=7450" claim refers to `bin/janet` and `libjanet.dylib`,
  not the whole build.

- **`build-tiger.sh`'s rsync uses `--delete`.**  Running back-to-
  back builds (G4 then G4+AltiVec) wipes the previous tarball
  from `$REMOTE_DIR` on the build host because rsync clobbers
  the destination tree.  Tarballs get scp'd back to `releases/`
  before the next build clobbers them — so this is OK in the
  normal pipeline — but if you `ssh` to the build host
  afterwards expecting both tarballs to still be there, only the
  most recent one will be.  Either:
  (a) accept that and re-scp from `releases/` if you need them, or
  (b) parameterize `$REMOTE_DIR` per-arch (one dir for each
  variant).  We took option (a) when running the cross-arch bench.

- **emac has password-required sudo.**  Can't do the "move /opt
  aside" check unattended.  Pivot to a test host that *naturally*
  lacks the dep, like `mdd` for mlsupport — that's a stronger
  proof anyway (empirical absence vs. moved-aside).

- **Tiger's stock `/bin/bash` is 2.05b** — no `pipefail`, no `seq`.
  When writing shell that has to run on Tiger directly (not under
  `tigersh`-deps's bash 3.2), avoid both.  Use `while [ "$i" -le
  "$N" ]; do … i=$((i+1)); done` instead of `for i in $(seq …)`.

- **`mdd` has no `otool`** (Leopard sans Xcode Command Line Tools).
  If a smoke script does `otool -L`, gate on `command -v otool`
  or skip the check on hosts without it.

- **Don't grep `^  fib` against bench.janet output.**  The
  "Workloads:" banner line `  fib(30), mandelbrot ...` shares the
  prefix with the time-result line `  fib   1.690 s`.  Use a
  trailing-space-then-digit anchor (`^  fib +[0-9]`) when parsing.

- **Avoid clock-speed-only mental models when comparing G3 vs G4.**
  emac (1.42 GHz G4) vs ibookg38 (~700 MHz G3) — naïve 2× ratio.
  Actual Janet bench ratio is closer to 1.3-1.4× because the
  interpreter is memory-bound and PowerPC's L1/L2 design differs
  between G3 and G4.  Cross-CPU comparisons need same-binary,
  same-workload runs on each box.

## Starting prompt for session 010

```
Starting session 010.  Read docs/sessions/009-m2-g4-altivec/
HANDOFF.md and README.md.

Session 009 closed out M2 (G4 + AltiVec) — build scripts support
G3 / G4 / G4-altivec via TIGER_ARCH= preset, both G4 tarballs build
clean, but the benchmark showed non-invasive AltiVec gives ~0%
gain on Janet's standard workload.  No release this session.
v0.2.1 G3 tarball remains the recommended download.

Pick one (carry-forward from 008 + new from 009):
  A. Upstream PR for posix_spawn patches (0002-0004)
  C. M3 — G5 / ppc64 (G4 + AltiVec closed in 009)
  D. Tiger test failures parked in docs/deferred.md
  E. Upstream patch 0006 (:cd tests) as a small PR
  F. macports-legacy-support: add CLOCK_PROCESS_CPUTIME_ID
  G. Apply -static-libgcc to sister Tiger projects
  H. (Stretch) Stress-test bench under varied workloads if anyone
     reports a real one that benefits from AltiVec

Each has its own writeup in HANDOFF.md "Suggested next moves".
```
