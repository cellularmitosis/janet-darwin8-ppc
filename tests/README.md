# tests/

Smoke tests and native-module verification for the built tarball.
Separate from Janet's own upstream test suite (which we run via
`make test` in `external/janet/` during the build).

Empty for now; populated as M1 progresses.

## Planned tests

### Core smokes — does the binary actually run?

- `hello.janet` — `(print "hello from janet on tiger ppc")`.
- `arithmetic.janet` — sanity-check ints, floats, bignums.
- `os-arch.janet` — verify `(os/arch)` returns `:ppc`.

### `os/spawn` regression — the `posix_spawn` fallback

- `spawn-basic.janet` — `(os/spawn ["/bin/echo" "hi"])`, check exit
  and stdout.
- `spawn-pipes.janet` — pipe in, pipe out, pipe err, check the
  buffers.
- `spawn-exit-codes.janet` — non-zero exits, signals.

If the `fork()`+`execve()` fallback is right, these pass.  If
not, they segfault or hang.

### Native module gate — the M1 acceptance test

- `janet-lzo-roundtrip.sh` — installs janet-lzo via `jpm install
  https://github.com/cellularmitosis/janet-lzo` against a freshly-
  installed `/opt/janet-X.Y.Z/` on **ibookg37** (separate from
  build host), then runs:

  ```
  janet -e '(import lzo) \
            (def x @"the quick brown fox jumps over the lazy dog") \
            (def c (lzo/compress x)) \
            (def d (lzo/decompress c)) \
            (assert (= (string x) (string d)) "lzo round-trip failed")'
  ```

  Pass = native modules load and the `@loader_path` wiring resolves
  `libMacportsLegacySupport.dylib` from inside the loaded `.so`.
  This is the gate for shipping M1.

## How tests are run

`scripts/smoke-tiger.sh` (planned) runs the smokes after install on
ibookg37.  Each test captures stdout, stderr, exit code; failures go
into the session's `build-logs/`.

A green run is required before tagging a release.
