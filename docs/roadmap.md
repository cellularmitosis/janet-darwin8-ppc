# Roadmap

Prioritized forward work.  This file evolves as sessions land; the
fixed reference is [`docs/plan.md`](plan.md).

## M1 — G3 standalone build, native modules work

Two releases.  The first (M1.a) ships the pure-Janet REPL and
native-module loader.  The second (M1.b) adds `posix_spawn` so
`os/spawn` and `jpm install` work.  Splitting M1 this way means we
ship something usable as fast as possible without blocking on the
posix_spawn fallback, which is genuine engineering work and only
required for subprocess-using programs.

### M1.a — pure-Janet REPL + native modules (first release)

Each item is roughly one session.

1. **Session 001: bring-up & pin.**
   - Clone `janet-lang/janet`, pin to a specific master SHA.
   - Stand up `external/janet/` + `scripts/regen-patches.sh` +
     `scripts/fetch-janet.sh`.
   - First attempt: `make` upstream HEAD on ibookg38 against
     macports-legacy-support, see what breaks.  Capture errors in
     session notes.

2. **`scripts/build-tiger.sh` — bundled build mode only.**
   - Fetch janet at the pinned SHA, apply patches, configure
     CFLAGS / CPPFLAGS / LDFLAGS for macports-legacy-support, build.
   - Bundle `libMacportsLegacySupport.dylib` under `lib/` of the
     install prefix.
   - Emit `janet-X.Y.Z-tiger-g3.tar.gz`.
   - BYO mode deferred to M1.b.

3. **`install_name_tool` wiring — `@loader_path` everywhere.**
   - `bin/janet` references `@loader_path/../lib/...`.
   - `lib/libMacportsLegacySupport.dylib` install_name set to
     `@loader_path/libMacportsLegacySupport.dylib`.
   - Verify on a clean ibookg37 install that nothing dangles via
     `otool -L` audit.

4. **Janet's own test suite — minus `os/spawn`-dependent tests.**
   - The upstream `make test` battery, run on ibookg38, captured
     in the session's `build-logs/`.
   - Anything that depends on `os/spawn` is expected to fail at
     this stage; mark and skip those, address in M1.b.
   - Any *other* FAIL is a session-task.

5. **✅ janet-lzo precompiled smoke — validates the native-module
   loader without needing jpm install.** *(session 003)*
   - Built `lzo.so` on ibookg38 via
     [`scripts/build-janet-lzo-remote.sh`](../scripts/build-janet-lzo-remote.sh),
     applying jpm's canonical macOS recipe directly:
     `-fPIC -shared -undefined dynamic_lookup -lpthread` against
     `/opt/janet-1.41.3-dev/include/janet` and `/opt/lzo-2.10`.
   - Dropped into `/opt/janet-1.41.3-dev/lib/janet/lzo.so` on
     ibookg37 (clean Tiger G3).
   - `(import lzo) (lzo/decompress (lzo/compress @"hello"))`
     round-trips; 60 KB payload compresses to 0.5 % and round-trips
     byte-exact; marshal/unmarshal through lzo round-trips a
     nested struct.
   - Native-module loader + `@loader_path`-resolved bundled
     `libMacportsLegacySupport.dylib` proven against a clean host
     without `jpm install`.

6. **✅ First release.** *(session 005)*
   - Released as [v0.1.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0).
   - GitHub release with `janet-1.41.3-dev-tiger-g3.tar.gz` attached.
   - scp'd to `mini10v:/var/www/html/misc/beta/` (source of truth)
     and `leopard.sh:.../beta/` (direct, so the URL works
     immediately).
   - Outer-README "Try it out!" curl one-liner past the (Sketch)
     stub.  Releases-table row added.  Implementation-status flipped
     from `✅ M1.a (local)` → `✅ M1.a`.
   - Public-URL install sanity-checked on ibookg37 (curl from
     `http://leopard.sh/misc/beta/...`, demo all green, lzo round-
     trip when `lzo.so` dropped in).
   - ✅ Demo: [`demos/v0.1.0-hello.{janet,sh}`](../demos/) —
     four-step (PEG / fiber / `string/format` / optional LZO
     round-trip), verified on ibookg37 (with `lzo.so`) and
     ibookg38 (without).  Session 004.

