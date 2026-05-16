# Claude agent instructions for this project

## What this project is

Bring [Janet](https://github.com/janet-lang/janet) — a Lisp-like
programming language with a small (~50-file) C interpreter — up on
**Mac OS X 10.4 Tiger / PowerPC**.  Track upstream HEAD pinned to a
specific SHA, ship a small set of portability patches (intended for
upstream), and produce standalone `/opt/janet-X.Y.Z/` tarballs that
run on real Tiger PPC hardware.

Project brief: [`docs/plan.md`](docs/plan.md).
Roadmap: [`docs/roadmap.md`](docs/roadmap.md).
Parked / deferred items: [`docs/deferred.md`](docs/deferred.md).

## Repo layout

```
docs/
  plan.md               — project brief: goals, non-goals, strategy.
  roadmap.md            — prioritized forward work (M1/M2/M3).
  deferred.md           — parked items, upstream PR follow-ups,
                          open questions.
  sessions/             — one dir per session, globally numbered.
    README.md           — sessions workflow.  Read this first.
    NNN-<slug>/         — session dirs.
patches/                — git format-patch output of our delta against
                          upstream janet.  Canonical patch record.
external/               — gitignored.  Where janet upstream is cloned.
scripts/                — build orchestration, cross-fleet wrappers.
tests/                  — smoke tests + native-module verification
                          (janet-lzo).
demos/                  — one runnable Janet program per release.
```

Two levels of git: this outer repo (the project) and
`external/janet/.git` (a working copy of upstream Janet on our
branch).  The outer repo is canonical; `external/janet/` is gitignored
and its value lands in `patches/` via `scripts/regen-patches.sh` (to
be added in session 001).

## Sessions workflow

**Read [`docs/sessions/README.md`](docs/sessions/README.md) before
starting work — that's the workflow you must follow.**  Start-of-
session checklist (including reading any HANDOFF.md from the prior
session), end-of-session ritual, and per-session-dir file conventions
all live there.

Substantive work lives in [`docs/sessions/`](docs/sessions/) — each
session is its own globally-numbered dir (`NNN-<short-slug>/`).
Borrowed from sister projects `llvm-7-darwin-ppc`, `lumo-darwin8-ppc`,
`ionpower-node`.

## Fleet hosts

- **uranium** — main dev Mac (this machine).  Edit, regen patches,
  cut releases, publish.
- **ibookg38** — Tiger G3 build host.  Native compilation runs here
  (gcc-4.9.4 + make-4.3 + ld64-97.17 via tigersh).  **384 MB RAM**,
  so watch swap on the bigger janet test suites.
- **ibookg37** — Tiger G3 test host.  Deliberately separate from the
  build host: verifies the tarball is genuinely standalone when
  installed on a fresh `/opt`.

Native build (not cross-build) is the default, matching the prior
leopard.sh recipe.  Cross-build remains a future option if iteration
speed becomes painful.

## Risk tolerance by host

- **uranium** — low.  `brew install`, source builds, standard package
  installs OK; random hobbyist binaries off the internet not OK.
- **PowerPC fleet** (ibookg37, ibookg38, etc.) — high.  These are
  reinstallable test machines.  tigersh/leopardsh packages, hobbyist
  Tiger/Leopard PPC builds, MacPorts/Fink/Debian patches as
  inspiration, in-place experimentation all fine.  The bar is "will
  this probably teach us something?" not "is this provably safe?"

## Document everything

Default to capturing liberally in the current session directory.
Plans, research, running work logs, decisions, dead ends, ambiguity
discussions, scope shifts, gotchas-in-the-moment — all worth writing
down.  Surface what you create briefly so the user has awareness.
Err on the side of MORE capture, not less.  The goal is that a
future-me (or a future Claude session) can pick up the thread without
re-explaining.

## Unsupervised mode

When the user says "work unsupervised" (or similar), they're
unreachable — at work, asleep — and cannot answer questions.  Under
this mode:

- **Don't stop to ask.**  Unblock yourself: make assumptions, run
  experiments, search the web for the problem or prior art, read
  related source, try the obvious fixes.
- **Long runtimes are fine.**  Eight or more hours of iteration is
  not too long if the task warrants it.
- **Only block for genuinely unreasonable actions.**  A workaround is
  almost always available.
- **Log every judgment call** in the active session's README — what
  was tried, what was rolled back, why.  That log is what the user
  reviews on return.

## Key invariants

1. **`patches/` is canonical.  `external/janet/.git` is working copy.**
   Always regen patches before committing the outer repo.  If they
   drift, trust `external/janet/` (someone's in-progress work lives
   there) and re-run regen.

2. **`external/janet/` is gitignored.**  Never commit it to the outer
   repo.  If it somehow gets added, `git rm -r --cached external/janet`
   and re-verify `.gitignore`.

3. **Patches should be upstreamable in shape.**  Even before we send
   them upstream, write them as if we were sending them tomorrow:
   small, well-motivated, no Tiger-specific paths hard-coded.  The
   Tiger build orchestration lives in `scripts/`, not in the patches.

4. **M1 = G3 only.**  G3-built tarballs run on G4/G5 anyway (PPC ISA
   is forward-compatible), so a single G3 build covers all PPC hosts
   for the first release.  G4 with AltiVec and G5/64-bit are M2/M3.

## Release distribution

Three places for every release:

1. **GitHub releases** — `gh release create vX.Y.Z ... <tarballs>`.
2. **`http://leopard.sh/misc/beta/`** — passwordless scp to
   `mini10v:/var/www/html/misc/beta/` (the source of truth; rsyncs
   to leopard.sh) AND `leopard.sh:/var/www/html/misc/beta/`
   directly (makes it visible immediately without waiting on the
   next rsync cycle).
3. The README's release table links to the GitHub release for the
   canonical URL.

## macports-legacy-support linking strategy

`@rpath` requires Leopard (LC_RPATH was added in 10.5).  We use
**`@loader_path/`** instead, which works on Tiger.  Layout:

```
/opt/janet-X.Y.Z/
├── bin/janet                                  (linked with
│                                               @loader_path/../lib/...)
├── lib/
│   ├── libjanet.dylib
│   └── libMacportsLegacySupport.dylib        (install_name =
│                                               @loader_path/...)
└── include/janet.h
```

`@loader_path` resolves to the directory of whatever binary is doing
the loading, so a runtime-loaded Janet native module (`.so` next to
`libMacportsLegacySupport.dylib` under `lib/janet/`) finds the dylib
without `@rpath` or `LC_RPATH`.

Two build modes:

- **Bundled** (default for our release): we build macports-legacy-
  support ourselves, install it into the per-arch staging prefix, and
  ship the dylib inside the Janet tarball.  Standalone install, no
  external dep at runtime.
- **BYO** (for leopard.sh, source builders, devs with macports-legacy-
  support already installed): build against an existing `/opt/
  macports-legacy-support-YYYYMMDD/` and skip the bundling step.
