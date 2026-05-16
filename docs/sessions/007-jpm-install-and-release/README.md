# Session 007 — jpm install end-to-end + M1.b release

## Arrival state

[Session 006](../006-posix-spawn-fallback/) shipped the `posix_spawn`
fork+execve fallback as patches 0002 / 0003 / 0004.  `suite-os.janet`
runs 57/58 on ibookg38 (the one failure is `os/realpath` semantics,
not spawn).  Uranium's full `make test` battery still passes with
`JANET_NO_POSIX_SPAWN` forced, so the posix_spawn-default path is
unregressed.  All M1.b roadmap items 1–7 are ✅.

What was deferred: the *external* validation of the fallback.  It
passes the test suite — but jpm's real-world `os/execute` pattern
(git, gcc, ar, cp chained together) is the honest gate.  Plus the
remaining mechanical pieces: BYO macports-legacy-support build mode
and the M1.b public release.

This session lands roadmap items 8 / 9 / 10 — the rest of M1.b.

## What happened

### Item 9 first — the fallback's real-world gate

Per session 006's HANDOFF, item 9 (`jpm install` from a git URL) is
the only one of the three that could plausibly fail.  Items 8 and 10
are mechanical.  So this session ran them in 9 → 8 → 10 order rather
than the roadmap's lexical order, to surface any showstopper early.

**Arrival check.**  ibookg37 still had the M1.a v0.1.0 tarball
installed.  `os/spawn` panics as expected: `unknown symbol os/spawn`.
Moved that out of the way to `/opt/janet-1.41.3-dev.v0.1.0` and
installed the session 006 dev tarball — which carries the fallback —
in its place.  Smoke: `(os/spawn ["/bin/echo" "hello-from-spawn"] :px)`
returns a `<core/process>`.  Fallback alive on the target host.

**Toolchain.**  `git` was the missing piece.  `tiger.sh git-2.35.1`
on ibookg37 (one minute).  `gcc-4.9.4`, `make-4.3`, `lzo-2.10`,
`macports-legacy-support-20221029` were already there from prior
sessions.

**jpm bootstrap.**  jpm doesn't ship with janet — it's a separate
project (`janet-lang/jpm`), bootstrapped via
`janet bootstrap.janet [config]`.  The default macOS config it
auto-generates assumes `cc = /usr/bin/cc` which on Tiger is Apple's
ancient gcc 4.0 (no TLS, no C99 in places janet needs).  Wrote a
Tiger-specific config that pins `:cc` / `:c++` to `gcc-4.9`, threads
`-I/opt/macports-legacy-support-20221029/include/LegacySupport`
into `:cflags`, and points `:prefix` / `:headerpath` / `:modpath` at
the janet install tree (`/opt/janet-1.41.3-dev/`) so jpm and modules
co-locate with janet.  Same config (with substituted paths) gets
embedded into [`demos/v0.2.0-jpm-install-lzo.sh`](../../../demos/v0.2.0-jpm-install-lzo.sh)
so other users don't have to rediscover it.

Bootstrap ran clean — every step (`mkdir`, `cp`, `chmod +x`,
recursive `janet jpm/cli.janet install`) is an `os/execute` /
`os/spawn` call.

**`jpm install janet-lzo` (item 9).**  Single command, captured at
[`build-logs/ibookg37-jpm-install-lzo.log`](build-logs/ibookg37-jpm-install-lzo.log):

```
$ jpm install https://github.com/cellularmitosis/janet-lzo.git
```

Exercised (every line is a `posix_spawn` fallback call):

- `git init`, `git remote add`, `git fetch --tags`, `git fetch HEAD`,
  `git reset --hard`, `git submodule update --init --recursive`
- `gcc-4.9 -c lzo.c -DJANET_BUILD_TYPE=release … -fPIC -o build/lzo.o`
- `gcc-4.9 … -o build/lzo.so build/lzo.o -L/opt/macports-legacy-support-20221029/lib -llzo2 -lMacportsLegacySupport -shared -undefined dynamic_lookup -lpthread`
- `gcc-4.9 -c lzo.c -DJANET_ENTRY_NAME=janet_module_entry_lzo … -o build/lzo.static.o`
- `ar rcs build/lzo.a build/lzo.static.o`
- `git remote get-url origin`, `git rev-parse HEAD`
- `cp -rf build/lzo.so /opt/janet-1.41.3-dev/lib/janet/` (and meta /
  static-archive counterparts)

Verification round-trip:

```
$ janet -e '(import lzo) ...'
raw=57 comp=61 back=57 match=true
text=hello jpm install on tiger ppc with the os/spawn fallback
```

The lzo paths went via `CPATH=/opt/lzo-2.10/include
LIBRARY_PATH=/opt/lzo-2.10/lib` rather than baking those into the
jpm config — gcc honors both as silent `-I` / `-L` additions, and
they're project-specific (other jpm packages won't want them).

Item 9 ✅ — fallback survives real-world subprocess pipelines, not
just the test-suite-friendly ones.

### Item 8 — BYO macports-legacy-support build mode

Two changes to the build orchestration:

- [`scripts/build-tiger.sh`](../../../scripts/build-tiger.sh) learns
  two new env knobs:
  - `BYO_MACPORTS_LEGACY=1` — skip bundling the legacy-support
    dylib + skip the `install_name_tool` rewrite.  Tarball name gets
    a `-byo` suffix.
  - `RELEASE_REV=<rev>` — append a project-level revision marker
    (e.g. `r2`) to the tarball basename, since we're cutting v0.2.0
    at the same upstream `1.41.3-dev` SHA as v0.1.0 and need
    distinct artifact names on the CDN.
