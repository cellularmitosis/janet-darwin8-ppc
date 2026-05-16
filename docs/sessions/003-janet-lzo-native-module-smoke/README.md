# Session 003 — janet-lzo native-module smoke

## Arrival state

Session 002 closed the M1.a build-and-tarball gate: a working
1.7 MB [`releases/janet-1.41.3-dev-tiger-g3.tar.gz`](../../../releases/janet-1.41.3-dev-tiger-g3.tar.gz),
patches 0001–0004 landed, `@loader_path` wiring verified for the
bundled `libMacportsLegacySupport.dylib`, REPL working on ibookg37
(clean Tiger G3), 29/30 of Janet's own test suite green.

What's left of M1.a is split across two strands:

1. **Distribution + polish** — GitHub release, scp to leopard.sh,
   README badge updates, demo script.  Pure paperwork.
2. **`janet-lzo` precompiled native-module smoke** (roadmap M1.a
   item 5) — the actual remaining engineering validation: prove the
   native-module loader works against the freshly-built tarball,
   without going through `jpm install` (which depends on `os/spawn`,
   blocked behind M1.b).

This session does (2).  Distribution stays deferred.

## What happened

### 1. Reconnaissance — janet-lzo's shape

[janet-lzo](https://github.com/cellularmitosis/janet-lzo) is a
single C file: `lzo.c` (`#include <janet.h>`, `#include <lzo/lzo1x.h>`,
links `-llzo2`), a `project.janet` declaring a `(declare-native ...)`
target, and a Makefile that just shells out to `jpm build`.  Tiny
enough to build by hand.

No jpm available on Tiger (depends on `os/spawn`), so I had to
reproduce jpm's macOS link recipe directly.  The canonical recipe is
in [`janet-lang/jpm/configs/macos_config.janet`](https://github.com/janet-lang/jpm/blob/master/configs/macos_config.janet):

```janet
:cflags          @["-std=c99"]
:dynamic-cflags  @["-fPIC"]
:dynamic-lflags  @["-shared" "-undefined" "dynamic_lookup" "-lpthread"]
:modpath         "/usr/local/lib/janet"
:modext          ".so"
```

Key insight: **native modules do not link against `libjanet.dylib`**.
They use `-undefined dynamic_lookup`, which leaves janet's C-API
symbols (`janet_panic`, `janet_wrap_buffer`, etc.) unresolved at
build time and resolves them at `dlopen()` time from the already-
running janet process.  This matches the fact that `bin/janet` is
statically linked against the janet core (session 002 finding) — the
core symbols live in the binary, not in a shared library.

This dodges the HANDOFF's framing that "the native module record
will reference @loader_path-relative libjanet — that's the bit being
tested."  We *are* still testing the M1.a wiring, just at a
different layer: the bundled `libMacportsLegacySupport.dylib`
@loader_path resolution happens when `bin/janet` first starts,
*before* it dlopens any native module; by the time we `(import lzo)`
the legacy-support symbols are already live in the address space.
This is the right call because it matches what `jpm install` will
produce in M1.b — testing the same shape users will hit.

### 2. Build host setup: install the tarball into /opt on ibookg38

The previous session's tarball had only been *built* on ibookg38
and *test-installed* on ibookg37.  ibookg38 itself didn't have
`/opt/janet-1.41.3-dev/` yet, so we couldn't `#include <janet.h>`
against it.  One-liner fix:

```bash
ssh ibookg38 'cd /opt && tar xzf -' < releases/janet-1.41.3-dev-tiger-g3.tar.gz
```

`/opt` on the fleet is `drwxrwxr-x root admin` and `macuser` is in
`admin`, so no sudo needed.

### 3. `scripts/build-janet-lzo-remote.sh`

[`scripts/build-janet-lzo-remote.sh`](../../../scripts/build-janet-lzo-remote.sh)
runs on the Tiger build host.  Reads `SRC_DIR` (the rsync'd
janet-lzo checkout), `JANET_PREFIX`, `LZO_PREFIX`, builds the
`.so` with jpm's defaults applied directly:

```
gcc-4.9 -std=c99 -Wall -Wextra -Os -fPIC \
        -I/opt/janet-1.41.3-dev/include/janet \
        -I/opt/lzo-2.10/include \
        -shared -undefined dynamic_lookup -lpthread \
        -L/opt/lzo-2.10/lib -llzo2 \
        -o build/lzo.so lzo.c
```

Then an in-place self-smoke: drop the `.so` into a temp dir, set
`JANET_PATH` to point there, `(import lzo)` + compress + decompress.

### 4. Fetching janet-lzo to ibookg38

No `git` on ibookg38.  Used `/opt/tigersh-deps-0.1/bin/curl` with
the local CA bundle (`/opt/tigersh-deps-0.1/share/cacert.pem`,
**not** `/Users/macuser/tmp/cacert-2026-03-19.pem` — that's the
`imacg3-dev` skill's convention, this host doesn't have it) to
pull `https://github.com/cellularmitosis/janet-lzo/archive/refs/heads/master.tar.gz`.

```bash
/opt/tigersh-deps-0.1/bin/curl -fsSL \
    --cacert /opt/tigersh-deps-0.1/share/cacert.pem \
    -o janet-lzo.tar.gz \
    https://github.com/cellularmitosis/janet-lzo/archive/refs/heads/master.tar.gz
```

### 5. First build attempt — works, smoke trips on Tiger mktemp

Compile + link cleanly produced a 10,480-byte `lzo.so`.  `otool -L`:

```
build/lzo.so:
    build/lzo.so                                 (the install-name baked-in)
    /opt/lzo-2.10/lib/liblzo2.2.dylib
    /usr/lib/libgcc_s.1.dylib
    /opt/gcc-4.9.4/lib/libgcc_s.1.dylib
    /usr/lib/libSystem.B.dylib
```

Five recorded dylibs.  No `libjanet` — exactly as expected with
`dynamic_lookup`.  All five resolvable on the test host (verified
explicitly — see step 6).

The build-host smoke step failed with:

```
usage: mktemp [-d] [-q] [-t prefix] [-u] template ...
```

Tiger's `mktemp` doesn't accept a bare `-d` — it requires a
template.  Fix: `mktemp -d -t janet-lzo-smoke.XXXXXX`.  Trivial.

### 6. Build-host smoke — round-trip OK

After the mktemp fix:

```
=== staged smoke (against /opt/janet-1.41.3-dev) ===
compressed bytes:   37
decompressed bytes: 33
round-trip ok:      true
```

Full log:
[`build-logs/build-lzo-ibookg38.log`](build-logs/build-lzo-ibookg38.log).

### 7. ibookg37 dependency audit (before testing)

Before testing on the clean host, audited the five dylibs the `.so`
records against what's actually present on ibookg37:

| Dylib | ibookg37 state |
|---|---|
| `/opt/lzo-2.10/lib/liblzo2.2.dylib` | ✅ present (122 KB, `lzo-2.10` tigersh pkg) |
| `/usr/lib/libgcc_s.1.dylib` | ✅ Tiger system |
| `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib` | ✅ present (466 KB) |
| `/usr/lib/libSystem.B.dylib` | ✅ Tiger system |

The dual `libgcc_s.1.dylib` reference (one `/usr/lib`, one
`/opt/gcc-4.9.4/lib`) is the same shape `bin/janet` carries and
was called out in session 002's gotchas — both resolve, neither
is a fallback, dyld loads both.

Note: ibookg37 has `/opt/gcc-4.9.4/` installed too (separate from
`/opt/gcc-libs-4.9.4/` — the latter is the runtime-only pkg, the
former the full compiler).  Session 002's initial survey missed
the gcc-4.9.4 dir; both are present.

### 8. Round-trip on ibookg37 — `(import lzo)` works two ways

Test 1: scp the `.so` to `$HOME/tmp/lzo.so`, run with `JANET_PATH`
override:

```
=== Test 1: JANET_PATH (no sudo) ===
msg:                hello from janet-lzo on tiger ppc — ibookg37 clean host
compressed bytes:   61
decompressed bytes: 57
round-trip ok:      true

=== larger payload ===
input bytes:        12000
compressed bytes:   83
decompressed bytes: 12000
compression ratio:  0.007
round-trip ok:      true

=== marshal/unmarshal round-trip ===
obj  : {:a 1 :b 2 :nested @["foo" "bar" 42]}
round: {:a 1 :b 2 :nested @["foo" "bar" 42]}
equal: true
```

Test 2: install into the canonical syspath
(`/opt/janet-1.41.3-dev/lib/janet/lzo.so`), no `JANET_PATH`
override, vanilla `(import lzo)`:

```
=== Test 2: canonical syspath ===
hello from /opt/janet-1.41.3-dev/lib/janet/lzo.so
60000-byte payload: 60000 -> 289, ratio 0.0048, ok=true
```

Full log:
[`build-logs/round-trip-ibookg37.log`](build-logs/round-trip-ibookg37.log).

A 60 KB repetitive payload compresses to **0.48 %** of its original
size and round-trips byte-exact.  Janet's `marshal` output also
survives the round-trip — a janet struct
`{:a 1 :b 2 :nested @["foo" "bar" 42]}` makes it through
`marshal → lzo.compress → lzo.decompress → unmarshal` with `deep=`
matching.  Both the C bindings and the native-module ABI are
healthy.

### 9. Where does the syspath come from?

Janet's module-search uses `(dyn :syspath)` for the `:sys:` token
in `module/paths`.  On our install, syspath is
`/opt/janet-1.41.3-dev/lib/janet` (baked in at build time from
`PREFIX`), so the matching pattern is `:sys:/:all::native:` →
`/opt/janet-1.41.3-dev/lib/janet/lzo.so`.  That's the canonical
location for a third-party native module against this tarball, and
the location `jpm install` will write to in M1.b.

### 10. Artifacts kept under the session dir

- [`lzo.so`](lzo.so) — the built native module (10,480 bytes).
  Kept as a reference artifact; small enough to check in.  Future
  rebuilds against future janet tarballs will replace this.
- [`build-logs/build-lzo-ibookg38.log`](build-logs/build-lzo-ibookg38.log) —
  the build script's full output on the build host.
- [`build-logs/round-trip-ibookg37.log`](build-logs/round-trip-ibookg37.log) —
  both round-trip tests from the clean host.

## Exit state

- **`scripts/build-janet-lzo-remote.sh`** is the canonical recipe
  for building a Janet native module against this project's tarball
  on Tiger.  Generalizes to any other single-`.c` janet binding —
  swap `lzo` for `<name>`, swap `-llzo2 -I/opt/lzo-2.10/...` for
  the new lib's flags.
- **janet-lzo `lzo.so` builds clean on ibookg38** (~5 seconds, single
  source file, no jpm).
- **Round-trip verified on ibookg37** under both `JANET_PATH` and
  the canonical `/opt/janet-1.41.3-dev/lib/janet/` syspath.

M1.a's native-module gate (roadmap item 5) is **met**.  Updated:
- [README.md](../../../README.md): native-module row → ✅ M1.a.
- [docs/roadmap.md](../../roadmap.md): item 5 marked done with
  pointer back to this session.

What's still M1.a-but-optional:
- GitHub release + scp to leopard.sh + mini10v.
- Outer-README "Try it out!" updated past the "_(Sketch)_" stub.
- `demos/v0.1.0-hello.{janet,sh}`.

What's M1.b:
- `posix_spawn` fork+execve fallback patch.
- BYO macports-legacy-support build mode.
- `jpm install` from a git URL on a clean Tiger box.  Once that
  works, the janet-lzo install is a one-liner:
  `jpm install https://github.com/cellularmitosis/janet-lzo`.

See [HANDOFF.md](HANDOFF.md) for the session-004 primer.
