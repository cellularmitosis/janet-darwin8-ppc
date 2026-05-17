# janet-darwin8-ppc

<center><img src="docs/media/janet-tiger.jpg" width="480"></center>

[Janet](https://github.com/janet-lang/janet) — the small Lisp-like
programming language — resurrected for **Mac OS X 10.4 Tiger /
PowerPC**.

Upstream Janet has no Tiger build in its release pipeline; the last
released-binary Tiger build was 1.27.0 via
[leopard.sh](https://leopard.sh/binpkgs/?prefix=janet-) in March
2023, and shipped with one locally-maintained patch that was never
debugged to working state.  This project picks that thread back up,
tracks upstream `master` pinned to a specific SHA, ships a small set
of portability patches (intended for upstream), and produces
standalone `/opt/janet-X.Y.Z/` tarballs that run on real Tiger PPC
hardware.

## Try it out!

On any G3, G4, or G5 Mac running Tiger:

```
sudo mkdir -p /opt
sudo chmod ugo+rwx /opt
cd /opt
curl http://leopard.sh/misc/beta/janet-1.41.3-dev-r3-tiger-g3.tar.gz | gunzip | tar x
/opt/janet-1.41.3-dev/bin/janet -e '(print "hello from janet on tiger ppc")'
```

For the M1.b acceptance demo — full `jpm install` pipeline →
gcc-4.9 → lzo round-trip — grab
[`demos/v0.2.0-jpm-install-lzo.{janet,sh}`](demos/) from the repo and
run `sh demos/v0.2.0-jpm-install-lzo.sh`.  Or for the lighter
v0.1.0-style smoke (PEG / fiber / `string/format` / optional LZO
round-trip): [`demos/v0.1.0-hello.{janet,sh}`](demos/).

## Status

**M1.b released** ([v0.2.1](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.1)):

- [`janet-1.41.3-dev-r3-tiger-g3.tar.gz`](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/download/v0.2.1/janet-1.41.3-dev-r3-tiger-g3.tar.gz)
  — curl-installable 1.7 MB tarball, **with `os/spawn` /
  `os/execute` / `os/shell` working** via a fork+execve fallback
  (Tiger has no `<spawn.h>` / `posix_spawn`).  **No `/opt`
  prerequisites** — verified on ibookg37 with `/opt/gcc-4.9.4`
  moved aside.
- [`janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz`](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/download/v0.2.1/janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz)
  — same binary but BYO macports-legacy-support (smaller, for
  leopard.sh / source-builders with the dep already at
  `/opt/macports-legacy-support-20221029/`).
- `suite-os.janet` 59/60 on ibookg38 (the one fail is unrelated —
  `os/realpath` Tiger semantics, see
  [`docs/deferred.md`](docs/deferred.md)).  New `:cd` tests
  (success + chdir-failure-via-errpipe) exercise the fork+execve
  fallback's previously-untested code paths.
- End-to-end gate: `jpm install
  https://github.com/cellularmitosis/janet-lzo` succeeds on a
  clean Tiger G3 box, builds the native module via gcc-4.9,
  installs into `lib/janet/lzo.so`, and round-trips a 9 KB
  payload through `(lzo/decompress (lzo/compress …))` — every
  subprocess inside jpm rides on the fork+execve fallback.
- Mirrored at `http://leopard.sh/misc/beta/janet-1.41.3-dev-r3-tiger-g3.tar.gz`
  for the curl-install one-liner.

v0.2.1 is a bundling respin of [v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0):
identical Janet behavior, but with `-static-libgcc` so the binary no
longer carries a runtime dependency on `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib`
(i.e. doesn't require tigersh's `gcc-libs-4.9.4` package installed
on the target).  The earlier
[v0.1.0 (M1.a)](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0)
release shipped the pure-Janet REPL + native-module loader without
subprocess support; v0.2.1 is the recommended download.

## Why

Janet hasn't shipped a Tiger build since I cut 1.27.0 for leopard.sh
in March 2023.  The dependencies that were the obstacle then (no
`clock_gettime`, no `arc4random_buf`, no `O_CLOEXEC`, etc.) are now
covered upstream — eight of my own PRs to `janet-lang/janet` between
2020–2022 landed cleanly — or covered by
[macports-legacy-support](https://github.com/macports/macports-legacy-support),
which backfills the broader libc gap.

The one stubborn remaining piece was `posix_spawn`: Tiger ships no
`<spawn.h>` and macports-legacy-support doesn't backfill it.  The
1.27.0 leopard.sh recipe carried a sketch of a `fork()` + `execve()`
fallback that was never debugged to working state.  Closing that gap
was this repo's first substantive job — done in
[v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0)
([session 006](docs/sessions/006-posix-spawn-fallback/) for the
fallback itself, [session 007](docs/sessions/007-jpm-install-and-release/)
for the `jpm install` end-to-end gate).

See [`docs/plan.md`](docs/plan.md) for the full plan,
[`docs/roadmap.md`](docs/roadmap.md) for prioritized forward work.

## Implementation status

Updated as each release lands.  Empty for now; format borrowed from
sister projects
[`llvm-darwin8-ppc`](https://github.com/cellularmitosis/llvm-darwin8-ppc)
and [`ionpower-node`](https://github.com/cellularmitosis/ionpower-node).

Legend: ✅ Working / 🟡 Partial or pinned / ❌ Missing.

### Build matrix

| Arch | Host | Status | Notes |
|---|---|---|---|
| G3 (PPC 750) Tiger | ibookg38 (build) / ibookg37 (test) | ✅ M1 (G3) | M1.b [released as v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0) (session 007).  Bundled + BYO macports-legacy-support tarballs both verified on a clean ibookg37.  G3-built tarballs run on G4 (session 009) and G5 (session 010) too — PPC ISA is forward-compatible.  G4 + AltiVec is M2 (explored, no win); ppc64 is M3. |
| G4 (PPC 7450) Tiger | emac (build) / pbookg42, mdd (test) | 🟡 M2 explored | `TIGER_ARCH=g4 scripts/build-tiger.sh` produces `-tiger-g4.tar.gz`.  Verified standalone on `mdd` (Leopard G4 MDD with no mlsupport at `/opt/macports-legacy-support-20221029` — `@loader_path` bundling carries the dylib).  Net gain over G3 tarball running on the same G4 hardware: **−0.2% on a mixed Janet benchmark** (mandelbrot −2.6%, fib +0.6%, peg +2.0%, marshal flat) — within noise.  Not shipped as a release variant; v0.2.1 G3 tarball remains the recommended download for G4 too.  See [session 009](docs/sessions/009-m2-g4-altivec/). |
| G4 (PPC 7450) + AltiVec Tiger | emac (build) / pbookg42, mdd (test) | 🟡 M2 explored, no measurable win | `TIGER_ARCH=g4-altivec` adds `-maltivec -mabi=altivec -ftree-vectorize`.  Builds cleanly; runs cleanly on G4 Tiger + Leopard; **dyld-rejects on G3** (`incompatible cpu-subtype`).  gcc-4.9 auto-vectorization at `-O2 -ftree-vectorize` finds essentially nothing in Janet's scalar bytecode interpreter — performance indistinguishable from plain G4 tarball (within ±0.002 s on every workload).  Hand-rolled AltiVec source patches dropped as future work. |
| G5 (PPC 970) Tiger | pmacg5 (PowerMac11,2, 2.3 GHz dual) | ✅ M3 (userland + build) | The "G5 needs a bootstrap-on-G3 workaround" caveat — inherited from leopard.sh 1.27.0's G5 Bus error — turned out to be stale on our pinned SHA + toolchain.  `TIGER_HOST=pmacg5 scripts/build-tiger.sh` runs end-to-end and produces a working tarball; v0.2.1 G3 tarball also runs cleanly on pmacg5 (expected from PPC forward-compat — full smoke including `os/spawn`, PEG, fibers, marshal, `int/s64`).  Bench: **1.701 s** total best-of-5 on pmacg5, **~1.93× faster than 1.42 GHz G4** on the same Janet binary.  See [session 010](docs/sessions/010-m3-g5-bootstrap/). |
| G4 Leopard | pbookg42, mdd | 🟡 Smoked | Tiger-built G4 tarballs run on Leopard 10.5.8 G4 too (forward-compat); not productized as a separate Leopard build.  Session 009 ran the smoke on `pbookg42` (PowerBook5,2) and `mdd` (PowerMac3,6 MDD). |
| ppc64 Tiger | pmacg5 | ❌ M3 | 64-bit variant; separate tarball.  Scope expanded in [session 010](docs/sessions/010-m3-g5-bootstrap/ppc64-value-representation.md) to include a `JANET_NANBOX_64` upstream patch (auto-detect at [`janet.h:313`](external/janet/src/include/janet.h) doesn't list `__PPC64__`); without it, a ppc64 build would silently fall back to the 32-bit nanbox layout and forfeit the inner-loop win. |

### Language & libraries

| Surface | Status | Notes |
|---|---|---|
| Pure-Janet REPL (`janet -e`) | ✅ M1.a | Tarball builds clean against macports-legacy-support; runs on clean ibookg37 install (session 002). |
| Native module loading (smoke = [janet-lzo](https://github.com/cellularmitosis/janet-lzo)) | ✅ M1.a | `lzo.c` built via [`scripts/build-janet-lzo-remote.sh`](scripts/build-janet-lzo-remote.sh) (jpm's canonical darwin recipe: `-fPIC -shared -undefined dynamic_lookup`).  Dropped into `lib/janet/lzo.so` and round-tripped via `(import lzo) (lzo/decompress (lzo/compress @"hello"))` on ibookg37 (clean Tiger G3) — session 003. |
| `os/spawn` (subprocess) | ✅ M1.b | `posix_spawn` fork+execve fallback (patches 0002 / 0003 / 0004, session 006).  `suite-os.janet` 57/58 on ibookg38 (the one fail is unrelated — `os/realpath`).  See [`docs/sessions/006-posix-spawn-fallback/`](docs/sessions/006-posix-spawn-fallback/). |
| `jpm install` from git URL | ✅ M1.b | `jpm install https://github.com/cellularmitosis/janet-lzo.git` succeeds on clean ibookg37: git fetch + gcc-4.9 build + `cp` install + `(import lzo)` round-trip, every subprocess via the fork+execve fallback.  See [`docs/sessions/007-jpm-install-and-release/`](docs/sessions/007-jpm-install-and-release/). |
| AltiVec via `-mcpu=7450 -maltivec` | 🟡 M2 explored | Compiler-flag-only AltiVec build works (`TIGER_ARCH=g4-altivec scripts/build-tiger.sh`), but gcc-4.9 auto-vec at `-O2 -ftree-vectorize` finds nothing to vectorize in Janet's interpreter.  Net gain on a mixed benchmark: ~0%.  See [session 009](docs/sessions/009-m2-g4-altivec/). |
| AltiVec source patches | ❌ Won't do | Empirically dropped after session 009.  Compiler-flag AltiVec already gives 0% gain, so source-level intrinsics would mean hand-targeting hot loops in Janet's scalar bytecode interpreter — speculative, fragile against upstream, and not a clear win on interpreter dispatch. |

### Linking & install

| Surface | Status | Notes |
|---|---|---|
| Standalone `/opt/janet-X.Y.Z/` tarball | ✅ M1.a | Tarball built in session 002, released as [v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0) in session 005.  Curl-installable; ships macports-legacy-support's dylib under `lib/`. |
| `@loader_path` install names | ✅ M1.a | `bin/janet` → `@loader_path/../lib/...`; bundled dylibs self-id'd to `@loader_path/...`.  Verified on ibookg37. |
| BYO macports-legacy-support build mode | ✅ M1.b | `BYO_MACPORTS_LEGACY=1 scripts/build-tiger.sh` skips bundling + `install_name_tool` rewrites; the binary keeps the absolute LC_LOAD_DYLIB reference to `$LEGACY_SUPPORT_PREFIX/lib/libMacportsLegacySupport.dylib`.  Released as `janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz` alongside the bundled tarball (v0.2.1, session 008). |
| `-static-libgcc` on bundled tarball | ✅ M1.b (v0.2.1) | Bundled-mode build adds `-static-libgcc` to `LDFLAGS`, so `bin/janet` has no `LC_LOAD_DYLIB` entry for any `libgcc_s.dylib` — `otool -L` shows only the bundled mlsupport `@loader_path` entry + `/usr/lib/libSystem.B.dylib` (Tiger stock).  Tarball runs on bare Tiger with no `/opt` packages installed.  BYO mode left unchanged (callers already have the tigersh package set). |

## Releases

| Tag | Date | Notes |
|---|---|---|
| [v0.2.1](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.1) | 2026-05-16 | **M1.b bundling respin.**  `janet-1.41.3-dev-r3-tiger-g3.tar.gz` (bundled) + `janet-1.41.3-dev-r3-tiger-g3-byo.tar.gz` (BYO).  Bundled tarball now built with `-static-libgcc`, dropping the runtime dep on `/opt/gcc-4.9.4/lib/libgcc_s.1.dylib` — `otool -L bin/janet` shows only `@loader_path/../lib/libMacportsLegacySupport.dylib` and `/usr/lib/libSystem.B.dylib`.  Verified standalone on ibookg37 with `/opt/gcc-4.9.4` moved aside.  Janet itself is byte-equivalent to v0.2.0 (same SHA, same patches except a test-only `:cd` addition).  BYO unchanged from v0.2.0. |
| [v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0) | 2026-05-16 | **M1.b release.**  `janet-1.41.3-dev-r2-tiger-g3.tar.gz` (bundled) + `janet-1.41.3-dev-r2-tiger-g3-byo.tar.gz` (BYO macports-legacy-support).  `os/spawn`/`os/execute`/`os/shell` working via the fork+execve fallback.  Acceptance gate: `jpm install janet-lzo` on a clean Tiger box.  Fallback patches landed session 006; release session 007.  *Bundled tarball requires tigersh's `gcc-libs-4.9.4` package installed at `/opt` — fixed in v0.2.1.* |
| [v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0) | 2026-05-16 | First M1.a release.  `janet-1.41.3-dev-tiger-g3.tar.gz` — pure-Janet REPL + native-module loader on Tiger G3.  No `os/spawn` (deferred to M1.b).  Built session 002, demo'd session 004, released session 005. |

## How it's built

(Filling in as the build script matures.)

Build host: **ibookg38** (Tiger G3, gcc-4.9.4 via tigersh,
make-4.3, ld64-97.17-tigerbrew).  Native build, not cross-build.
Test host: **ibookg37** (clean Tiger G3, verifies the tarball is
genuinely standalone).

See [`scripts/`](scripts/) (skeleton; populated in session 001).

## Layout

```
docs/plan.md           — project brief.
docs/roadmap.md        — prioritized forward work.
docs/deferred.md       — parked / nice-to-have items.
docs/sessions/         — one dir per work session.
patches/               — git format-patch output, canonical record.
external/janet/        — gitignored upstream clone.
scripts/               — build orchestration.
tests/                 — smoke tests + native module verification.
demos/                 — one demo per release.
```

See [`CLAUDE.md`](CLAUDE.md) for the agent-facing version of the
above.

## Prior art

- [leopard.sh Janet packages](https://leopard.sh/binpkgs/?prefix=janet-)
  (1.20–1.27, 2022–2023) — the previous Tiger build effort.
- [Eight merged janet-lang/janet PRs (2020–2022)](https://github.com/janet-lang/janet/pulls?q=is%3Apr+author%3Acellularmitosis+is%3Aclosed)
  — fixed the trivial Tiger gaps in upstream.
- [macports-legacy-support](https://github.com/macports/macports-legacy-support)
  — backfills libc functions missing from Tiger.
- Sister projects on the same Tiger/PowerPC fleet:
  [`ionpower-node`](https://github.com/cellularmitosis/ionpower-node),
  [`ghc-darwin8-ppc`](https://github.com/cellularmitosis/ghc-darwin8-ppc),
  [`tcc-darwin8-ppc`](https://github.com/cellularmitosis/tcc-darwin8-ppc),
  [`llvm-darwin8-ppc`](https://github.com/cellularmitosis/llvm-darwin8-ppc),
  [`lumo-darwin8-ppc`](https://github.com/cellularmitosis/lumo-darwin8-ppc).