- [`scripts/build-tiger-remote.sh`](../../../scripts/build-tiger-remote.sh)
  honors `BYO_MACPORTS_LEGACY`.  Bundled / BYO branches share the
  libjanet self-id step (so native modules find libjanet via
  `@loader_path` either way) and diverge on whether to bundle +
  rewrite the legacy-support reference.

BYO build verified by:

1. `BYO_MACPORTS_LEGACY=1 scripts/build-tiger.sh` on ibookg38 →
   [`build-logs/ibookg38-byo-build.log`](build-logs/ibookg38-byo-build.log).
   `otool -L` confirms `bin/janet` references the legacy-support
   dylib via its absolute install_name
   (`/opt/macports-legacy-support-20221029/lib/libMacportsLegacySupport.dylib`)
   and the tarball does NOT contain a bundled copy.
2. scp'd to ibookg37, unpacked under `/tmp/byo-test/`, ran
   `os/spawn` smoke against `/bin/echo` → green.  ibookg37 has
   `/opt/macports-legacy-support-20221029/` installed, so the
   absolute dylib reference resolves.

Item 8 ✅.

### Item 10 — v0.2.0 release

Two tarballs:

- `janet-1.41.3-dev-r2-tiger-g3.tar.gz` (1.7 MB, bundled)
- `janet-1.41.3-dev-r2-tiger-g3-byo.tar.gz` (1.6 MB, BYO)

The `-r2` suffix comes from `RELEASE_REV=r2` and exists because
upstream still reports `janet/version` = `1.41.3-dev` (no upstream
bump between v0.1.0 and v0.2.0).  Without the suffix, the bundled
tarball name would collide with v0.1.0's on the CDN.

Build logs:
[bundled](build-logs/ibookg38-bundled-r2-build.log),
[BYO](build-logs/ibookg38-byo-r2-build.log).

Published to:

- GitHub release [v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0)
  with both tarballs attached.
- `mini10v:/var/www/html/misc/beta/` (source of truth that rsyncs
  to leopard.sh).
- `leopard.sh:/var/www/html/misc/beta/` directly (so the URL works
  immediately without waiting on the rsync cycle).

**Demo: [`demos/v0.2.0-jpm-install-lzo.{janet,sh}`](../../../demos/).**
One-command pipeline.  On a vanilla Tiger box with tigersh, the `.sh`:

1. `tiger.sh`-installs the prerequisites
   (gcc-libs-4.9.4, macports-legacy-support-20221029, gcc-4.9.4,
   make-4.3, ld64-97.17-tigerbrew, git-2.35.1, lzo-2.10).
2. Curls + unpacks `janet-1.41.3-dev-r2-tiger-g3.tar.gz` from
   `http://leopard.sh/misc/beta/` under `/opt`.
3. Clones jpm, bootstraps with the embedded Tiger config (and the
   janet install prefix substituted in).
4. `jpm install https://github.com/cellularmitosis/janet-lzo.git`
   (with `CPATH=/opt/lzo-2.10/include LIBRARY_PATH=/opt/lzo-2.10/lib`
   in the wrapper's env so gcc finds the lzo dep).
5. Runs the `.janet`, which does an `os/spawn` round-trip (proves
   the fallback) and an lzo round-trip through the jpm-installed
   module (proves the whole pipeline end-to-end).

End-to-end run on ibookg37 (wiped to a clean state — no janet, no
jpm — then `bash /tmp/v0.2.0-jpm-install-lzo.sh`):
[`build-logs/ibookg37-demo-clean-run.log`](build-logs/ibookg37-demo-clean-run.log).
Last few lines:

```
=== run v0.2.0-jpm-install-lzo.janet ===

=== janet-darwin8-ppc v0.2.0 jpm-install — Janet 1.41.3-dev on macos/ppc ===

[1] os/spawn captured stdout="hello-from-os/spawn"  exit=0
[2] lzo (via jpm install): 9000 -> 108 bytes (ratio 0.0120), round-trip ok=true

ok.
```

Item 10 ✅.

### Outer README

Status section flipped from "M1.a released, M1.b pending" to
"M1.b released (v0.2.0)".  Releases table got a v0.2.0 row.
Implementation-status rows for `os/spawn`, `jpm install`, and BYO
macports-legacy-support all flipped to ✅ M1.b.

## Exit state

M1 (G3) complete.  v0.2.0 is the recommended download.  Both
bundled and BYO tarballs published to GitHub releases and
`leopard.sh/misc/beta/`.  The demo gate works on a clean Tiger box.

Remaining work:

- **Upstream PR for the `posix_spawn` patch series.**  Queued in
  [`docs/deferred.md`](../../deferred.md); independent timeline,
  doesn't gate anything.
- **M2.** G4 + AltiVec exploration.  Roadmap items 11–13.
- **M3.** G5 / 64-bit.  Roadmap items 14–15 (G5 bootstrap workaround
  for the `tools/patch-header.janet` Bus error + ppc64 build).

The two Tiger-specific test failures spotted in session 006
(`os/realpath` on nonexistent paths, `suite-filewatch.janet`
EVFILT_VNODE mapping) remain parked in
[`docs/deferred.md`](../../deferred.md) — neither blocks anything
M1.b-related.

Next: see [HANDOFF.md](HANDOFF.md) if you want to pick up M2 (or
file the upstream PR); otherwise the project is at a natural
stopping point.
