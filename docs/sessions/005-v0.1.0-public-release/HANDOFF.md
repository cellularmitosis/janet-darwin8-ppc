# HANDOFF — session 005 → 006

## Where things stand

M1.a is publicly released as
[v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0).
Tarball mirrored at
`http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz`,
README "Try it out!" past the (Sketch) stub, releases table and
implementation-status flips landed in session 005.  Fresh-install
sanity check on ibookg37 (curl from the public URL) — all four demo
steps green including the LZO round-trip when `lzo.so` is dropped in.

All ten M1.a roadmap items are now ✅.

## Suggested first move for session 006: M1.b — `posix_spawn` fallback

This is the substantive engineering work of the project, parked
since session 002 stubbed it out via `JANET_NO_PROCESSES`.  Tiger
ships no `<spawn.h>` and macports-legacy-support doesn't backfill
it; the leopard.sh 1.27.0 recipe carried a sketch of a
`fork()`+`execve()` fallback that was never debugged to working
state.

Starting points:

- **The leopard.sh sketch.**  `https://leopard.sh/tigersh/scripts/
  install-janet-1.27.0.sh` — inline patch, somewhere in the recipe.
  Treat as a reference, not a drop-in; the project has moved from
  1.27.0 → 1.41.3-dev so APIs and code paths around `os/spawn` may
  have drifted.
- **`external/janet/src/core/os.c`.**  The Janet side of `os/spawn`,
  `os/execute`, `os/shell`.  Currently behind `#ifndef
  JANET_NO_PROCESSES` (our patch 0004 from session 002).  Reverting
  that gate is roughly the prerequisite — we want the code back in
  the build, then we make it compile and run on Tiger.
- **`<spawn.h>` consumers in `os.c`.**  `posix_spawn`,
  `posix_spawn_file_actions_*`, `posix_spawnattr_*` are the calls
  to replace with a `fork()` + `dup2()` + `execve()` synthesis.
- **Validation surface.**  `external/janet/test/suite-os.janet` —
  currently failing because `os/execute` is stubbed.  When it
  passes clean on ibookg38 we know the fallback is correct.

Land the result as `patches/000N-posix-spawn-fallback.patch`.  Patch
0004 (the `JANET_NO_PROCESSES` stub) gets dropped once the fallback
works — it was always a placeholder, not an upstreamable change.

Sequence within session 006:

1. Stand up a working branch in `external/janet/` from the pinned
   SHA.  Revert patch 0004 (`#define JANET_NO_PROCESSES`).
2. `make` on ibookg38 — see what breaks.  Expectation: missing
   `<spawn.h>`, undefined `posix_spawn*` symbols.
3. Pull the leopard.sh 1.27.0 sketch in.  Rebase against 1.41.3-dev
   `os.c` — the touch points may have moved.
4. Make it compile, then make `suite-os.janet` pass.  Both gates.
5. Regen patches; verify the bundle is still upstreamable in shape
   (no Tiger-specific paths hard-coded).

Probably 1–2 sessions on its own.  M1.b's other items — BYO
macports-legacy-support build mode, `jpm install` from git URL,
demo + release — chain off this one.

## M1.a paperwork that's still queued (low priority)

- **Upstream PR for the four M1.a patches.**  Patches 0001–0003 are
  Tiger-portability fixes that should land in upstream Janet on
  their own merits.  Each is small and well-motivated; the work is
  in writing the PR descriptions and walking them through review.
  Out of scope until M1.b ships and we have a final patch bundle
  worth submitting together.
- **`scripts/regen-patches.sh` audit.**  Not run since session 002;
  worth a quick spot-check before session 006 starts touching
  `external/janet/` again, to confirm `patches/` reflects what's
  actually in the working copy.

Neither blocks M1.b.

## Gotchas not to re-step on

- **The release tarball reports `(print janet/version)` =
  `1.41.3-dev` (no `-local` suffix).**  If a future session sees
  `1.41.3-dev-local` on a test host, that's a local rebuild leaking
  in from session-003-era experiments, not the released artifact.
  Either rebuild fresh from the public URL or compare sha256 against
  `ba1c32b3af07c7fd5a2b168b55f9749473ec09bd8fddcb567dd71b895a54394b`.

- **Reaching the leopard.sh / mini10v mirrors uses bare ssh
  aliases** (`scp foo leopard.sh:...`), no special config.  Both
  hosts accept passwordless scp from uranium; the user's ssh config
  has the aliases.  If they break, talk to the user — don't try to
  reverse-engineer the auth.

- **All session-004 gotchas still apply** (import-vs-require for
  optional native modules, `lzo/compress` wants a buffer, PEG needs
  explicit `<-` captures), plus session-003's (Tiger `mktemp`
  template, CA bundle path on tigersh, native modules link
  `-undefined dynamic_lookup`, `/opt` is admin-writable).

## Starting prompt for session 006

```
Starting session 006.  Read docs/sessions/005-v0.1.0-public-release/
HANDOFF.md and README.md.  M1.a v0.1.0 is publicly released —
GitHub release, mirrored at leopard.sh/misc/beta/, README updated,
fresh-install sanity check on ibookg37 passed.  All M1.a roadmap
items 1–6 are ✅.

Next up: M1.b — the posix_spawn fork+execve fallback.  The project's
substantive engineering work, parked since session 002 stubbed it
out via JANET_NO_PROCESSES.  Probably 1–2 sessions on its own.
HANDOFF section "Suggested first move" sketches the sequence: revert
patch 0004, see what breaks, pull in the leopard.sh 1.27.0 sketch
as a reference, rebase against 1.41.3-dev os.c, make `make test`'s
suite-os.janet pass.

If unsupervised, proceed with section "Suggested first move" — it's
the only critical-path work left in M1.
```
