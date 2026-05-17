# HANDOFF — session 011 → 012

## Where things stand

**M3 closed.  v0.2.2 shipped** with `janet-1.41.3-dev-r4-tiger-g5-ppc64.tar.gz`
as the new native ppc64 variant for G5 Tiger.  ~15% faster than the
G3 tarball on the same G5 hardware (mandelbrot −34%, fib −12%,
marshal −13%, peg +5%).  G3 bundled + BYO also bumped to `r4` for
release consistency (same Janet behavior as v0.2.1).

The roadmap's three milestones are now complete:
- M1.a — pure-Janet REPL + native modules (v0.1.0, session 005)
- M1.b — `posix_spawn` fallback + `jpm install` (v0.2.0/v0.2.1)
- M2 — G4 + AltiVec exploration (session 009, no release — non-win)
- M3 — G5 bootstrap + ppc64 (session 010 + this session, v0.2.2)

Patch stack stays at 6 (no NANBOX_64 — parked for upstream
investigation, see below).

### What's in v0.2.2

- `janet-1.41.3-dev-r4-tiger-g3.tar.gz` — bundled G3, byte-equivalent
  to v0.2.1's r3 modulo timestamps.
- `janet-1.41.3-dev-r4-tiger-g3-byo.tar.gz` — BYO G3, same.
- `janet-1.41.3-dev-r4-tiger-g5-ppc64.tar.gz` — **new.**
  ppc64 native, bundles `libMacportsLegacySupport.dylib` (ppc64) +
  rewrites install_names to `@loader_path/`.  Runtime requirements:
  `/usr/lib/libgcc_s_ppc64.1.dylib` (stock Tiger, Jan 2006) +
  `/usr/lib/libSystem.B.dylib` (stock Tiger).

## Suggested next moves

Project has run out of roadmap.  Reasonable carry-forwards:

**A. Upstream the `JANET_NANBOX_64` ppc64 bug.**  Real finding.
Build the parked patch in
[`nanbox64-investigation/`](nanbox64-investigation/) on top of
janet master HEAD, reproduce on a non-Apple ppc64 box (the bug
is almost certainly endianness-related, not Darwin-ABI-specific),
file an issue with the reproducer.  Worth a few hours; an upstream
fix turns our parked 2-line patch into a shipping ppc64+NANBOX_64
build.  No urgency — NANBOX_64 wins ~1.4% on top of no-nanbox per
our (broken) measurement, so this is "complete the engineering for
correctness," not "ship a bigger win."

**B. Upstream the posix_spawn patches.**  Carry-forward from
sessions 007-010.  User indicated this is being handled
out-of-band; not for us to drive in-project.  Tracked in
[`../deferred.md`](../deferred.md).

**C. Tiger-specific test failures.**  Carry-forward.  Two parked
items in [`../deferred.md`](../deferred.md):
  - `os/realpath` doesn't error on nonexistent paths.
  - `suite-filewatch.janet` 17/23 on Tiger.

**D. Leopard variants.**  `docs/deferred.md` lists this.  Mostly
mechanical (Leopard is more POSIX-compliant than Tiger, not less),
but no clear demand.

**E. Amalgamation drop.**  Single-file `janet.c` + `janet.h` +
`janetconf.h` preconfigured for Tiger, for embedders.  Listed in
`docs/deferred.md`.

**F. Sister-project follow-up.**  Apply the `-static-libgcc` and
ppc64-variant patterns from this project to llvm-darwin8-ppc /
ghc-darwin8-ppc / etc.

**G. Pin bump.**  We're on a pinned janet master SHA from before
the 1.41.3 official release.  A bump to a newer SHA (or to the
1.41.x stable line if there is one) would refresh the upstream
patch base.  Worth doing eventually but not urgent — pinned SHA
is stable and our patches apply cleanly.

The natural pick if continuing in-project is **A** (the
NANBOX_64 upstream contribution) — it leaves the work in a fully
tied-off state.  Otherwise the project is in a clean
"feature-complete, awaiting upstream merge" resting state.

## Where canonical artifacts live after this session

- [`docs/sessions/011-m3-ppc64/README.md`](README.md) — full
  narrative.
- [`docs/sessions/011-m3-ppc64/nanbox64-investigation/`](nanbox64-investigation/) —
  parked NANBOX_64 patch + writeup of the big-endian put bug.
- [`docs/sessions/011-m3-ppc64/probe-address-space-v{1,2}.c`](probe-address-space-v2.c) —
  the address-space probes that confirmed the 47-bit invariant for
  Janet's purposes.
- [`docs/sessions/011-m3-ppc64/int-s64-bench.janet`](int-s64-bench.janet) —
  s64/u64-heavy bench (not used in the canonical release bench, but
  kept for future "is NANBOX_64 worth it" measurement once the
  upstream bug is fixed).
- [`docs/sessions/011-m3-ppc64/build-logs/`](build-logs/) —
  bench logs, build logs, probe outputs.
- [`releases/janet-1.41.3-dev-r4-tiger-{g3,g3-byo,g5-ppc64}.tar.gz`](../../../releases/) —
  v0.2.2 artifacts.
- [`scripts/build-tiger.sh`](../../../scripts/build-tiger.sh) +
  [`build-tiger-remote.sh`](../../../scripts/build-tiger-remote.sh) —
  gained `TIGER_ARCH=g5-ppc64` preset + `LDFLAGS_EXTRA` env.
