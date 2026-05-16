# Session 002 — JANET_NO_PROCESSES stub and first tarball

## Arrival state

Session 001 left the build at the expected next blocker:

```
src/core/os.c:62:19: fatal error: spawn.h: No such file or directory
```

`external/janet/` was on the `darwin-ppc` branch with one commit
(patch 0001, features.h) on top of the pinned SHA.  No build
script, no install_name_tool wiring, no tarball yet.  Goal:
implement the `JANET_NO_PROCESSES` stub (HANDOFF.md option 1), get
the build through to a working `janet` binary, package as a
tarball, and verify on ibookg37.

## What happened

### 1. JANET_NO_PROCESSES is already an upstream flag

A grep for `JANET_NO_PROCESSES` in `external/janet/` found
**`#ifndef JANET_NO_PROCESSES`** already wrapping the entire
`os/spawn` / `os/execute` / `os/shell` machinery in `os.c` (lines
343–1640) and the corresponding `JANET_CORE_REG` registrations
(line 3004+).  Upstream meson also exposes it
(`meson.build:96: conf.set('JANET_NO_PROCESSES', not get_option('processes'))`),
and emscripten auto-defines it in `src/include/janet.h:168`.

So the M1.a stub isn't a from-scratch flag — it's a one-line
completion of an already-existing flag.  The only thing outside
the existing guard was `#include <spawn.h>` at line 62 (in the
platform-includes section, gated only by `JANET_PLAN9`).

### 2. Patch 0002: gate `<spawn.h>` behind `JANET_NO_PROCESSES`

Trivial one-line change:

```diff
-#ifndef JANET_PLAN9
+#if !defined(JANET_PLAN9) && !defined(JANET_NO_PROCESSES)
 #include <spawn.h>
 #endif
```

Committed to `external/janet/` as `66d03e3b`, regenerated as
[`patches/0002-os.c-gate-spawn.h-include-behind-JANET_NO_PROCESSES.patch`](../../../patches/0002-os.c-gate-spawn.h-include-behind-JANET_NO_PROCESSES.patch).

Upstreamable in shape: small, well-motivated, no Tiger-specific
paths.  Worth sending upstream as part of the larger Tiger PR.

### 3. First retry build — CPPFLAGS ignored, then CFLAGS ignored too

