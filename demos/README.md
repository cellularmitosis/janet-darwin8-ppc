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

## Future demos

Planned for v0.1.1 (M1.b — `posix_spawn` fallback lands):

- `vX.Y.Z-lzo-jpm-install.sh` — curl + tarball-install + `jpm install
  https://github.com/cellularmitosis/janet-lzo` end-to-end on a vanilla
  Tiger box.  The acceptance-gate demo for M1.b.