- [`docs/roadmap.md`](../../roadmap.md) — item 12 closed with full
  notes.
- [`README.md`](../../../README.md) — ppc64 row of build matrix
  flipped to ✅; v0.2.2 added to release table.

## Gotchas not to re-step on

**All sessions 003-010 gotchas still apply.**  New from this
session:

- **pmacg5 is shared with sibling projects.**  Use **imacg52** for
  G5 work in this project (memory saved:
  `project_g5_host_preference.md`).  pmacg5 benches looked
  catastrophically bad on this session's first attempt (ppc64
  *slower* than ppc32 by 56%) because other workloads were running.
  imacg52 gave clean, stable numbers (±0.005 s across 5 runs).  If
  imacg52 ever goes offline, fall back to pmacg5 *only* after
  confirming no other heavy workloads are running.

- **gcc-4.9.4 from tigersh uses `-m64`, not `-arch ppc64`.**
  `-arch` is an Apple-gcc extension; the GNU build of gcc-4.9.4
  doesn't recognize it.  Use `-m64` for ppc64.  If you ever switch
  to Apple's stock gcc-4.0 from Xcode 2.5, then `-arch ppc64` is
  the right flag.

- **`-m64` must reach both `CFLAGS` AND `LDFLAGS`.**  Janet's
  Makefile uses `$(CFLAGS) $(COMMON_CFLAGS)` for compilation but
  `$(LDFLAGS) $(BUILD_CFLAGS)` for the link line — and `CFLAGS`
  doesn't propagate to `LDFLAGS`.  Hence the new `LDFLAGS_EXTRA`
  env var.  Without it, `.o`s are ppc64 but the link line tries
  to emit ppc32, fails.

- **`BOOT_CFLAGS` deliberately stays ppc32 for ppc64 builds.**
  janet_boot is build-host-only; G5 runs both bitnesses natively;
  no plumbing needed.

- **`JANET_NANBOX_64` is broken on big-endian.**  Array `put`
  silently no-ops; top-level `var` reads back as nil.  Don't
  re-enable without an upstream fix.  Symptoms look like a Janet
  ABI / union-by-value calling-convention issue; full reproducer
  in [`nanbox64-investigation/`](nanbox64-investigation/).
  Affects every architecture with NANBOX_64 forced on big-endian,
  not just ppc64 (untested but high-confidence).

- **The 47-bit-address-space "invariant" naively appears violated
  on Tiger ppc64** because the stack lives at bit ~50.  But Janet
  never NaN-boxes stack pointers — only heap, code, and static
  data — and those all live below bit 31 on Tiger ppc64.  The v1
  probe was needlessly alarming; the v2 probe is the right
  framing.

- **`libgcc_s_ppc64.1.dylib` exists in stock Tiger** at
  `/usr/lib/libgcc_s_ppc64.1.dylib` (Jan 2006 datestamp).  No
  `-static-libgcc` is needed for ppc64 because we don't depend on
  a non-stock libgcc — the mlsupport.ppc64 dylib uses the stock
  one.  (Per `otool -L
  /opt/macports-legacy-support-20221029.ppc64/lib/libMacportsLegacySupport.dylib`.)

- **`@loader_path/` works fine on Mach-O ppc64.**  No surprises
  from the ppc32 setup — same `install_name_tool` rewrites, same
  bundled layout.

- **The ppc64 tarball runs ONLY on G5.**  PowerPC ISA is
  forward-compatible for ppc32 (G3 binaries run on G4/G5) but NOT
  for ppc64 (G5-only).  If a G3 or G4 user tries to install the
  ppc64 tarball, dyld will refuse with `Bad CPU type in executable`
  or similar.  This is the desired behavior — fail at install,
  not at first arithmetic.

- **tigersh provides ppc64 mlsupport as a precanned binary
  package.**  `tiger.sh macports-legacy-support-20221029.ppc64`
  installs the ppc64 variant alongside the existing ppc32 one.
  No source-build work needed for our release.

## Starting prompt for session 012

```
Starting session 012.  Read docs/sessions/011-m3-ppc64/HANDOFF.md
and README.md.

Session 011 closed M3 item 12 — ppc64 build released as v0.2.2 with
~15% perf win on G5 vs the G3 tarball.  Project is feature-
complete against the M1/M2/M3 roadmap.

Real finding parked for upstream: `JANET_NANBOX_64` is broken on
big-endian ppc64 — array `put` silently no-ops, top-level `var`
reads back as nil.  Patch + writeup in
docs/sessions/011-m3-ppc64/nanbox64-investigation/.

Pick one of (carry-forward):
  A. Upstream the NANBOX_64 ppc64 bug (file issue + reproducer
     against janet-lang/janet master).
  B. Upstream posix_spawn patches (user indicated out-of-band).
  C. Tiger test failures parked in docs/deferred.md
     (os/realpath, suite-filewatch.janet).
  D. Leopard variants.
  E. Amalgamation drop.
  F. Sister-project follow-up (apply -static-libgcc /
     ppc64-variant patterns to other projects).
  G. Pin bump to a newer janet SHA.

Or call the project at a clean resting point and switch contexts.

Each has its own writeup in HANDOFF.md "Suggested next moves".
```
