# Session 006 — posix_spawn fork+execve fallback

## Arrival state

[Session 005](../005-v0.1.0-public-release/) released M1.a as
[v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0)
— GitHub release, mirrored at
`http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz`,
README updated, fresh-install sanity check on ibookg37 green.  All
M1.a roadmap items 1–6 are ✅.

What was deferred: M1.b — get `os/spawn` / `os/execute` / `os/shell`
actually working on Tiger.  Sessions 002–003 had stubbed those out
via `JANET_NO_PROCESSES` (patches 0002 + 0003) because Tiger lacks
`<spawn.h>` and `posix_spawn{,p}`, and macports-legacy-support
doesn't backfill it.  Session 005's [HANDOFF](../005-v0.1.0-public-release/HANDOFF.md)
queued M1.b as the natural next pickup, with the
[leopard.sh 1.27.0 sketch](https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh)
named as a starting reference.

This session does the fork+execve fallback.

## What happened

### Reading the existing pieces

- The `<spawn.h>` include in `src/core/os.c:62` was gated on
  `JANET_NO_PROCESSES` (patch 0002).
- `JANET_NO_PROCESSES` itself was auto-defined on
  `JANET_APPLE_PRE_LEOPARD` in `src/core/features.h` (patch 0003).
- `JANET_NO_PROCESSES` is upstream's broad "no subprocess support"
  off-switch — it wraps a ~1300-line block in `os.c` covering
  `os/execute`, `os/spawn`, `os/shell`, `os/posix-fork`,
  `os/posix-exec`, and the `posix_spawn*` calls inside
  `os_execute_impl`.

The cleanest design point was therefore *not* to keep flipping
`JANET_NO_PROCESSES` on Tiger.  Instead, introduce a finer-grained
flag, `JANET_NO_POSIX_SPAWN`, that only swaps the `posix_spawn`
implementation for a fork+execve one.  `JANET_NO_PROCESSES` stays
as the broader user-facing off-switch (matching upstream
conventions like `JANET_NO_SPAWN`, `JANET_NO_NET`, `JANET_REDUCED_OS`).

### The leopard.sh 1.27.0 sketch

Per session 005's HANDOFF, fetched and read.  Three observations:

1. Uses `#ifdef POSIX_SPAWN_RESETIDS` as the discriminator (it's a
   macro from `<spawn.h>`, so its absence means we didn't include
   the header).  Cute, but a positive feature flag
   (`JANET_NO_POSIX_SPAWN`) is more upstreamable in shape.

2. The fallback is a bare `fork()` + `execve()` — no pipe
   redirection, no chdir, no execvp path lookup, no exec-failure
   propagation back to the parent.  Enough to pass the trivial
   case; nowhere near enough for `os/spawn` with `:out :pipe` or
   `os/execute` with `:px` (PATH lookup).

3. The patch is against 1.27.0; we're tracking 1.41.3-dev.  The
   surrounding code in `os_execute_impl` has churned, so it's a
   shape reference, not a drop-in.

### The fallback as actually written

Touch points in `src/core/os.c` and `src/core/features.h`,
land as patches 0002 / 0003 / 0004 of the new series.

The fork+execve fallback (in `os_execute_impl`):

  - **pipe(errpipe) with FD_CLOEXEC** on both ends.  This is the
    standard trick to propagate exec failures: on successful
    execve, the kernel closes the write end (CLOEXEC), and the
    parent's `read()` returns 0.  On exec failure, the child
    `write()`s errno and `_exit(127)`; the parent reads
    `sizeof(int)` bytes and panics with the child's errno.  Net
    result: failure modes (ENOENT, EACCES, chdir failed, ...)
    look identical to the `posix_spawn` rejection path.
  - **Child applies file actions** in the same order the
    posix_spawn `file_actions_*` calls would have: dup2 +
    selective close for stdin / stdout / stderr against
    `pipe_in/out/err`, `new_in/out/err`, and the
    `stderr_is_stdout` sentinel.
  - **Optional chdir** in the child before exec, honoring the
    `:cd` argument.  We define `JANET_SPAWN_CHDIR` for the
    fallback so `os_execute_impl`'s argument-parsing prelude
    doesn't pre-emptively panic.
  - **execvp vs execv** picked by flags bit 1 (the `:p` flag),
    matching `posix_spawnp` vs `posix_spawn`.
  - **`environ = envp` in the child** when `:e` was passed,
    leaving the parent's `environ` untouched (fork separates
    address spaces — no race against
    `janet_lock_environ`/`unlock` which is already held around
    the call).
  - **EINTR-safe `read` / `waitpid`** loops.