First retry passed `-DJANET_NO_PROCESSES` via **CPPFLAGS**.  Result:
exact same `spawn.h: No such file or directory` failure, because
Janet's Makefile **never uses `CPPFLAGS`** (see
[findings.md](findings.md#janets-makefile-doesnt-use-cppflags-and-its-boot-phase-uses-bootcflags-not-cflags)).
The Makefile takes user defines via `CFLAGS`.

Second retry passed it via **CFLAGS**.  Same failure.  Reason: the
"bootstrap" phase (`build/core/*.boot.o`) uses a separate
`BOOT_CFLAGS` variable that's hardcoded and **does not include
`$(CFLAGS)`**:

```makefile
BOOT_CFLAGS:=-DJANET_BOOTSTRAP -DJANET_BUILD=$(JANET_BUILD) -O0 $(COMMON_CFLAGS) -g
```

So there's no clean way to inject a `-D` into the boot-phase
compile from the environment.  Options were (a) edit
`janetconf.h`, (b) wrap `CC` with the define baked in, (c) auto-
detect in `features.h`.  Picked **(c)** — most upstreamable and
makes the source tree "just work" on Tiger with no flag gymnastics.

### 4. Patch 0003: auto-define `JANET_NO_PROCESSES` on pre-Leopard Apple

Reused the `JANET_APPLE_PRE_LEOPARD` macro from patch 0001:

```c
/* features.h, after the linux _GNU_SOURCE block */
#if defined(JANET_APPLE_PRE_LEOPARD) && !defined(JANET_NO_PROCESSES)
# define JANET_NO_PROCESSES
#endif
```

Auto-detects, no build-time flag needed.  Combined with patch 0002,
the same upstream source tree compiles on Tiger as long as
`AvailabilityMacros.h` reports pre-Leopard.

Committed as `d2acfcbe`, regenerated as
[`patches/0003-features.h-auto-define-JANET_NO_PROCESSES-on-pre-Leo.patch`](../../../patches/0003-features.h-auto-define-JANET_NO_PROCESSES-on-pre-Leo.patch).

### 5. Third build attempt — got further, then hit O_CLOEXEC

With patches 0001–0003 applied, the build cleanly compiled
`net.c`, `os.c`, and the surrounding files.  It got past the M1
blockers we knew about and into a new one:

```
src/core/util.c:1086:57: error: 'O_CLOEXEC' undeclared (first use in this function)
     RETRY_EINTR(randfd, open("/dev/urandom", O_RDONLY | O_CLOEXEC));
```

This is `janet_cryptorand` falling through to the `/dev/urandom`
path on Tiger (which lacks `arc4random_buf`, gated already by
`MAC_OS_X_VERSION_10_7`).  Tiger also lacks `O_CLOEXEC` (added in
10.7).

**But macports-legacy-support DOES backfill `O_CLOEXEC`** — its
`include/LegacySupport/sys/fcntl.h` shim adds
`#ifndef O_CLOEXEC #define O_CLOEXEC 0 #endif` after including the
real `<sys/fcntl.h>`.  We just needed
`-I.../LegacySupport` on the boot-phase compile command line, and
that's what BOOT_CFLAGS doesn't pass through.

### 6. Patch 0004: Makefile honors CPPFLAGS

Folded `$(CPPFLAGS)` into `COMMON_CFLAGS` (which feeds both
`BOOT_CFLAGS` and `BUILD_CFLAGS`):

```diff
-COMMON_CFLAGS:=-std=c99 -Wall -Wextra -Isrc/include -Isrc/conf -fvisibility=hidden -fPIC
+COMMON_CFLAGS:=-std=c99 -Wall -Wextra -Isrc/include -Isrc/conf -fvisibility=hidden -fPIC $(CPPFLAGS)
```

One line.  Matches standard make idiom: `CPPFLAGS` carries
preprocessor flags (`-D`, `-I`) that should apply uniformly.
Committed as `51e4dc76`, regenerated as
[`patches/0004-Makefile-honor-CPPFLAGS-in-both-boot-and-final-compi.patch`](../../../patches/0004-Makefile-honor-CPPFLAGS-in-both-boot-and-final-compi.patch).

Upstreamable in shape: it's a general portability/usability
improvement, not Tiger-specific.

### 7. Fourth build — through to a working janet binary

With patches 0001–0004 applied and
`CPPFLAGS=-I/opt/macports-legacy-support-20221029/include/LegacySupport`,
the build ran to completion:

```
=== smoke ===
hello from janet 1.41.3-dev on tiger ppc
```

Time: ~3 minutes wall-clock on ibookg38 (G3 700 MHz).
Full log: [`build-logs/build-tiger-run2.log`](build-logs/build-tiger-run2.log).

### 8. `scripts/build-tiger.sh` + `scripts/build-tiger-remote.sh`

Promoted the inline build env into a real pipeline.  Two scripts:

- [`scripts/build-tiger.sh`](../../../scripts/build-tiger.sh) — runs
  on uranium.  Calls `fetch-janet.sh`, derives the janet version
  from `janetconf.h`, rsyncs the patched source to the Tiger host
  (default `ibookg38`), invokes the remote build, and scp's the
  tarball back to `releases/`.
- [`scripts/build-tiger-remote.sh`](../../../scripts/build-tiger-remote.sh) —
  runs on the Tiger host.  Configures CPPFLAGS/LDFLAGS, does
  `make` + `make install DESTDIR=...`, bundles
  `libMacportsLegacySupport.dylib` into `$PREFIX/lib/`, runs
  `install_name_tool` to wire `@loader_path`, smoke-tests the
  staged binary, and tars up `$PREFIX`.

Version naming: we ship as **`janet-1.41.3-dev-tiger-g3`** —
matching `(print janet/version)` verbatim.  Upstream's
`janetconf.h` carries `JANET_VERSION_EXTRA "-dev"` between
releases, and rather than strip it the script preserves it.  When
upstream cuts 1.42.0 (or whatever's next) we re-pin and the
tarball name follows naturally.

### 9. install_name_tool wiring (the @loader_path bit)

Layout of the bundled tarball is:

```
/opt/janet-1.41.3-dev/
├── bin/janet          (links → @loader_path/../lib/libMacportsLegacySupport.dylib)
├── lib/
│   ├── libjanet.1.41.3-dev.dylib   (real file)
│   ├── libjanet.1.41.dylib         (symlink → libjanet.1.41.3-dev.dylib)
│   ├── libjanet.dylib              (symlink → libjanet.1.41.dylib)
│   ├── libjanet.a
│   └── libMacportsLegacySupport.dylib  (id = @loader_path/...)
└── include/janet/janet.h, share/man/man1/janet.1, lib/pkgconfig/janet.pc
```

Wiring:
- `bin/janet` had its `-lMacportsLegacySupport` recorded as the
  absolute build-time path; `install_name_tool -change` rewrites
  to `@loader_path/../lib/libMacportsLegacySupport.dylib`.
- `lib/libjanet.1.41.3-dev.dylib` gets the same treatment for its
  internal `libMacportsLegacySupport` dep (sibling reference:
  `@loader_path/libMacportsLegacySupport.dylib`), and its own
  install-name is set to `@loader_path/libjanet.1.41.dylib`
  (matching the Makefile-baked SONAME).
- `lib/libMacportsLegacySupport.dylib` self-id'd to
  `@loader_path/libMacportsLegacySupport.dylib`.

Note: `bin/janet` is **statically linked** against the Janet core
(it does *not* depend on `libjanet.dylib`).  Janet's Makefile
links bin/janet directly from `build/janet.o build/shell.o`,
which is the same object set used to build the shared library.
The shared library is for native module consumers, not the binary
itself.

### 10. ibookg37 verification

scp'd the 1.7 MB tarball to ibookg37 (a clean Tiger G3 — only
`/opt/janet-1.41.3-dev/` and the system + tigersh deps present):

```
$ /opt/janet-1.41.3-dev/bin/janet -e '(print "hello from janet " janet/version " on tiger ppc — ibookg37 clean host")'
hello from janet 1.41.3-dev on tiger ppc — ibookg37 clean host

$ /opt/janet-1.41.3-dev/bin/janet -e '(print (+ 1 2)) (each x [:a :b :c] (print x))'
3
a
b
c

$ /opt/janet-1.41.3-dev/bin/janet -e '(os/spawn ["echo"] :p)'
error: unknown symbol os/spawn
```

The `os/spawn` panic is the **expected M1.a behavior** — the symbol
is genuinely absent from the binary (not panicking from a stub
function).  That's the cleanest possible "feature missing" UX
given the M1.b work hasn't shipped yet.

`otool -L` on the installed `bin/janet`:

```
@loader_path/../lib/libMacportsLegacySupport.dylib          (ours, bundled)
/usr/lib/libgcc_s.1.dylib                                   (Tiger system)
/opt/gcc-4.9.4/lib/libgcc_s.1.dylib                         (gcc runtime)
/usr/lib/libSystem.B.dylib                                  (Tiger system)
```

Three of those are already on any Tiger box with gcc-libs-4.9.4
installed.  The fourth resolves via @loader_path.

### 11. Janet's own test suite — 29 PASS, 1 FAIL (expected), 3 SKIP

Ran the upstream test suite on ibookg38 against `build/janet`.
Pre-emptively skipped `suite-ev.janet`, `suite-ev2.janet`,
`suite-filewatch.janet` (use os/spawn).  Full log:
[`build-logs/test-suite.log`](build-logs/test-suite.log).

```
=== summary: 29 passed, 1 failed, 3 skipped ===
failed: test/suite-os.janet
```

The single failure is:

```
test/suite-os.janet:145:14: compile error: unknown symbol os/execute
```

Exactly the M1.a-stubbed-out symbol — expected.  All other 29
suites (array, asm, boot, buffer, bundle, capi, cfuns, compile,
corelib, debug, ffi, inttypes, io, marsh, math, net, parse, peg,
pp, specials, string, strtod, struct, symcache, table, tuple,
unknown, value, vm) pass cleanly on PPC Tiger.  This is a strong
M1.a signal — the runtime, parser, VM, GC, I/O, networking, math,
PEGs, and FFI machinery are all healthy on the target.

## Exit state

- **Patches 0001–0004 land** as a clean upstreamable stack — all
  pre-Leopard auto-detect or general portability, nothing Tiger-
  filename-specific.
- **`scripts/build-tiger.sh` + `scripts/build-tiger-remote.sh`** are
  the canonical M1.a build pipeline.  End-to-end: ~3 minutes from
  `scripts/build-tiger.sh` to a 1.7 MB tarball.
- **`releases/janet-1.41.3-dev-tiger-g3.tar.gz`** is built,
  install_name_tool'd, and verified on ibookg37 (clean Tiger G3
  test host).
- **REPL works.  29/30 of Janet's own test suite passes.**  The
  one failure is the expected `os/spawn`/`os/execute` absence;
  three suites pre-emptively skipped (use os/spawn).

M1.a's core acceptance gate is met:
- ✅ Curl-installable tarball
- ✅ Standalone @loader_path wiring
- ✅ `libMacportsLegacySupport.dylib` bundled
- ✅ REPL works on a clean test host
- ✅ Test suite green except for the deliberately-disabled bits

What's still M1.a-related but optional:
- janet-lzo precompiled native-module smoke (bonus item 5).
- GitHub release + scp to mini10v + scp to leopard.sh.
- Update outer README's status / build matrix.
- `demos/v0.1.0-hello.{janet,sh}`.

What's M1.b:
- `posix_spawn` fork+execve fallback patch.
- BYO macports-legacy-support build mode.
- `jpm install` from-git-URL on clean Tiger.

See [HANDOFF.md](HANDOFF.md) for the session-003 primer.