### M1.b — `posix_spawn` fallback + jpm install (final M1 release)

7. **✅ `posix_spawn` fallback.** *(session 006)*
   - Patches 0002 / 0003 / 0004 — `JANET_NO_POSIX_SPAWN` gate +
     fork + (dup2 / chdir) + execve fallback with a CLOEXEC pipe
     for exec-failure propagation + auto-detection on pre-Leopard
     Apple.  Old `JANET_NO_PROCESSES` stub patches dropped.
   - Validation: `suite-os.janet` 57/58 on ibookg38 (the 1
     failure is `os/realpath` semantics, not spawn — see
     [`deferred.md`](deferred.md)).  Uranium's full `make test`
     battery still passes with `JANET_NO_POSIX_SPAWN` forced, so
     the posix_spawn-default path is unregressed.
   - Upstream PR is queued; see [`deferred.md`](deferred.md).

8. **BYO macports-legacy-support build mode.**
   - `scripts/build-tiger.sh` learns `BYO_MACPORTS_LEGACY=1`.
   - For developers and leopard.sh integration with macports-legacy-
     support already installed at `/opt/macports-legacy-support-*/`.
   - Skips the bundling + install_name_tool dylib steps; just
     references the existing install.

9. **jpm install from git URL works.**
   - `jpm install https://github.com/cellularmitosis/janet-lzo` on
     ibookg37 against a clean `/opt/janet-X.Y.Z/` install.
   - Build chain inside jpm runs (gcc, make, …).
   - Pass = posix_spawn fallback is solid AND `@loader_path`
     resolution from inside the freshly-built `.so` works.

10. **Final M1 release.**
    - Tarball with the `posix_spawn` fallback baked in.
    - BYO mode documented in `BUILDING.md` or similar.
    - Demo: `demos/vX.Y.Z-lzo-jpm-install.sh` — full
      curl→install→`jpm install`→lzo round-trip on a vanilla Tiger
      box.
    - Upstream PR for the `posix_spawn` patch as a separate track
      (its own timeline; we don't gate releases on upstream review).

## M2 — G4 + AltiVec exploration

8. **G4 build with `-mcpu=7450`.**  Non-invasive — just a different
   tigersh recipe path.  Probably trivial.  Tarball:
   `janet-X.Y.Z-tiger-g4.tar.gz`.

9. **AltiVec compiler flags (`-maltivec -mabi=altivec`).**  Compile
   and benchmark vs the G3 build on G4 hardware.  Document gains.

10. **AltiVec source patches (if measurement justifies).**  Likely
    candidates: hot loops in `src/core/{vm,corelib,marsh}.c`,
    memcpy/bzero in the GC.  Out of scope if non-invasive AltiVec
    gives most of the win.

## M3 — G5 / 64-bit

11. **G5 bootstrap workaround.**  The leopard.sh 1.27.0 recipe died
    at `build/janet tools/patch-header.janet ... → Bus error` on G5.
    Strategy: build a bootstrap janet on G3, scp it to G5, use it as
    the host janet during the G5 build (sidesteps the bug).  Root-
    cause if cheap; ship the workaround if not.

12. **64-bit ppc64 build.**  Separate tarball:
    `janet-X.Y.Z-tiger-g5-ppc64.tar.gz`.

## Beyond M3

Anything not on the M1/M2/M3 critical path lives in
[`deferred.md`](deferred.md) — Leopard variants, the amalgamation
drop, upstream PR follow-ups, etc.  Pull items back into this
roadmap when they're scheduled for a specific milestone.
