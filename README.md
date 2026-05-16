# janet-darwin8-ppc

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

## Status

**Bootstrap / pre-release.**  Scaffolding in place; first build
attempt is session 001.  No release yet.

## Try it out!

_(Placeholder — fills in after the first M1 release.)_

On any G3, G4, or G5 Mac running Tiger:

```
sudo mkdir -p /opt
sudo chmod ugo+rwx /opt
cd /opt
# (one-liner installs for prerequisites will go here)
curl http://leopard.sh/misc/beta/janet-X.Y.Z-tiger-g3.tar.gz | gunzip | tar x
/opt/janet-X.Y.Z/bin/janet -e '(print "hello from janet on tiger ppc")'
```

## Why

Janet hasn't shipped a Tiger build since I cut 1.27.0 for leopard.sh
in March 2023.  The dependencies that were the obstacle then (no
`clock_gettime`, no `arc4random_buf`, no `O_CLOEXEC`, etc.) are now
covered upstream — eight of my own PRs to `janet-lang/janet` between
2020–2022 landed cleanly — or covered by
[macports-legacy-support](https://github.com/macports/macports-legacy-support),
which backfills the broader libc gap.

The one stubborn remaining piece is `posix_spawn`: Tiger ships no
`<spawn.h>` and macports-legacy-support doesn't backfill it.  The
1.27.0 leopard.sh recipe carries a sketch of a `fork()` + `execve()`
fallback, but it was never debugged to working.  This repo's first
substantive job is to close that gap.

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
| G3 (PPC 750) Tiger | ibookg38 (build) / ibookg37 (test) | ❌ M1 | Critical-path target.  See [docs/roadmap.md](docs/roadmap.md). |
| G4 (PPC 7450) Tiger | TBD | ❌ M2 | Adds `-mcpu=7450 -maltivec`.  |
| G5 (PPC 970) Tiger | pmacg5 | ❌ M3 | `tools/patch-header.janet` Bus error on G5 in 1.27.0; needs bootstrap-on-G3 workaround. |
| G4 Leopard | TBD | ❌ Later | Leopard is more POSIX, so mechanically easier. |
| ppc64 Tiger | TBD | ❌ M3 | 64-bit variant; separate tarball. |

### Language & libraries

| Surface | Status | Notes |
|---|---|---|
| Pure-Janet REPL (`janet -e`) | ❌ M1.a | Gate: builds clean against macports-legacy-support and runs on a clean ibookg37 install. |
| Native module loading (smoke = [janet-lzo](https://github.com/cellularmitosis/janet-lzo)) | ❌ M1.a | M1.a gate: `(import lzo) (lzo/decompress (lzo/compress @"hello"))` round-trips with janet-lzo **precompiled** on the build host and dropped into place — validates `@loader_path` + loader without needing `os/spawn`. |
| `os/spawn` (subprocess) | ❌ M1.b | The `posix_spawn` fork+execve fallback — the bit the 1.27.0 leopard.sh sketch never got working.  M1.b gate. |
| `jpm install` from git URL | ❌ M1.b | Depends on `os/spawn`; lights up once the above lands.  M1.b adds the `jpm install janet-lzo`-on-clean-Tiger end-to-end smoke. |
| AltiVec via `-mcpu=7450 -maltivec` | ❌ M2 | Compiler flags only; no source patches. |
| AltiVec source patches | ❌ Deferred | Only if M2 measurement justifies.  See [docs/deferred.md](docs/deferred.md). |

### Linking & install

| Surface | Status | Notes |
|---|---|---|
| Standalone `/opt/janet-X.Y.Z/` tarball | ❌ M1.a | Curl-installable, no separate runtime deps.  Ships macports-legacy-support's dylib cohosted under `lib/`. |
| `@loader_path` install names | ❌ M1.a | `@rpath` is Leopard+, so we use `@loader_path` for Tiger compat.  Wired post-link via `install_name_tool`. |
| BYO macports-legacy-support build mode | ❌ M1.b | For leopard.sh / developers with the lib already installed.  Lands alongside the `posix_spawn` fix. |

## Releases

| Tag | Date | Notes |
|---|---|---|
| _(none yet)_ | | First release ships at end of M1. |

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
