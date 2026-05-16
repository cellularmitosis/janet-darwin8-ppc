# HANDOFF — session 004 → 005

## Where things stand

Session 004 landed [`demos/v0.1.0-hello.{janet,sh}`](../../../demos/) —
a four-step Janet demo (PEG, fiber, `string/format`, optional LZO
round-trip) plus a thin POSIX-sh wrapper.  Verified on ibookg37
(with `lzo.so`) and ibookg38 (without).  M1.a's last load-bearing
deliverable beyond the tarball itself is now in tree.

All that's left of M1.a is **public distribution**:

1. GitHub release of [`releases/janet-1.41.3-dev-tiger-g3.tar.gz`](../../../releases/).
2. scp to `mini10v:/var/www/html/misc/beta/` (the source of truth;
   rsyncs to leopard.sh).
3. scp to `leopard.sh:/var/www/html/misc/beta/` directly (so the
   tarball is visible without waiting for the next rsync cycle).
4. Outer-[README.md](../../../README.md) "Try it out!" past the
   _(Sketch)_ stub.
5. Releases-table row pointing at the GitHub release.
6. Implementation-status table — the "Standalone tarball" row can
   flip from "✅ M1.a (local)" to "✅ M1.a".

Then **M1.b proper** (the `posix_spawn` fork+execve fallback) —
genuine engineering, probably 1–2 sessions on its own.

## Suggested first moves for session 005

### A. M1.a release distribution (15–30 min)

The "visible-to-others" actions (GitHub release, scp to leopard.sh,
scp to mini10v) need user confirmation per
[`CLAUDE.md`](../../../CLAUDE.md) — surface for sign-off before
executing.  The local prep (README edits, releases-table row,
implementation-status flip) can be done first and confirmed in the
same commit.

Sanity-check before the GitHub release: the curl one-liner in the
new README "Try it out!" should be cut-and-pasteable into a fresh
Tiger box.  Test path: install on ibookg37 a *second* time from the
about-to-be-published URL, not from the local
`releases/...tar.gz` — proves the public artifact is what we think
it is.

Version tag: stick with `1.41.3-dev` per session 002's
recommendation; matches `(print janet/version)` verbatim.  Release
tag could be `v0.1.0` (our project's first release) — these are
orthogonal.

### B. M1.b — `posix_spawn` fork+execve fallback

The big M1.b item per [roadmap](../../roadmap.md).  Same shape as
session 003's HANDOFF section C — start from the leopard.sh 1.27.0
sketch (`https://leopard.sh/tigersh/scripts/install-janet-1.27.0.sh`),
re-implement `os/spawn` / `os/execute` / `os/shell` via `fork()` +
`execve()` + pipes, validate against `test/suite-os.janet`
(currently failing because `os/execute` is stubbed).

Independent of A; could run before, after, or in parallel with the
release.  No coupling — A ships the M1.a tarball as-is.

## Gotchas not to re-step on

- **`(import lzo)` is compile-time, not runtime.**  Wrapping it in
  `try` to handle a missing module won't work because `import` is a
  macro that resolves `lzo/compress` etc. at macroexpansion.  Use
  the runtime `require` function instead and look up bindings via
  `(get-in mod [(symbol "compress") :value])`.  See session 004
  README snag 1 for the full pattern.

- **`lzo/compress` panics on string input.**  Wants a buffer; coerce
  via `(buffer ...)` or use a `@"..."` buffer literal.  janet-lzo's
  `lzo.c` could accept either with a two-line change — worth
  upstreaming separately, but out of scope here.

- **PEG patterns need explicit captures.**  A grammar that *matches*
  the input but has no `(<- ...)` capture forms returns `@[]`, not
  the matched text.  Add `(<- :rule)` around each piece you want
  back.

- **All session-003 gotchas still apply:** Tiger `mktemp` needs a
  template, no `git` on ibookg38, CA bundle at
  `/opt/tigersh-deps-0.1/share/cacert.pem` (not the imacg3 path),
  native modules link with `-undefined dynamic_lookup` (no
  `-ljanet`), `/opt` is admin-writable so no `sudo` needed.

## Starting prompt for session 005

```
Starting session 005.  Read docs/sessions/004-v0.1.0-hello-demo/
HANDOFF.md and README.md.  Session 004 landed demos/v0.1.0-hello.
{janet,sh} — the M1.a demo with PEG / fiber / string-format / LZO
round-trip, verified on ibookg37 (with lzo) and ibookg38 (without).

All that's left of M1.a is public distribution: GitHub release,
scp to leopard.sh + mini10v, outer-README "Try it out!" past the
"(Sketch)" stub, releases-table row, implementation-status flip.
HANDOFF section A walks through it.  Section B is M1.b
(posix_spawn fallback) — bigger work, can run independently.

Pick the section.  If unsupervised, default to section A (M1.a
distribution); surface the visible-to-others steps (gh release,
scp) for sign-off before executing.
```
