# HANDOFF — session 006 → 007

## Where things stand

M1.b's hardest piece — the `posix_spawn` fork+execve fallback — is
done.  Patches 0002 / 0003 / 0004 (revised + new) bring
`os/execute`, `os/spawn`, `os/shell`, and friends back into the
Tiger build.  `suite-os.janet` reports 57 of 58 tests passing on
ibookg38 (the one failure is `os/realpath` semantics, not spawn).
Uranium's full `make test` battery still passes with
`JANET_NO_POSIX_SPAWN` forced, so the posix_spawn-default path is
unregressed.

Old patches 0002 / 0003 (the `JANET_NO_PROCESSES` stub) — dropped.

## Suggested first move for session 007

Roadmap items 8 + 9 + 10 — finish M1.b.

**Item 8: BYO macports-legacy-support build mode.**  Probably
small.  `scripts/build-tiger.sh` learns `BYO_MACPORTS_LEGACY=1`
(or the variable name of choice); when set, it skips the bundling
+ install_name rewriting steps in `build-tiger-remote.sh` and
trusts a pre-existing `/opt/macports-legacy-support-*/` on the
build host.  This is what leopard.sh / source-builder hosts need.

**Item 9: `jpm install` from a git URL.**  This is the real proof
that M1.b's fallback works end-to-end.  Target: install
`https://github.com/cellularmitosis/janet-lzo` on a clean ibookg37
against a fresh `/opt/janet-X.Y.Z/`.  `jpm install` shells out to
`git clone`, `gcc`, and friends — every step rides on
`os/execute`.  Pass = our fallback is honest about the corner
cases, not just the test-suite-friendly ones.

**Item 10: M1.b release.**  Cut a v0.2.0 (or whatever the version
ends up being — see "Version bump" gotcha below).  Tarball with
the fallback baked in.  Demo: `demos/v0.2.0-jpm-install.{janet,sh}`
that does the full curl→tar→`jpm install`→lzo round-trip on
vanilla Tiger.  Upstream PR for the patch bundle goes here too as
a separate track.

Roadmap item 9 is the main event.  8 and 10 are mechanical once 9
works.

## Gotchas not to re-step on

- **`fetch-janet.sh` is destructive to local commits.**
  `scripts/build-tiger.sh` calls `scripts/fetch-janet.sh` first
  thing, which does `git checkout pinned-sha && git switch -C
  darwin-ppc && git am patches/*`.  That blows away any local
  amendments / fixups in `external/janet/` that aren't yet in
  `patches/`.  This session lost a one-line warning fix this way
  on the first iteration — squashed the fixup, *then* ran
  build-tiger.sh without regenerating `patches/` first, and
  fetch-janet.sh reset the working copy to the pre-fixup state on
  disk.  Rule: **`regen-patches.sh` before
  `build-tiger.sh`, every time.**  Or make build-tiger.sh's
  fetch-janet.sh call optional — also fine.

- **`pid_t pid` needs an init under `-Wmaybe-uninitialized`.**
  gcc-4.9 can't prove that the pre-fork error branches (pipe /
  fcntl / fork failure) panic before `proc->pid = pid` is read.
  Initializing `pid = -1` silences the warning.  Don't drop it.

- **`os/realpath` on a nonexistent path doesn't error on Tiger.**
  `test/suite-os.janet:195`.  macports-legacy-support's realpath
  shim succeeds on `"abc123def456"` and synthesizes a path,
  whereas glibc / modern Darwin error.  Unrelated to spawn.  Park
  in `docs/deferred.md`; only worth chasing if a downstream user
  hits it.

- **`suite-filewatch.janet` reports 17/23 on Tiger.**
  `EVFILT_VNODE` flag mapping looks wrong — `:attrib` shows up
  where `:write` is expected, and there are extra spurious
  events.  Probably needs a Tiger-specific tweak in
  `src/core/filewatch.c` or a "skip on Tiger" gate in the test.
  Also unrelated to spawn; park.

- **Local `releases/janet-1.41.3-dev-tiger-g3.tar.gz` is now a
  development build with the spawn fallback baked in.**  The
  *published* v0.1.0 tarball at
  `http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz`
  and on the GitHub release is still the M1.a artifact.
  Filename collision because upstream hasn't bumped past
  `1.41.3-dev` and we follow upstream.  M1.b's release will need
  a fresh filename (most likely a tarball-name bump to e.g.
  `janet-1.41.3-dev-r2-tiger-g3.tar.gz`, or wait for upstream
  1.41.4 / 2.0.0).

- **All session 003–005 gotchas still apply.**  Import-vs-require
  for optional native modules, `lzo/compress` wants a buffer, PEG
  needs explicit `<-` captures, Tiger `mktemp` template, CA bundle
  path on tigersh, native modules link `-undefined dynamic_lookup`,
  `/opt` is admin-writable, leopard.sh / mini10v reachable via
  bare ssh aliases, the `1.41.3-dev` vs `1.41.3-dev-local` version
  string distinction.

## Starting prompt for session 007

```
Starting session 007.  Read docs/sessions/006-posix-spawn-fallback/
HANDOFF.md and README.md.  M1.b's hard part is done — the
posix_spawn fork+execve fallback lands in patches 0002/0003/0004,
suite-os.janet is 57/58 on ibookg38 (the 1 failure is os/realpath,
not spawn).

Next up: roadmap items 8 + 9 + 10 — BYO macports-legacy-support
build mode, `jpm install` from a git URL on a clean Tiger box,
and the M1.b release.  Item 9 is the real end-to-end gate for the
fallback; 8 and 10 chain off it.  HANDOFF section "Suggested first
move" sketches the sequence.

If unsupervised, proceed with item 9 first since it validates the
fallback against jpm's real `os/execute` patterns (git, gcc,
make) — then 8 (small wrapper change), then 10 (release).
```
