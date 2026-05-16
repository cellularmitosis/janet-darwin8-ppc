# Deferred

Things parked: scheduled-but-not-yet-on-the-roadmap, opportunistic
follow-ups, low-priority polish.  When one of these gets pulled
forward, move it into [`roadmap.md`](roadmap.md) under the right
milestone.

The split:

- **[`roadmap.md`](roadmap.md)** = scheduled work, ordered by
  milestone (M1, M2, M3).
- **this file** = unscheduled / nice-to-have / "if someone asks".

If something here is more than two paragraphs to describe, give it
its own file in `docs/proposals/<slug>.md` and link it from a one-line
entry here.

## Upstream PRs (no fixed timeline)

These are out-of-band tracks that don't block our own releases.  We
send them when the patch is solid; upstream reviews at their pace.

- **`posix_spawn` fallback PR.**  The patch landed in session 006
  (patches 0002 / 0003 / 0004 — `JANET_NO_POSIX_SPAWN` gate + fork
  + (dup2 / chdir) + execve fallback + auto-detection on pre-
  Leopard Apple).  `suite-os.janet` 57/58 on ibookg38; the 1 fail
  is unrelated (`os/realpath` semantics).  Ready to send upstream;
  queue alongside the M1.b release.  Similar in shape to the
  already-merged PRs #432 (O_CLOEXEC) and #436 (arc4random_buf).
- **~~Simplify PR #937's clock-shim gate.~~**  *Withdrawn — empirically
  refuted.*  Initial reasoning was that mlsupport provides
  `clock_gettime` on Tiger so the Mach shim is dead code.  In
  practice, mlsupport's `clock_gettime` shim only covers
  `CLOCK_REALTIME` and `CLOCK_MONOTONIC` — it does NOT provide
  `CLOCK_PROCESS_CPUTIME_ID`, which Janet's POSIX path needs.
  Janet's Mach branch handles CPUTIME via a separate libc `clock()`
  fallback precisely because of that gap.  Full writeup +
  reproducible compile error in
  [`proposals/merged-prs-vs-mlsupport.md`](proposals/merged-prs-vs-mlsupport.md#empirical-correction).
- **Audit of merged PRs vs macports-legacy-support coverage.**  See
  [`proposals/merged-prs-vs-mlsupport.md`](proposals/merged-prs-vs-mlsupport.md).
  Maps each of the user's merged upstream PRs (#432 O_CLOEXEC, #436
  arc4random_buf, `f06e9ae3` /dev/urandom, #937 Mach clock shim)
  against what mlsupport actually provides on Tiger.  Final verdict:
  none of the four should be simplified or reverted upstream — each
  earns its keep, either for non-mlsupport builders or because
  mlsupport's own shim is incomplete (#937 case).

## Tarball variants

- **Amalgamation drop.**  Ship a small tarball with the single-file
  `janet.c` + `janet.h` + `janetconf.h` pre-configured for Tiger,
  for users who want to embed Janet in their own C project without
  the full build apparatus.  Niche — the intersection of "wants to
  embed Janet" and "is targeting Tiger PPC" is tiny — but cheap to
  produce alongside the main tarball, since `make` already builds
  `build/c/janet.c`.

## Other-OS / other-arch variants

- **Leopard build variants.**  `janet-X.Y.Z-leopard-g4.tar.gz`,
  `janet-X.Y.Z-leopard-g5.tar.gz`, etc.  Mostly mechanical once
  Tiger is solid; Leopard is more POSIX-compliant, so it's *easier*
  than Tiger.  Probably warrants a single session.

## Performance work

- **AltiVec source patches** (if M2's non-invasive AltiVec via
  compiler flags doesn't get us most of the win).  Likely candidates:
  hot loops in `src/core/{vm,corelib,marsh}.c`, GC `memcpy`/`bzero`
  paths.

## Tooling / quality-of-life

- **GitHub Actions CI** that at minimum lints the patches against
  the pinned upstream SHA on every PR.  Real build CI on actual
  Tiger PPC hardware is impractical (it's the user's fleet), but we
  can at least check that patches apply cleanly to the pinned SHA.
- **`tests/` test runner script** that captures stdout/stderr/exit
  in a structured way (à la
  [`tcc-darwin8-ppc/scripts/run-tests2.sh`](../../tcc-darwin8-ppc/scripts/run-tests2.sh)).
  Useful once we have more than a handful of smoke tests.

## Tiger-specific test failures (not blocking)

Surfaced by session 006's run of Janet's own test suite on
ibookg38.  Unrelated to the spawn work; flagged in case they bite
a downstream user.

- **`os/realpath` does not error on nonexistent paths.**
  `test/suite-os.janet:195` —
  `(assert-error "..." (os/realpath "abc123def456"))` fails on
  Tiger because macports-legacy-support's `realpath` shim
  synthesizes a path instead of returning NULL/ENOENT.  Standard
  Darwin realpath errors; Tiger's pre-10.5 implementation (or the
  shim's emulation of it) doesn't.  Workaround: avoid relying on
  this error case in Tiger-targeted Janet code.

- **`suite-filewatch.janet` reports 17/23 on Tiger.**  `EVFILT_VNODE`
  flag mapping looks wrong — `:attrib` events show up where
  `:write` events are expected, plus spurious extra events.
  Probably needs a Tiger-specific tweak in `src/core/filewatch.c`
  or a "skip on Tiger" gate in the test.  Janet's filewatch is
  built on `kqueue`/`kevent`; Tiger's kqueue is older than the one
  upstream targets.

## Open questions
- **What's the right answer for `@loader_path` from inside a Janet
  native module?**  Four candidate strategies in [`plan.md`](plan.md#caveat-loader_path-resolution-from-inside-a-native-module);
  pick whichever works on real hardware.
- **G5's `tools/patch-header.janet` Bus error.**  Root cause vs
  workaround.  Leopard.sh sidestepped it by shipping the G4 binpkg
  on G5; we can do the same in M3, or build a bootstrap janet on
  G3 and use it as the host janet during the G5 build.
