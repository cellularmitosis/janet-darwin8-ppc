# HANDOFF — session 001 → 002

## Where things stand

Build on ibookg38 now gets past the BSD-socket-types problem (patch
0001, features.h) and dies at the expected next blocker:

```
src/core/os.c:62:19: fatal error: spawn.h: No such file or directory
 #include <spawn.h>
```

Everything before that point compiles cleanly with gcc-4.9 +
macports-legacy-support.

## Suggested first move for session 002

**Stub out `posix_spawn` enough to get a build through.**  This is
M1.a work — we just need `make` to complete so we can produce a
tarball, not a working `os/spawn`.

Two ways to shape the stub:

1. **`JANET_NO_PROCESSES` Makefile/janetconf flag.**  Wrap the
   `<spawn.h>` include and the `os/spawn` / `os/execute` machinery
   (lines ~62 + ~1360–1470 of `src/core/os.c`), plus the
   `JANET_CORE_REG("os/spawn", os_spawn)` registration (line
   3006).  Pure subtraction of features; nothing remains to break
   at runtime.  Cleanest for M1.a.

2. **Real fork+execve fallback (the M1.b path) early.**  Start from
   the leopard.sh 1.27.0 sketch
   (`https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh`).
   More ambitious; defers M1.a until the fallback works.

Strong recommendation: **go with option (1) for session 002**.
M1.a's job is "ship something usable as fast as possible";
subprocess support is explicitly M1.b.  Splitting the work means
session 002 can end with a tarball and a working pure-Janet REPL.

Patch 0002 would be `patches/0002-disable-os-spawn-when-JANET_NO_PROCESSES.patch`
or similar, and `scripts/build-tiger.sh` would pass
`-DJANET_NO_PROCESSES` in CPPFLAGS for the M1.a build.

## Other unblocking work in session 002

Once the build completes:

3. **Write `scripts/build-tiger.sh`.**  Promote the inline env
   vars from session 001 to a real script.  Runs on uranium and
   ssh's into ibookg38 (or, simpler: lives on uranium, does the
   rsync + ssh dance itself).  Env vars + invocation pattern is
   in [`findings.md`](findings.md#janet-build-env-that-gets-the-build-started).

4. **`install_name_tool` wiring for `@loader_path`.**
   - `bin/janet` → `@loader_path/../lib/libjanet.dylib`
   - `lib/libMacportsLegacySupport.dylib` install_name set to
     `@loader_path/libMacportsLegacySupport.dylib`
   - Audit via `otool -L` that nothing dangles.

5. **Bundle macports-legacy-support's dylib** under
   `/opt/janet-X.Y.Z/lib/` in the install step.

6. **First tarball.**  `janet-X.Y.Z-tiger-g3.tar.gz`.  Test on
   ibookg37 (clean machine).  REPL should work; `os/spawn` should
   panic with a clean error.

## Gotchas not to re-step on

- Don't try `-D_DARWIN_C_SOURCE` to fix BSD-types-hidden issues on
  Tiger.  It's a no-op there.  Tiger predates that macro.  See
  [findings.md](findings.md#on-tiger-_posix_c_source--_xopen_source-hide-bsd-socket-types).
- Don't expect macports-legacy-support to provide `<spawn.h>` or
  `posix_spawn`.  It doesn't — it ships `sys/spawn.h` (which is
  unrelated to the posix_spawn interface used in C programs).
- Don't try plain `rsync` on Tiger boxes — use
  `~/bin/tiger-rsync.sh`, which forces protocol 27.
- Don't `git clone` on ibookg38 — there's no git installed.
  Workflow is: modify on uranium, rsync to Tiger to build.

## Starting prompt for session 002

```
Starting session 002.  Read docs/sessions/001-bring-up-and-pin/
HANDOFF.md and README.md.  Pick up where 001 left off: build
fails at <spawn.h> not found in src/core/os.c.  Implement the
JANET_NO_PROCESSES stub described in HANDOFF.md (option 1) so
the build completes on ibookg38, then move on to scripts/build-
tiger.sh + the install_name_tool wiring + the first tarball.
M1.a acceptance: REPL runs end-to-end on ibookg37 (clean test
host).  Bonus: precompiled janet-lzo native-module smoke.

Build env (from session 001):
  PATH=/opt/gcc-4.9.4/bin:/opt/make-4.3/bin:/opt/ld64-97.17-tigerbrew/bin:$PATH
  CC=gcc-4.9
  CPPFLAGS="-I/opt/macports-legacy-support-20221029/include/LegacySupport"
  LDFLAGS="-L/opt/macports-legacy-support-20221029/lib -lMacportsLegacySupport"

External/janet/ is at the pinned SHA + patch 0001
(features.h).  Rsync changes to ibookg38:tmp/janet/ via
~/bin/tiger-rsync.sh.
```
