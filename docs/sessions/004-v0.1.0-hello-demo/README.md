# Session 004 — v0.1.0-hello demo

## Arrival state

Session 003 closed the M1.a native-module loader gate.  `janet-lzo`'s
`lzo.so` builds on ibookg38 via
[`scripts/build-janet-lzo-remote.sh`](../../../scripts/build-janet-lzo-remote.sh)
and round-trips on ibookg37 from both `JANET_PATH` and the canonical
`/opt/janet-1.41.3-dev/lib/janet/` syspath.  M1.a's engineering is
done; what remains is distribution + paperwork:

1. GitHub release of `janet-1.41.3-dev-tiger-g3.tar.gz`.
2. scp to `mini10v:/var/www/html/misc/beta/` + `leopard.sh:.../beta/`.
3. Outer-README "Try it out!" past the _(Sketch)_ stub.
4. **`demos/v0.1.0-hello.{janet,sh}`** — roadmap M1.a item 6.

This session does (4).  The release distribution (1–3) stays
queued for session 005.

## What happened

### Goal

The HANDOFF's suggested shape: a small standalone demo that
exercises the REPL, a non-trivial piece of Janet, and ideally the
LZO native module too — so the demo doubles as install-health smoke.
Plus a `.sh` wrapper so it's one-command runnable.

### The .janet program

[`demos/v0.1.0-hello.janet`](../../../demos/v0.1.0-hello.janet)
runs four labeled steps:

1. **PEG** — splits `janet/version` (e.g. `"1.41.3-dev"`) into the
   semver triple and the optional pre-release tag, with explicit
   `(<- ...)` captures.  Exercises `peg/match` and the built-in
   PEG VM.
2. **Fiber** — a lazy fibonacci generator built with `fiber/new`,
   `yield`, and `resume`.  Drained with `(seq [_ :range [0 12]]
   (resume f))` for fib(0..11) = `@[0 1 1 2 3 5 8 13 21 34 55 89]`.
3. **`string/format`** — `%.5f` / `%x` / `%6d|` to exercise the
   formatter without needing any external lib.
4. **LZO native module** — compresses a 9 KB repetitive payload
   (200× "the quick brown fox jumps over the lazy dog. ") to 108
   bytes (ratio 0.012) and round-trips it.  When `lzo.so` is
   absent, prints a polite skip.

### Two snags during drafting

Both worth recording for future Janet work on Tiger.

**Snag 1 — `import` is compile-time, not runtime.**  Initial draft
wrapped `(import lzo)` in a `try` so the demo would degrade
gracefully on installs without `lzo.so`.  That fails:

```
/tmp/v0.1.0-hello.janet:60:21: compile error: unknown symbol lzo/compress
```

`(import lzo)` is a macro that calls `require` at macroexpansion
time and synthesizes `lzo/compress`, `lzo/decompress`, etc. as
compile-time bindings.  The `try`'s catch never runs because the
*compiler* sees `lzo/compress` as an unresolved symbol before any
code executes.

Fix: bypass the macro.  `require` is a plain function; it returns
the module's env table (`@{(symbol "compress") @{:value <cfun> ...}
...}`).  Look up the cfunctions at runtime via
`(get-in mod [(symbol "compress") :value])`.  Wrap the `require`
call itself in a `try`; the rest of the lzo block reads cleanly:

```janet
(def lzo-mod (try (require "lzo") ([_err] nil)))
(if lzo-mod
  (let [compress (get-in lzo-mod [(symbol "compress") :value])
        ...]
    ...)
  (print "[4] lzo: skipped (module not found)"))
```

**Snag 2 — `lzo/compress` wants a buffer, not a string.**  Plain
`(lzo/compress "...")` panics with `expected buffer, got string`.
Session 003's smoke used the `@"..."` buffer-literal form
(`(lzo/compress @"hello")`).  For a `string/repeat`-built payload,
coerce with `(buffer (string/repeat ...))`.  Worth fixing in
janet-lzo upstream too — accepting either buffer or string is a
two-line change to `lzo.c`.  Deferred (it's a janet-lzo concern,
not a janet-darwin8-ppc concern).

### The .sh wrapper

[`demos/v0.1.0-hello.sh`](../../../demos/v0.1.0-hello.sh) — thin
POSIX-sh wrapper.  Locates the `.janet` next to itself via
`$(cd $(dirname "$0") && pwd)`, then `exec`s
`/opt/janet-1.41.3-dev/bin/janet <script>`.  If `/opt/janet-1.41.3-dev/bin/janet`
is missing it prints the curl-install one-liner.

### Verification

Run on **ibookg37** (clean Tiger G3, has lzo.so installed under
`/opt/janet-1.41.3-dev/lib/janet/` from session 003) — all four
steps green, lzo round-trip ok=true.  Full output:
[`build-logs/demo-ibookg37-with-lzo.log`](build-logs/demo-ibookg37-with-lzo.log)
and the wrapper end-to-end variant
[`build-logs/wrapper-ibookg37.log`](build-logs/wrapper-ibookg37.log).

Run on **ibookg38** (build host, has Janet installed but no
lzo.so) — steps [1]-[3] green, step [4] prints the skip line and
the demo still exits cleanly:
[`build-logs/demo-ibookg38-no-lzo.log`](build-logs/demo-ibookg38-no-lzo.log).

That confirms both code paths (lzo present, lzo absent) are clean,
which matters because the v0.1.0 tarball ships without lzo.so —
LZO is a separately-installed third-party module.

### demos/README.md update

[`demos/README.md`](../../../demos/README.md) had a placeholder
sketch ("Empty for now.  The first demo will ship with v0.1.0:
…").  Replaced with the actual v0.1.0 entry pointing at both files,
plus a one-paragraph description of the `import`-vs-`require`
fallback so future demos in the same shape don't re-step on snag 1.

The original sketch had v0.1.0 as *two* demos:
`v0.1.0-hello.janet` (bare hello) and `v0.1.0-lzo.sh` (full curl-
install + lzo round-trip).  This session collapses them: one demo
that's both the install-smoke and the language-feature showcase.
The `v0.1.0-lzo.sh` curl-install variant — the M1 acceptance-gate
demo — would be more natural as a v0.1.1 (M1.b) demo since the
"clean Tiger box → working `jpm install janet-lzo`" pipeline needs
`os/spawn` to land first.

## Exit state

`demos/v0.1.0-hello.{janet,sh}` lands.  Verified on both ibookg37
(with lzo) and ibookg38 (without lzo).  M1.a roadmap item 6 is
**partially done**: the `demos/v0.1.0-hello.{janet,sh}` artifact
ships; the GitHub release + scp parts of item 6 stay queued.

What's still M1.a-but-optional:

- GitHub release + scp to leopard.sh + mini10v.
- Outer-README "Try it out!" updated past the _(Sketch)_ stub.
- Releases-table row pointing at the GitHub release.

See [HANDOFF.md](HANDOFF.md) for the session-005 primer.
