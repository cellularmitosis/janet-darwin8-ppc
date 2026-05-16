# Session 002 findings

Cross-session-relevant things learned.

## `JANET_NO_PROCESSES` is already an upstream flag

Upstream Janet already supports a `JANET_NO_PROCESSES` build flag.
`os.c` lines 343–1640 wrap the entire process-spawning machinery
(`os/execute`, `os/spawn`, `os/shell`, `os/posix-exec`,
`os/posix-fork`) behind it, and lines 3004+ wrap the corresponding
`JANET_CORE_REG` registrations.  `meson.build` exposes it as
`-Dprocesses=false`, and `janet.h:168` auto-defines it under
`__EMSCRIPTEN__`.

The only piece outside this guard was `#include <spawn.h>` in
`os.c`'s platform-includes section — gated by `JANET_PLAN9` but
not `JANET_NO_PROCESSES`.  Patch 0002 closes that gap.

So our M1.a stub is a one-line completion of an existing partial
flag, not a from-scratch invention.  The patch is upstreamable as
"complete the `JANET_NO_PROCESSES` support that's already mostly
there."

## Janet's Makefile doesn't use CPPFLAGS, and its boot phase uses BOOT_CFLAGS (not CFLAGS)

Vanilla upstream Janet's Makefile **never reads `$(CPPFLAGS)`** —
every compile rule threads `BUILD_CFLAGS` or `BOOT_CFLAGS`:

- `BUILD_CFLAGS := $(CFLAGS) $(COMMON_CFLAGS)` — final phase.
- `BOOT_CFLAGS := -DJANET_BOOTSTRAP ... $(COMMON_CFLAGS) -g` —
  **no `$(CFLAGS)`**, no `$(CPPFLAGS)`.

So `CPPFLAGS=-Ifoo` and `CFLAGS=-Ifoo` are both silently dropped
during the bootstrap phase.  The bootstrap phase still compiles
the entire core source set including `os.c` and `util.c`, so a
`-D` or `-I` needed to make any of those compile won't reach them.

Patch 0004 fixes this for both phases by folding `$(CPPFLAGS)` into
`COMMON_CFLAGS`.  Going forward, our `scripts/build-tiger.sh`
relies on this — passes `-I.../LegacySupport` via `CPPFLAGS`.

If you're ever bringing up Janet on a platform that needs
header-search-path adjustments (anything pre-Leopard, anything
that uses a shim like macports-legacy-support), patch 0004 is the
load-bearing piece.

## macports-legacy-support's `<sys/fcntl.h>` shim provides O_CLOEXEC

Tiger lacks `O_CLOEXEC` (Apple added it in 10.7).  Janet's
`util.c` falls back to `/dev/urandom` for `janet_cryptorand` on
pre-10.7 Mac (gated by `MAC_OS_X_VERSION_10_7`), and that path
uses `O_CLOEXEC`.

macports-legacy-support DOES backfill it:
`include/LegacySupport/sys/fcntl.h` does
`#include_next <sys/fcntl.h>` then adds
`#ifndef O_CLOEXEC #define O_CLOEXEC 0 #endif`.  It's `0`, so
the bit is a no-op (no actual close-on-exec semantics), but the
compile succeeds.

For Janet's `janet_cryptorand` use case the missing semantics
don't matter: the fd is opened, read from, and closed within the
function with no `exec` in between.  Close-on-exec is hygienic;
defining it to 0 here is correct.

This shim is **only visible if `-I.../LegacySupport` is on the
boot-phase compile command line** — i.e. before patch 0004,
unreachable from any standard env var.

## Janet's bin/janet is statically linked against the core

`bin/janet` does **not** depend on `libjanet.dylib` at runtime —
it's linked directly from `build/janet.o build/shell.o`, the same
objects used to build the shared library.  The shared library
exists for native module consumers (modules built against Janet's
headers expect to dynamically resolve the Janet C API).

Practical implication: when fixing up install names with
`install_name_tool`, the binary only needs its
`libMacportsLegacySupport.dylib` ref rewritten; you do not need
to fix up a `libjanet.dylib` ref because there isn't one.  This
is different from many "binary + shared lib" projects.

## install_name_tool wiring on Tiger uses @loader_path, not @rpath

`@rpath` requires `LC_RPATH`, which was added in Leopard.  On
Tiger we use `@loader_path` for everything.  Layout:

```
/opt/janet-X.Y.Z/
├── bin/janet
└── lib/{libjanet.X.Y.Z.dylib,
          libjanet.dylib,
          libMacportsLegacySupport.dylib,
          janet/<modules>/*.so}
```

Wiring:
- `bin/janet`: every absolute-build-path dep rewritten to
  `@loader_path/../lib/<name>`.
- `lib/lib*.dylib`: id and inter-lib deps rewritten to
  `@loader_path/<basename>`.
- Native modules under `lib/janet/<modpath>/`: at module-build
  time, link against `@loader_path/../../<basename>` for parent-
  level libs, or `@loader_path/<basename>` for sibling .so's.

This is a standard pattern for self-contained app/lib bundles on
older macOS, and it sidesteps the LC_RPATH-doesn't-exist problem
without needing to special-case anything.

## Tiger PPC runtime deps for a gcc-4.9.4-built binary

A typical `bin/janet` (or any Tiger PPC binary built with
`/opt/gcc-4.9.4`) records four dep paths:

```
/usr/lib/libSystem.B.dylib           — Tiger system, always present
/usr/lib/libgcc_s.1.dylib            — Tiger system, always present
/opt/gcc-4.9.4/lib/libgcc_s.1.dylib  — gcc-4.9 runtime, needs gcc-libs-4.9.4
@loader_path/../lib/libMacportsLegacySupport.dylib — bundled
```

The double libgcc_s reference is gcc-4.9's compatibility trick:
the gcc-emitted code calls into both the system runtime
(for ABI symbols Tiger has) and gcc's own runtime (for symbols
Tiger lacks, e.g. `__sync_synchronize`).

For "really standalone" tarballs that work on a Tiger box with
NO `/opt/gcc-4.9.4/` installed, we'd need to bundle
`/opt/gcc-4.9.4/lib/libgcc_s.1.dylib` ourselves and rewrite the
ref to `@loader_path/../lib/libgcc_s.1.dylib`.  Deferred to M1.b
or later — for now we depend on `gcc-libs-4.9.4` being installed
(it's installed by tigersh as a dep of any other gcc-4.9.4-built
package anyway).

## Janet versioning: `janet/version` may include a `-dev` suffix

Upstream's `src/conf/janetconf.h` carries
`JANET_VERSION_EXTRA "-dev"` between releases on master.  So
master HEAD reports `janet/version` as `1.41.3-dev`, not just
`1.41.3`.  The Makefile threads this into install paths verbatim:
`libjanet.1.41.3-dev.dylib`.

`scripts/build-tiger.sh` reads `JANET_VERSION` directly from
`janetconf.h` (the literal string after `#define JANET_VERSION`).
So tarballs are `janet-1.41.3-dev-tiger-g3.tar.gz` while we're
on master between releases; will be `janet-1.42.0-tiger-g3.tar.gz`
or similar once we re-pin to a release commit.
