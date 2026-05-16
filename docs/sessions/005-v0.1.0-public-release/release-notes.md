# janet-darwin8-ppc v0.1.0

**First M1.a release** of [Janet](https://github.com/janet-lang/janet)
for Mac OS X 10.4 Tiger / PowerPC.

Tarball: `janet-1.41.3-dev-tiger-g3.tar.gz` (1.7 MB).

## Try it out

On any G3, G4, or G5 Mac running Tiger:

```
sudo mkdir -p /opt
sudo chmod ugo+rwx /opt
cd /opt
# Prerequisites (installed by tigersh, see leopard.sh):
#   gcc-libs-4.9.4, macports-legacy-support-20221029
curl http://leopard.sh/misc/beta/janet-1.41.3-dev-tiger-g3.tar.gz | gunzip | tar x
/opt/janet-1.41.3-dev/bin/janet -e '(print "hello from janet on tiger ppc")'
```

For a richer four-step smoke (PEG / fiber / `string/format` /
optional LZO round-trip), grab
[`demos/v0.1.0-hello.{janet,sh}`](https://github.com/cellularmitosis/janet-darwin8-ppc/tree/main/demos)
from the repo.

## What works

- **Pure-Janet REPL** — `janet`, `janet -e`, `janet script.janet`.
- **Native-module loader** — verified with
  [janet-lzo](https://github.com/cellularmitosis/janet-lzo)'s `lzo.so`
  (session 003) and the demo's runtime `(require "lzo")` path
  (session 004).
- **29 of 30 of Janet's own test suites pass.**  The one failure is
  `suite-os.janet` panicking on the deliberately-stubbed
  `os/execute` — expected at this stage.

## What's missing (M1.b)

- `os/spawn`, `os/execute`, `os/shell`, `os/posix-fork`,
  `os/posix-exec` are absent under `JANET_NO_PROCESSES`.  Tiger has
  no `<spawn.h>` and macports-legacy-support doesn't backfill it.
  The `posix_spawn` fork+execve fallback is M1.b — debugging the
  leopard.sh 1.27.0 sketch to working state is the next chunk of
  engineering.
- `jpm install` from a git URL depends on the above and lands with
  M1.b too.

## Layout

```
/opt/janet-1.41.3-dev/
├── bin/{janet, jpm, janet-format}
├── lib/
│   ├── libjanet.1.41.3-dev.dylib  (install_name = @loader_path/…)
│   └── libMacportsLegacySupport.dylib  (bundled, @loader_path/…)
└── include/janet.h
```

`@loader_path/` install names (not `@rpath/` — LC_RPATH was added in
10.5).  A runtime-loaded native module in
`lib/janet/*.so` resolves the bundled dylib via its own
`@loader_path/../`.

## Build / verify

- Build host: ibookg38 (Tiger G3, gcc-4.9.4 via
  [tigersh](https://leopard.sh/tigersh/)).
- Test host: ibookg37 (clean Tiger G3 — no compiler, no source,
  proves the tarball is genuinely standalone).
- Upstream Janet pinned to a specific master SHA; portability delta
  lives in [`patches/`](https://github.com/cellularmitosis/janet-darwin8-ppc/tree/main/patches)
  (four small patches, intended for upstream).

Build script: [`scripts/build-tiger.sh`](https://github.com/cellularmitosis/janet-darwin8-ppc/blob/main/scripts/build-tiger.sh).
Session logs: [`docs/sessions/`](https://github.com/cellularmitosis/janet-darwin8-ppc/tree/main/docs/sessions).
