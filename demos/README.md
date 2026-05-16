# demos/

One runnable Janet program per release, showcasing what that release
unlocked.  Pattern borrowed from sister projects
[`tcc-darwin8-ppc/demos/`](../../tcc-darwin8-ppc/demos/) and
[`ghc-darwin8-ppc/demos/`](../../ghc-darwin8-ppc/demos/).

Naming: `vX.Y.Z-<slug>.{janet,sh}`.  The `.sh` is a thin wrapper that
invokes `/opt/janet-<version>/bin/janet <slug>.janet` so the demo is
one-command runnable from a clone of this repo.

## v0.1.0 — pure-Janet REPL + native modules

- [`v0.1.0-hello.janet`](v0.1.0-hello.janet) — exercises PEG, fibers,
  `string/format`, and the LZO native module (if installed) against
  the v0.1.0 tarball.  Doubles as install-health smoke.
- [`v0.1.0-hello.sh`](v0.1.0-hello.sh) — wrapper that runs
  `/opt/janet-1.41.3-dev/bin/janet v0.1.0-hello.janet`.

Run it on a Tiger PPC box that has the v0.1.0 tarball installed:

```
sh demos/v0.1.0-hello.sh
```

The `(import lzo)` block is wrapped in a runtime `require` so the demo
runs cleanly whether or not janet-lzo's `lzo.so` is dropped under
`/opt/janet-1.41.3-dev/lib/janet/`.  With LZO present, step [4]
round-trips a 9 KB payload through `lzo/compress` and `lzo/decompress`;
without, step [4] prints a polite skip.

## v0.2.0 — `posix_spawn` fallback + `jpm install`

- [`v0.2.0-jpm-install-lzo.janet`](v0.2.0-jpm-install-lzo.janet) —
  two-step (os/spawn round-trip via `/bin/echo`, then lzo round-trip
  through the jpm-installed native module).
- [`v0.2.0-jpm-install-lzo.sh`](v0.2.0-jpm-install-lzo.sh) — full
  pipeline wrapper.  On a vanilla Tiger box with tigersh:
    1. tigersh-installs the prerequisites (gcc-libs-4.9.4,
       macports-legacy-support-20221029, gcc-4.9.4, make-4.3,
       ld64-97.17-tigerbrew, git-2.35.1, lzo-2.10).
    2. curls + unpacks `janet-1.41.3-dev-r2-tiger-g3.tar.gz` to
       `/opt/janet-1.41.3-dev/`.
    3. Bootstraps jpm into the janet tree with a Tiger-specific
       config baked into the script.
    4. `jpm install https://github.com/cellularmitosis/janet-lzo`.
    5. Runs the `.janet` script.

  Acceptance gate for M1.b: every subprocess call (git, gcc-4.9, ar,
  cp, …) inside jpm rides on the `posix_spawn` fork+execve fallback
  that landed in session 006.

  Run on a Tiger PPC box (one-command, idempotent):

  ```
  sh demos/v0.2.0-jpm-install-lzo.sh
  ```
