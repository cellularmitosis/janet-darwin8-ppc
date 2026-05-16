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

- **`posix_spawn` fallback PR.**  Once our patch is debugged-to-
  working in M1.b, send it upstream.  The leopard.sh 1.27.0 sketch
  is the starting point.  Reasonable framing: "pre-10.5 macOS lacks
  `<spawn.h>`; here's a fork+execve fallback gated on feature
  detection."  Similar in shape to the user's already-merged PRs
  #432 (O_CLOEXEC) and #436 (arc4random_buf).
- **Simplify PR #937's clock-shim gate.**  The merged PR gates the
  Mach `clock_get_time` shim on `!MAC_OS_X_VERSION_10_12`.  Now that
  macports-legacy-support provides `clock_gettime` on Tiger, the
  Mach shim is dead code in our world.  An upstream simplification
  would change the gate to feature-detection (`!_POSIX_TIMERS` or
  similar), or remove the shim entirely.  Low priority; cosmetic.

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

## Open questions

- **Does Janet's `os/spawn` need anything beyond the leopard.sh
  fork+execve sketch?**  Janet exposes a `spawn` API surface that
  includes file actions (pipes, redirects) and environment passing.
  The 1.27.0 sketch handled the simple case but never validated
  pipes.  Will surface in M1.b.
- **What's the right answer for `@loader_path` from inside a Janet
  native module?**  Four candidate strategies in [`plan.md`](plan.md#caveat-loader_path-resolution-from-inside-a-native-module);
  pick whichever works on real hardware.
- **G5's `tools/patch-header.janet` Bus error.**  Root cause vs
  workaround.  Leopard.sh sidestepped it by shipping the G4 binpkg
  on G5; we can do the same in M3, or build a bootstrap janet on
  G3 and use it as the host janet during the G5 build.