`pid_t pid` declaration hoisted above the `JANET_NO_POSIX_SPAWN`
ifdef and initialized to `-1` (suppresses a
`-Wmaybe-uninitialized` warning on the error-before-fork branch;
the `if (status) { janet_panic ... }` check downstream prevents
the uninitialized `pid` from ever being read, but gcc-4.9 can't
prove that).

### Validation

**uranium (Apple Silicon, posix_spawn available)** —
[`build-logs/uranium-fallback-test.log`](build-logs/uranium-fallback-test.log).
`CPPFLAGS=-DJANET_NO_POSIX_SPAWN make test` exercises the
fork+execve branch on a modern host where every dependency works:

```
suite-os.janet — 58 of 58 tests passed (0 skipped)
[all other suites also 0 skipped, 0 fail]
```

Full suite green.  No regression in the
posix_spawn-default path (built earlier in the session against
HEAD, also green).

**ibookg38 (Tiger PPC G3, real fallback)** —
[`build-logs/ibookg38-build.log`](build-logs/ibookg38-build.log)
for the build,
[`build-logs/ibookg38-suite-os.log`](build-logs/ibookg38-suite-os.log)
for `suite-os.janet`:

```
suite-os.janet — 57 of 58 tests passed (0 skipped)
```

The one failure is `"os/realpath errors when path does not exist"`
at `test/suite-os.janet:195` — Tiger / macports-legacy-support's
`realpath` returns success on nonexistent paths instead of
erroring.  Unrelated to spawn; flagged for [`docs/deferred.md`](../../deferred.md).
All spawn / execute / shell / fork / exec tests pass.

A broader `for f in test/suite*.janet` run from suite-array
through suite-filewatch was also done
([`build-logs/ibookg38-tests.log`](build-logs/ibookg38-tests.log)),
but the ssh-tee output cuts off after filewatch — a buffering
artifact, not a process death — so suite-os specifically was
re-run on its own as the gate.  (Filewatch itself shows 17/23 on
Tiger; the failures are kqueue `EVFILT_VNODE` flag-mapping quirks
also unrelated to spawn.  Also for `deferred.md`.)

### Patches series — new shape

```
0001  features.h: skip _POSIX_C_SOURCE / _XOPEN_SOURCE on pre-Leopard macOS   (unchanged from M1.a)
0002  os.c:        gate <spawn.h> include behind JANET_NO_POSIX_SPAWN          (revised)
0003  os.c:        fork+execve fallback for systems without posix_spawn        (new)
0004  features.h:  auto-define JANET_NO_POSIX_SPAWN on pre-Leopard Apple       (revised)
0005  Makefile:    honor CPPFLAGS in both boot and final compile phases        (unchanged, renumbered)
```

Old patches 0002 / 0003 (the `JANET_NO_PROCESSES` stub) — dropped.
The HANDOFF flagged them as placeholders; M1.b replaces them with
the real fix.

## Exit state

M1.b's substantive engineering is done:

- Tiger PPC build of janet ships `os/execute`, `os/spawn`,
  `os/shell`, `os/posix-fork`, `os/posix-exec`, `os/proc-wait`,
  `os/proc-kill`, `os/proc-close`, and `os/getpid` — all five
  `JANET_CORE_REG`s that were previously gated off.
- `suite-os.janet` reports 57/58 on real Tiger hardware (the 1
  failure is `os/realpath` semantics, not spawn).
- `make test`'s full battery still green on uranium with
  `JANET_NO_POSIX_SPAWN` forced — no regression to the
  posix_spawn-default path.

Remaining M1.b items (roadmap 8–10): BYO macports-legacy-support
build mode, `jpm install` from a git URL on a clean Tiger box, the
demo + final M1 release.  All three chain off this session's work.

A `releases/janet-1.41.3-dev-tiger-g3.tar.gz` was produced as a
build artifact, but **the released v0.1.0 tarball at
leopard.sh/misc/beta/ and on the GitHub release is unaffected** —
this session does not ship a new public release.  Filename collision
(both report `janet/version` = `1.41.3-dev`, since upstream hasn't
bumped) is annoying; the M1.b release will likely either bundle
under a different name or wait for upstream to cut 1.41.4.

Next: [HANDOFF.md](HANDOFF.md).
