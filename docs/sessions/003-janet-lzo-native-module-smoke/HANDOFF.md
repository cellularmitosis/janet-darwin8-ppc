# HANDOFF — session 003 → 004

## Where things stand

Session 003 closed the **M1.a native-module loader gate**.
`janet-lzo`'s `lzo.so` builds on ibookg38 via
[`scripts/build-janet-lzo-remote.sh`](../../../scripts/build-janet-lzo-remote.sh)
(jpm's canonical macOS link recipe applied directly) and round-trips
on ibookg37 from both `JANET_PATH` and the canonical
`/opt/janet-1.41.3-dev/lib/janet/` syspath.

M1.a's engineering is fully done.  All that's left of M1.a is
**distribution + paperwork**:

1. GitHub release of `releases/janet-1.41.3-dev-tiger-g3.tar.gz`.
2. scp to `mini10v:/var/www/html/misc/beta/`.
3. scp to `leopard.sh:/var/www/html/misc/beta/`.
4. Outer-README "Try it out!" past the "_(Sketch)_" stub.
5. Releases-table entry pointing at the GitHub release.
6. `demos/v0.1.0-hello.{janet,sh}` — small Janet demo per roadmap.

Then M1.b proper (the real `posix_spawn` fallback) — bigger work,
likely its own session.

## Suggested first moves for session 004

Three flavors; pick whichever has appetite.

### A. M1.a release distribution (15-30 min)

Same shape as session 002's HANDOFF section A.  The native-module
gate is now green, so the matrix update is unambiguous (M1.a row →
✅ across the board for native-module + REPL + standalone install;
🟡 only on the `os/spawn` row).

The "visible-to-others" actions (GitHub release, scp to leopard.sh,
scp to mini10v) need user confirmation per CLAUDE.md — surface for
sign-off before executing.

Version: stick with `1.41.3-dev` per session 002's
recommendation; matches `(print janet/version)` verbatim.

### B. `demos/v0.1.0-hello.{janet,sh}` (~30 min)

Roadmap M1.a item 6.  Small standalone demo that exercises:

- the REPL (`janet -e`)
- a non-trivial piece of Janet (a PEG, a fiber, something with
  `string/format`)
- ideally the native module too (`(import lzo)`), to make the demo
  *also* serve as smoke evidence the install is healthy
- `.sh` wrapper that calls `/opt/janet-1.41.3-dev/bin/janet
  demos/v0.1.0-hello.janet` so the demo is one-command runnable

Land it alongside the release.

### C. M1.b — `posix_spawn` fork+execve fallback

The big M1.b item per roadmap.  Same shape as session 002's
HANDOFF section C — read the leopard.sh 1.27.0 sketch
(`https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh`),
re-implement `os/spawn` / `os/execute` / `os/shell` via
`fork()` + `execve()` + pipes, validate against
`test/suite-os.janet` (currently failing because `os/execute` is
stubbed).  Probably 1–2 sessions of focused work.

## Gotchas not to re-step on

- **Tiger `mktemp` doesn't accept naked `-d`.**  Always pass a
  template: `mktemp -d -t prefix.XXXXXX`.
- **The CA bundle path the `imacg3-dev` skill cites
  (`/Users/macuser/tmp/cacert-2026-03-19.pem`) doesn't exist on
  ibookg38.**  Use `/opt/tigersh-deps-0.1/share/cacert.pem`
  instead, or one of the `/opt/ca-certificates-*/share/cacert.pem`
  installs.
- **No git on ibookg38.**  Use the tigersh-deps `curl` to pull
  GitHub release/branch tarballs.
- **Native modules don't link `-ljanet`.**  Use `-undefined
  dynamic_lookup`; janet's C-API symbols resolve at `dlopen()` time
  from the host process.  Linking against `libjanet.dylib` would
  double-instantiate janet's globals.
- **`/opt` is admin-writable; don't reach for `sudo`** when
  installing into `/opt/<owned-by-macuser>/`.  Plain `cp` works.
  Also: `ssh imacg3 'sudo ...'` is *not* viable because there's no
  tty for the password prompt over a non-interactive ssh — but you
  shouldn't need it anyway.
- **`bin/janet` is statically linked against the core.**  Native
  modules dlopen into it, not into a shared libjanet.  This is why
  `-undefined dynamic_lookup` is the right link shape and why
  bin/janet's `otool -L` has no libjanet entry.

## Starting prompt for session 004

```
Starting session 004.  Read docs/sessions/003-janet-lzo-native-
module-smoke/HANDOFF.md and README.md.  Session 003 closed the M1.a
native-module loader gate; janet-lzo's lzo.so builds on ibookg38
via scripts/build-janet-lzo-remote.sh and round-trips on ibookg37
from both JANET_PATH and the canonical /opt/janet-1.41.3-dev/lib/
janet/ syspath.

All that's left of M1.a is distribution + paperwork: GitHub
release, scp to leopard.sh + mini10v, README "Try it out" past the
"(Sketch)" stub, demo script.  HANDOFF section A walks through it.
Demo is section B.  M1.b (the real posix_spawn fallback) is
section C — bigger work.

Pick the section.  If unsupervised, default to section A (M1.a
distribution).
```
