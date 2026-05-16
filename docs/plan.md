# Plan: Janet on `powerpc-apple-darwin8` (Mac OS X 10.4 Tiger)

Bring [Janet](https://github.com/janet-lang/janet) (a Lisp-like
programming language with a small ~50-file C interpreter) back to
PowerPC Tiger.  Upstream has no Tiger build in its release pipeline;
the last released-binary Tiger build was 1.27.0 via leopard.sh in
March 2023, and shipped with one locally-maintained patch (a sketch
of a `posix_spawn` fallback that was never debugged to working).
This project closes that gap and ships proper standalone tarballs.

This is bounded archaeology — a small number of surgical patches
against upstream `master` plus Tiger build orchestration.  Not a
fork, not a research project.

## Goal

End-to-end: a `janet` REPL that runs on a Tiger PPC G3, executes
pure-Janet programs, AND loads native C modules (specifically
[janet-lzo](https://github.com/cellularmitosis/janet-lzo)) without
crashing.  Tarball is installed via curl one-liner; no separate
runtime dependencies required after install.

Success looks like:

```
$ curl http://leopard.sh/misc/beta/janet-X.Y.Z-tiger-g3.tar.gz | gunzip | tar x -C /opt/
$ /opt/janet-X.Y.Z/bin/janet -e '(print "hello from janet on tiger ppc")'
hello from janet on tiger ppc
$ /opt/janet-X.Y.Z/bin/jpm install https://github.com/cellularmitosis/janet-lzo
$ /opt/janet-X.Y.Z/bin/janet -e '(import lzo) (print (lzo/decompress (lzo/compress @"hello world")))'
hello world
```

## Explicit non-goals

- **Upstreaming the Tiger build process.**  Upstream Janet's Makefile
  isn't going to learn `/opt/macports-legacy-support` paths.  What
  we upstream is the *C-level portability patches* (e.g. the
  `posix_spawn` fallback); the build orchestration lives in this
  repo forever.
- **Intel Tiger.**  PowerPC only.
- **Self-bootstrap from Apple GCC 4.0.**  We use gcc-4.9.4 from
  tigersh, like every other sister project.
- **AltiVec performance work in M1.**  M2.
- **64-bit PPC.**  M3.
- **Cross-build from arm64 macOS.**  Native build on Tiger, like
  the leopard.sh 1.27.0 recipe.  Cross-build is a future option
  if iteration speed becomes painful.

## Why this is tractable

1. **Janet upstream is small.**  ~50 .c files in `src/core/`, no
   JIT, no heavy dependencies.  Builds in seconds even on G3.  The
   normal build also produces a single-file amalgamation
   (`build/c/janet.c` + `janet.h` + `janetconf.h`) which is a useful
   embedding target down the road.

2. **Most of the portability work is already done in upstream master.**
   Eight PRs landed in `janet-lang/janet` between 2020 and 2022, all
   surgical Tiger gaps:

   | PR | Year | What it did |
   |---|---|---|
   | [#431](https://github.com/janet-lang/janet/pull/431) | 2020 | `os/arch` returns `"ppc"` via `__ppc__` |
   | [#432](https://github.com/janet-lang/janet/pull/432) | 2020 | `#ifdef O_CLOEXEC` guards (Tiger lacks the flag) |
   | [#436](https://github.com/janet-lang/janet/pull/436) | 2020 | pre-10.7: `/dev/urandom` instead of `arc4random_buf` |
   | [#936](https://github.com/janet-lang/janet/pull/936) | 2022 | `__MACH__` → `JANET_APPLE` consolidation |
   | [#937](https://github.com/janet-lang/janet/pull/937) | 2022 | Mach clock shim gated on `!MAC_OS_X_VERSION_10_12` |
   | [#943](https://github.com/janet-lang/janet/pull/943) | 2022 | `.dylib` (not `.so`) on macOS |

   All trivial; all merged.  The pattern works.

3. **macports-legacy-support fills the remaining libc gap.**  Tiger
   lacks `clock_gettime`, `openat`, `fmemopen`, `getentropy`,
   `pthread_setname_np`, etc., but
   [macports-legacy-support](https://github.com/macports/macports-legacy-support)
   backfills all of those with a `-I/opt/.../include/LegacySupport
   -lMacportsLegacySupport` wiring.  This wasn't available in 2022
   when the previous Tiger porting effort stalled; it changes the
   shape of the problem substantially.

4. **The one remaining real problem is `posix_spawn`.**  Tiger
   lacks `<spawn.h>` entirely, and macports-legacy-support does
   **not** backfill it.  The leopard.sh 1.27.0 recipe contained a
   sketch of a `fork()`+`execve()` fallback (see
   `install-janet-1.27.0.sh` on leopard.sh), but it was never
   debugged to working state.  Getting that fallback solid and
   correct is the substantive engineering work of this project.

5. **Sibling projects established the workflow.**
   `llvm-7-darwin-ppc`, `ionpower-node`, `lumo-darwin8-ppc`,
   `tcc-darwin8-ppc`, `ghc-darwin8-ppc` all run on the same Tiger
   PPC fleet with the same `/opt`-prefix + tigersh +
   macports-legacy-support pattern.  We borrow it wholesale.

## Strategy: three buckets

### Bucket A — surgical portability patches → upstream PRs

Small, well-motivated diffs against `master`.  Live in `patches/`
canonically; expected to land upstream eventually.  Currently
anticipated:

- **Patch 1: `posix_spawn` fallback for pre-10.5 macOS.**  Wrap
  `#include <spawn.h>` in a feature-detect guard and provide a
  `fork()`+`execve()` path when the POSIX spawn API is unavailable.
  Start from the leopard.sh 1.27.0 sketch, debug it to working, send
  upstream.

- **Possible patch 2: simplify the Mach clock shim** (PR #937's gate
  could become `!HAS_CLOCK_GETTIME` rather than
  `!MAC_OS_X_VERSION_10_12`, since macports-legacy-support provides
  `clock_gettime` on Tiger and the Mach-based fallback becomes dead
  code).  Low priority; nice-to-have.

- More may surface during M1 bring-up.

### Bucket B — Tiger build orchestration → lives in this repo

Never upstreamed.  Includes:

- CPPFLAGS / LDFLAGS for macports-legacy-support.
- gcc-4.9.4 / make-4.3 / ld64-97.17-tigerbrew toolchain pinning.
- `scripts/build-tiger.sh` and friends.
- The G5 `tools/patch-header.janet` Bus-error workaround (deferred
  to M3).
- `install_name_tool` post-build wiring for `@loader_path`.

Two build modes:

- **Bundled** (default for our GitHub release): we build
  macports-legacy-support and Janet, ship the dylib inside
  `/opt/janet-X.Y.Z/lib/` with `install_name =
  @loader_path/libMacportsLegacySupport.dylib`.  Result: one
  standalone tarball that installs on a vanilla Tiger via
  `curl ... | tar x -C /opt/` with no other dependencies.
- **BYO** (for leopard.sh and source-builders who already have
  macports-legacy-support installed): build against an existing
  `/opt/macports-legacy-support-YYYYMMDD/` and skip the bundling
  step.  Lighter, no duplicate copy of the dylib.

### Bucket C — release artifacts and distribution

- Tarballs named `janet-X.Y.Z-<os>-<arch>.tar.gz`
  (e.g. `janet-1.41.2-tiger-g3.tar.gz`).
- Attached to GitHub releases as canonical URLs.
- Mirrored to `http://leopard.sh/misc/beta/` (passwordless scp:
  primary target is `mini10v:/var/www/html/misc/beta/`, which is
  the source of truth and rsyncs to `leopard.sh`; we also scp
  directly to `leopard.sh:/var/www/html/misc/beta/` so the file is
  visible immediately rather than after the next rsync cycle).
- README "Try it out" section uses the http://leopard.sh URL
  (cheaper than github for old hardware, and matches the pattern
  used by ionpower-node, tcc-darwin8-ppc, etc.).

## macports-legacy-support linking strategy

`@rpath` requires Leopard (LC_RPATH added in macOS 10.5).
`@executable_path/` and `@loader_path/` both work on Tiger.  We use
**`@loader_path/`** because runtime-loaded Janet native modules
(`.so` files in `/opt/janet-X.Y.Z/lib/janet/` or wherever) that link
against macports-legacy-support can then find the dylib next to them
without `@rpath`.

Final layout:

```
/opt/janet-X.Y.Z/
├── bin/janet                                  (links to ../lib via
│                                               @loader_path/../lib/...)
├── lib/
│   ├── libjanet.dylib                         (install_name =
│   │                                           @loader_path/libjanet.dylib)
│   ├── libMacportsLegacySupport.dylib        (install_name =
│   │                                           @loader_path/libMacports...)
│   └── janet/                                 (jpm-managed native modules)
├── include/janet.h
└── share/janet/                               (.janet library code)
```

### Caveat: `@loader_path` resolution from inside a native module

`@loader_path` resolves relative to the directory of *whatever
binary is doing the loading*.  For a Janet native module loaded at
runtime (a `.so` produced by `jpm build` and dropped under
`lib/janet/<modname>/`), the loader is the `.so` — so
`@loader_path/libMacportsLegacySupport.dylib` resolves to
`lib/janet/<modname>/libMacportsLegacySupport.dylib`, which is
the wrong directory.

There are a few ways out, all to be verified empirically in M1:

1. **`@loader_path/../../libMacportsLegacySupport.dylib`** when
   linking the `.so` — climbs back to `lib/`.  Brittle (depends on
   the depth jpm installs the `.so` to).
2. **`@executable_path/../lib/libMacportsLegacySupport.dylib`** —
   always resolves to the right place regardless of where the
   loaded module sits, but only works when there's a `janet`
   executable in the picture (true for our use, less true for
   embedding-Janet scenarios — which we don't need to support yet).
3. **Copy/symlink the dylib next to each native module.**  Wasteful
   but unambiguous.
4. **Find/build `libMacportsLegacySupport.dylib` such that the
   loader picks it up via the main `janet` binary's already-loaded
   symbols** (two-level vs flat namespace, or `-undefined
   dynamic_lookup` on the `.so`).  Likely the cleanest answer if it
   works; needs testing.

Session 001 / 002 picks whichever shape proves out on real
hardware.  M1.a's "precompiled janet-lzo dropped into place" smoke
will surface the answer.

## Pinned upstream version

We track upstream `janet-lang/janet` `master` pinned to a specific
SHA, chosen in session 001 from the then-current HEAD.  Bump
deliberately, session-by-session — never silently re-pull HEAD.

Current pin: **TBD — to be set in session 001**.

## Milestones

### M1 — G3 standalone build, native modules work

Split into two releases to ship something usable as fast as possible.
Most Janet programs don't need subprocess support; the ones that do
(jpm itself, anything shelling out) wait for M1.b.

**M1.a — first release.**  Pure-Janet REPL and native-module loader.
- Builds on **ibookg38** (Tiger G3, 384 MB RAM, gcc-4.9.4).
- Bundled build mode only (macports-legacy-support cohosted under
  `/opt/janet-X.Y.Z/lib/`).
- Tarball installs to `/opt/janet-X.Y.Z/` on a clean machine
  (verified on **ibookg37**, a separate test host).
- `janet` REPL works.
- `(import lzo) (lzo/decompress (lzo/compress @"hello"))` round-trips
  with janet-lzo **precompiled on the build host** and dropped into
  place — no `jpm install` yet, because jpm needs `os/spawn`.  The
  precompiled-and-dropped variant still exercises the
  `@loader_path` wiring and the native-module loader, which is what
  M1.a is really testing.
- Janet's own test suite passes, modulo tests that depend on
  `os/spawn` (marked + skipped, addressed in M1.b).

**M1.b — final M1 release.**  `posix_spawn` fallback → `os/spawn` and
`jpm install` work.
- `posix_spawn` fork+execve fallback debugged and landed as a patch.
  This is the bit the 1.27.0 leopard.sh recipe never got working;
  it's the substantive engineering work of M1.b.
- BYO build mode added (for leopard.sh and developers who already
  have macports-legacy-support installed at `/opt/macports-legacy-
  support-*/`).
- `jpm install https://github.com/cellularmitosis/janet-lzo` works
  end-to-end on a clean Tiger box.
- The `posix_spawn` patch goes upstream as a janet-lang/janet PR
  (separate timeline; not a release gate).

### M2 — G4 + AltiVec exploration

- Same as M1 but `-mcpu=7450 -maltivec`.
- Non-invasive first (just compiler flags + measurement).
- Invasive AltiVec patches against Janet source only if measurement
  justifies it.

### M3 — G5 / 64-bit

- Resolves the `tools/patch-header.janet` Bus error on G5 that broke
  the leopard.sh 1.27.0 build (likely workaround: build a bootstrap
  janet on G3, scp it to the G5 to use as the host janet during the
  G5 build — same trick as cross-bootstrapping).
- Optional: 64-bit `ppc64` build as a separate tarball.

## Native module smoke: janet-lzo

[janet-lzo](https://github.com/cellularmitosis/janet-lzo) is a small
Janet C native module wrapping the LZO compression library (`lzop`'s
library).  It uses `jpm` + a Makefile and exercises the loadable-
module loader.  A successful M1 means, end-to-end on a clean Tiger
G3:

1. `tigersh lzo2` installs liblzo2 to `/opt/lzo2-*` (existing recipe).
2. `jpm install https://github.com/cellularmitosis/janet-lzo` compiles
   the C module against our Janet headers and the system liblzo2,
   producing a `.so` under `lib/janet/`.
3. `janet -e '(import lzo) (print (lzo/decompress (lzo/compress @"hello world")))'`
   prints `hello world`.

If `@loader_path` resolution and the linker wiring are right, step 3
prints the string.  If the linker can't find macports-legacy-support
symbols from inside the `.so`, step 3 dies at load time — and we have
the next bug to fix.

## Prior art / references

- Last working Tiger Janet builds (1.20–1.27, 2022–2023):
  - https://leopard.sh/binpkgs/?prefix=janet-
  - Tiger install script: https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh
  - Leopard install script: https://leopard.sh/leopardsh/scripts/install-janet-1.27.0.sh
- macports-legacy-support upstream:
  https://github.com/macports/macports-legacy-support
  - Tiger install script: https://leopard.sh/tigersh/scripts/install-macports-legacy-support-20221029.sh
- Sister projects on this fleet:
  - [`../ionpower-node/`](../../../ionpower-node/) — Node.js runtime
    on TenFourFox's JIT.  Triad G3/G4/G5 release flow.
  - [`../tcc-darwin8-ppc/`](../../../tcc-darwin8-ppc/) — TinyCC
    backend for Tiger PPC.  Same `/opt` install pattern, in-tree
    source instead of patches.
  - [`../ghc-darwin8-ppc/`](../../../ghc-darwin8-ppc/) — GHC 9.2.8
    on Tiger PPC.  Patches-against-upstream model (closest sibling
    to this project's shape).
  - [`../lumo-darwin8-ppc/`](../../../lumo-darwin8-ppc/) — Lumo /
    ClojureScript REPL on ionpower-node.  Source of the
    globally-numbered session convention we use here.
