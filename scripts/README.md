# scripts/

Build orchestration, cross-fleet wrappers, release tooling.  Empty
skeleton for now — scripts get added as sessions need them.

Planned set (will fill in during M1):

- `fetch-janet.sh` — clone `janet-lang/janet` into
  `../external/janet/`, check out the pinned SHA, apply patches.
- `regen-patches.sh` — regenerate `../patches/` from
  `../external/janet/`'s working branch.
- `build-tiger.sh` — main native build script.  Runs on the Tiger
  build host (ibookg38).  Configures CPPFLAGS / LDFLAGS for
  macports-legacy-support, builds janet, runs `install_name_tool`
  for `@loader_path` wiring, produces a tarball.
  - `BYO_MACPORTS_LEGACY=1` env var → use existing
    `/opt/macports-legacy-support-*` instead of bundling.
- `smoke-tiger.sh` — install the tarball into a scratch prefix on
  ibookg37, run the smoke tests in `../tests/`, including the
  janet-lzo native-module round-trip.
- `upload-release.sh` — `gh release create` + scp to
  `mini10v:/var/www/html/misc/beta/` (source of truth, rsyncs to
  leopard.sh) and `leopard.sh:/var/www/html/misc/beta/` (immediate
  visibility).

All scripts should be invocable from the repo root with relative
paths, e.g. `scripts/build-tiger.sh`.
