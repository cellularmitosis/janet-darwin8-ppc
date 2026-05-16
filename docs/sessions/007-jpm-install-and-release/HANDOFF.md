# HANDOFF — session 007 → 008 (or wherever you want to start)

## Where things stand

**M1 (G3) is done.**  v0.2.0 is published with the `posix_spawn`
fork+execve fallback proven via `jpm install`-of-janet-lzo on a
clean Tiger box.  Both bundled and BYO tarballs are on GitHub and
on `http://leopard.sh/misc/beta/`.  The demo
(`demos/v0.2.0-jpm-install-lzo.sh`) reproduces the full pipeline
end-to-end.

The project has hit its first natural stopping point.  Pick from:

## Suggested next moves

**A. Upstream PR for the `posix_spawn` patches.**  Out-of-band,
doesn't gate anything else.  Patches 0002 + 0003 + 0004 are
upstreamable in shape (small, well-motivated, no Tiger-specific
paths in the C).  The PR description writes itself from
[`docs/sessions/006-posix-spawn-fallback/README.md`](../006-posix-spawn-fallback/README.md).
Similar in shape to PR #432 (`O_CLOEXEC` fallback) and PR #436
(`arc4random_buf` fallback) — both merged.  Probably an hour of
prose-polishing + a `git format-patch --base` rebase against
current upstream master.

**B. M2 — G4 + AltiVec exploration.**  Roadmap items 11–13.  The
non-invasive parts (`-mcpu=7450`, then `-maltivec -mabi=altivec`)
are basically `scripts/build-tiger.sh` variants — probably one
session to land both as additional tarballs
(`janet-X.Y.Z-r2-tiger-g4.tar.gz`,
`janet-X.Y.Z-r2-tiger-g4-altivec.tar.gz`).  Benchmark comparison
against the G3 build is the interesting part.  AltiVec source
patches (item 13) are only worth doing if compiler-flag AltiVec
doesn't get most of the win.

**C. M3 — G5 / 64-bit.**  Roadmap items 14–15.  The G5 bootstrap
workaround is non-trivial: 1.27.0's recipe died at
`tools/patch-header.janet → Bus error` on G5.  The "build a
bootstrap janet on G3, scp it to G5, use it as the host janet
during the G5 build" sidestep is the recommended starting point.
Root-causing the Bus error is more interesting but probably more
work.

**D. Tiger-specific test failures in `deferred.md`.**  Two parked
items from session 006:

- `os/realpath errors when path does not exist` in `test/suite-os.janet:195`
  — macports-legacy-support's `realpath` shim returns success on
  nonexistent paths.  Either fix in macports-legacy-support or
  guard the test on Tiger.
- `suite-filewatch.janet` reports 17/23 on Tiger — `EVFILT_VNODE`
  flag mapping looks wrong.  Real bug, plausibly in
  `src/core/filewatch.c`; needs a closer look at Tiger's kqueue
  flags vs the upstream-targeted version.

Both are upstreamable in shape.  Neither blocks anything M1-related.

## Gotchas not to re-step on

- **All session 003–006 gotchas still apply.**  `fetch-janet.sh`
  is destructive to local commits in `external/janet/`; `pid_t pid`
  needs an init under `-Wmaybe-uninitialized`; `os/realpath` on
  Tiger doesn't error on missing paths; `suite-filewatch.janet`
  is 17/23 on Tiger; native modules link with `-undefined dynamic_lookup`;
  the `1.41.3-dev` vs `1.41.3-dev-local` vs `1.41.3-dev-r2` string
  distinction.

- **`RELEASE_REV` only affects the tarball basename.**  It does
  NOT propagate into `PREFIX` (`/opt/janet-${JANET_VERSION}`) or
  into the binary's `janet/version` (since both should match what
  upstream's `janetconf.h` reports).  Two janet builds at the
  same upstream SHA with different `RELEASE_REV` values install
  to the same prefix and report the same version — they're
  fungible as `/opt` contents, distinguishable only by the source
  tarball name.

- **The default jpm `bootstrap.janet` won't work on Tiger.**  It
  auto-generates a macos config that pins `cc = /usr/bin/cc`
  (Apple's gcc 4.0) which janet's `_Thread_local` blocks on.  The
  Tiger config baked into [`demos/v0.2.0-jpm-install-lzo.sh`](../../../demos/v0.2.0-jpm-install-lzo.sh)
  is the working recipe — start from that for any future jpm
  package on Tiger.

- **`jpm install`'s gcc invocation honors `CPATH` / `LIBRARY_PATH`
  as silent `-I` / `-L` additions.**  Use these for project-
  specific deps (lzo, openssl, …) rather than baking the paths
  into the global jpm config.  The demo wrapper sets
  `CPATH=/opt/lzo-2.10/include LIBRARY_PATH=/opt/lzo-2.10/lib`
  before calling `jpm install`.

- **Publishing to leopard.sh: scp to BOTH `mini10v` (source of
  truth, rsyncs to leopard.sh) AND `leopard.sh` directly
  (makes the URL live immediately).**  The README's curl one-
  liner points at `http://leopard.sh/misc/beta/...` and breaks
  for fresh installers if only mini10v has the new tarball and
  the rsync hasn't fired yet.

- **`/opt` on the test fleet (ibookg37, ibookg38) is
  admin-writable, no sudo needed.**  v0.1.0's demo wrapper
  matched that; v0.2.0's earlier draft had `sudo mkdir -p /opt`
  which prompted for a password on ibookg37 and broke the
  unattended demo run.  Fixed to: check `/opt` writable, advise
  the user to set it up once if not.

## Starting prompt for session 008 (or whichever)

```
Starting session 008.  Read docs/sessions/007-jpm-install-and-release/
HANDOFF.md and README.md.

M1 (G3) is done as of v0.2.0 — `os/spawn`, `jpm install` from git
URL, bundled + BYO tarballs all working on real Tiger PPC.  Project
is at a natural stopping point.

Pick one:
  A. Upstream PR for the posix_spawn patches (out-of-band, easy)
  B. M2 — G4 + AltiVec
  C. M3 — G5 / ppc64
  D. Tiger-specific test failures parked in docs/deferred.md

Each has its own writeup in HANDOFF.md "Suggested next moves".
```
