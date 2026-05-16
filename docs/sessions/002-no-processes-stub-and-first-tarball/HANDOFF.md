# HANDOFF — session 002 → 003

## Where things stand

Session 002 closed out the M1.a build-and-tarball gate.  Four
upstreamable patches; a working `scripts/build-tiger.sh`; a 1.7 MB
[`releases/janet-1.41.3-dev-tiger-g3.tar.gz`](../../../releases/janet-1.41.3-dev-tiger-g3.tar.gz)
verified on ibookg37 (clean Tiger G3); 29/30 of Janet's own test
suite green (the one fail is `suite-os.janet` panicking on the
deliberately-stubbed `os/execute`).

What's left on M1.a is **distribution + polish**, not engineering:
GitHub release, scp to leopard.sh, README status updates, demo
script.  Then M1.b proper (the real `posix_spawn` fallback).

## Suggested first moves for session 003

Pick whichever you have appetite for.  Roughly in priority order:

### A. M1.a release distribution (15-30 min)

Six bits:

1. **Update outer README** — flip the build matrix line for G3
   Tiger to ✅ M1.a (or 🟡 if leaving M1.b open).  Add a Releases-
   table entry.  Replace the "(Placeholder)" curl block with the
   real one-liner.
2. **Bump `docs/sessions/...` and `docs/roadmap.md` accordingly.**
   M1.a items 1–4 done; 5 (janet-lzo native module) is the lone
   bonus.  6 (the release itself) is what this section is.
3. **`demos/v0.1.0-hello.{janet,sh}`** — small demo script that
   prints something and shows off basic Janet usage.  Per
   `docs/roadmap.md#M1.a` item 6.
4. **`gh release create`** of the tarball.  Per `CLAUDE.md`'s
   "Release distribution" section, three places:
   - `gh release create vX.Y.Z ... releases/janet-1.41.3-dev-tiger-g3.tar.gz`
   - `scp releases/janet-1.41.3-dev-tiger-g3.tar.gz mini10v:/var/www/html/misc/beta/`
   - `scp releases/janet-1.41.3-dev-tiger-g3.tar.gz leopard.sh:/var/www/html/misc/beta/`
5. **Confirm the curl-installable one-liner works** end-to-end:
   `curl http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz | gunzip | tar x`
   on a Tiger box and exercise the REPL.
6. **Version-naming sanity check.**  We're shipping
   `1.41.3-dev`; that's honest (matches `(print janet/version)`)
   but ugly.  Decide whether to:
   - keep the `-dev` suffix
   - rename to `0.1.0` (project-local versioning), or
   - re-pin once upstream cuts a release tag (and live with
     `1.41.3-dev` between now and then).

   Strong recommendation: keep `-dev` for now.  It's accurate and
   subsequent re-pins will naturally drop it when upstream tags
   the next release.

The "visible-to-others" actions (GitHub release, scp to leopard.sh)
need user confirmation per CLAUDE.md — surface for sign-off before
executing.

### B. janet-lzo precompiled native-module smoke (M1.a bonus, ~1-2 hrs)

Per roadmap M1.a item 5.  Validates the `@loader_path` wiring +
the native module loader on a clean Tiger box, without needing
`jpm install` (which depends on `os/spawn`).

Sketch:

1. On ibookg38, clone
   `https://github.com/cellularmitosis/janet-lzo`.
2. Build the `.so` by hand (gcc-4.9, link against
   `/opt/janet-1.41.3-dev/lib/libjanet.dylib` and `lzo-2.10`).
   Native module record will reference @loader_path-relative
   libjanet — that's the bit being tested.
3. Drop the `.so` into `/opt/janet-1.41.3-dev/lib/janet/lzo.so`
   (or wherever Janet's module path search puts it on Tiger).
4. On ibookg37: `(import lzo) (lzo/decompress (lzo/compress @"hello"))`
   round-trip.

If `@loader_path` resolution from inside the `.so` works (i.e.
the .so finds libjanet.dylib from its sibling-dir location), the
M1.a native module gate is met.

### C. M1.b — posix_spawn fallback (the real work)

The big M1.b item per roadmap.  Start from the leopard.sh 1.27.0
sketch:
`https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh`.

Strategy:

1. Read the historic patch to understand the fork+execve+pipe
   plumbing intended.
2. Carve out a new compile-time path in `src/core/os.c`: when
   `JANET_NO_PROCESSES` is **not** set but `<spawn.h>` isn't
   available (something like `JANET_HAS_POSIX_SPAWN` auto-detected
   in features.h, off on pre-Leopard Apple), use a fork+execve
   fallback for `os/spawn` and friends.
3. Validate against Janet's own `test/suite-os.janet` (currently
   failing because os/execute is stubbed out).
4. Land as patches 0005 (or 0005–N depending on shape) on the
   `darwin-ppc` branch.

This is bigger than (A) or (B) — likely a full session of its own,
maybe two.

## Gotchas not to re-step on

- **Don't add a Tiger-specific build script trick to inject `-D`
  through CFLAGS.** Patch 0004 already taught the Makefile to
  read CPPFLAGS — use that.  Auto-detect via `features.h` for
  anything conditional on the target.
- **Don't pass `CFLAGS=...` if you also want it in the boot phase.**
  `BOOT_CFLAGS` does NOT include `$(CFLAGS)` upstream.  Pass via
  `CPPFLAGS` (post-patch 0004) to hit both phases.
- **bin/janet does NOT link against `libjanet.dylib`.**  It's
  statically linked from the same object set used to build the
  shared library.  No need to install_name_tool a libjanet ref on
  bin/janet — it has none.
- **`(print janet/version)` reports `1.41.3-dev`**, not `1.41.3`.
  Anything reading the version should not strip the suffix
  unconditionally.
- **macports-legacy-support provides O_CLOEXEC via `<sys/fcntl.h>`,
  not `<fcntl.h>`.**  But `<fcntl.h>` typically `#include`s
  `<sys/fcntl.h>` on Tiger, so as long as
  `-I.../LegacySupport` is on the compile command line, it
  resolves transparently.
- **gcc-4.9 binaries reference TWO libgcc_s.1.dylib paths**
  (`/usr/lib/...` AND `/opt/gcc-4.9.4/lib/...`).  This is intentional
  (compatibility + completeness).  Don't try to flatten it without
  understanding why both are there.
- **Don't try to commit external/janet/ from the outer repo.**
  Plain `git commit` from the project root operates on the outer
  repo (which has external/janet gitignored); to touch the
  darwin-ppc branch, `cd external/janet` first.

## Starting prompt for session 003

```
Starting session 003.  Read docs/sessions/002-no-processes-stub-
and-first-tarball/HANDOFF.md and README.md.  Session 002 closed
the M1.a build-and-tarball gate; a working tarball lives at
releases/janet-1.41.3-dev-tiger-g3.tar.gz and the M1.a acceptance
gate has been met on ibookg37 (REPL + 29/30 test suite green).

What's left for M1.a is distribution (GitHub release, scp to
leopard.sh, README update, demo).  HANDOFF section A walks
through it.  M1.a bonus is the janet-lzo native module smoke
(section B).  M1.b is the real posix_spawn fallback (section C).

Pick the section to work on.  If unsupervised, default to
section A (M1.a release distribution) — small and visible.
```
