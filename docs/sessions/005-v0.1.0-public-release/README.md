# Session 005 — v0.1.0 public release

## Arrival state

Session 004 landed [`demos/v0.1.0-hello.{janet,sh}`](../../../demos/) —
the four-step PEG / fiber / `string/format` / optional-LZO demo,
verified on ibookg37 (with `lzo.so`) and ibookg38 (without).  All of
M1.a's engineering was done; only public distribution remained:
GitHub release of [`releases/janet-1.41.3-dev-tiger-g3.tar.gz`](../../../releases/),
scp to `mini10v:/var/www/html/misc/beta/` and `leopard.sh:.../beta/`,
README "Try it out!" past the _(Sketch)_ stub, releases-table row,
implementation-status flip from `✅ M1.a (local)` to `✅ M1.a`.

## What happened

Section A from the session-004 [HANDOFF](../004-v0.1.0-hello-demo/HANDOFF.md)
— M1.a public distribution.  All five external/local changes landed,
verified by a fresh-install smoke from the public URL.

### Local prep

Outer-[README.md](../../../README.md) edits:

- Status section: `M1.a built and verified locally` →
  `M1.a released (v0.1.0)`, with a link to the GitHub release and a
  reference to the `leopard.sh/misc/beta/` mirror URL.
- "Try it out!" — `_(Sketch — public release pending session 003.)_`
  stub removed; the curl one-liner is now a real install path
  (always was bytewise, but the stub said otherwise).  Added a
  pointer to [`demos/v0.1.0-hello.{janet,sh}`](../../../demos/) as a
  richer smoke.
- Releases table — placeholder row replaced with a v0.1.0 row
  linking to the GitHub release tag.
- Build-matrix row for G3: `🟡 M1.a built` → `🟡 M1.a released`.
- Linking & install row for the standalone tarball: `✅ M1.a (local)` →
  `✅ M1.a`, with the GitHub release link.

[Release notes](release-notes.md) drafted separately for the GitHub
release — distilled from the README's "Status" section + the build
layout + the M1.b "what's missing" caveats, plus the curl one-liner
and a demos pointer.

### External actions (user-confirmed before executing)

1. **scp to `mini10v:/var/www/html/misc/beta/`** — the source-of-
   truth mirror that rsyncs to leopard.sh.
2. **scp to `leopard.sh:/var/www/html/misc/beta/`** — direct, so the
   tarball is visible without waiting for the next rsync cycle.
3. **`gh release create v0.1.0`** on `cellularmitosis/janet-darwin8-ppc`,
   tarball attached, release notes from `release-notes.md` — landed
   at https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0.

Sha256 of the tarball, identical at all three locations (local,
mini10v, leopard.sh):

```
ba1c32b3af07c7fd5a2b168b55f9749473ec09bd8fddcb567dd71b895a54394b
```

### Public-URL sanity check

Per the session-004 HANDOFF: install on ibookg37 *from the just-
published URL*, not from the local `releases/...tar.gz`, to prove
the public artifact is what we think it is.

The existing install at `/opt/janet-1.41.3-dev/` on ibookg37 (from
session 003, has `lzo.so` under `lib/janet/`) was renamed to
`/opt/janet-1.41.3-dev.bak.005/`.  Then the README's curl one-liner
ran verbatim:

```
ssh ibookg37 'cd /opt &&
  curl -fsSL http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz \
    | gunzip | tar x &&
  /opt/janet-1.41.3-dev/bin/janet -e "(print \"hello from janet on tiger ppc\")"'
```

→ `hello from janet on tiger ppc`.  `janet/version` reports
`1.41.3-dev`.  `otool -L bin/janet` shows
`@loader_path/../lib/libMacportsLegacySupport.dylib`, confirming the
LC_RPATH-free install-name strategy ships in the released artifact.

Demo run on the fresh install: all four steps green, LZO step
politely skips with "module not found".  Copied `lzo.so` over from
the backed-up install and re-ran the demo — all four steps green
including the LZO 9000→108 byte round-trip.  Then restored the
prior install by `rm -rf /opt/janet-1.41.3-dev && mv .bak.005
/opt/janet-1.41.3-dev`.

Full session log: [`build-logs/public-install-ibookg37.log`](build-logs/public-install-ibookg37.log).

### Note on the `-dev` vs `-dev-local` version string

The fresh public-URL install reports `(print janet/version)` =
`1.41.3-dev` (matches the upstream `JANET_VERSION` in `Makefile`).
The pre-existing install on ibookg37 reported `1.41.3-dev-local` —
that was a local rebuild done during session 003's lzo work
(probably picked up some `-DJANET_VERSION_SUFFIX=local` or similar
flag from a make recompile, not the released tarball).  No action
needed; flagged here so future sessions don't confuse the two.

## Exit state

M1.a is publicly released and verified:

- GitHub release [v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0).
- Mirrored at `http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz`
  (curl URL in the README's "Try it out!") and on the mini10v
  source-of-truth host.
- README's status section, "Try it out!", releases table, and two
  implementation-status rows reflect the release.

M1.a as a milestone is **done**.  All ten roadmap items 1–6 (M1.a
slice) are now ✅.  The remaining M1 work is M1.b — the
`posix_spawn` fork+execve fallback — which session 003's HANDOFF
section C originally sketched; the HANDOFF for session 006 carries
that forward as the natural next pickup.
