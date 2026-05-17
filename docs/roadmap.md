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

8. **✅ BYO macports-legacy-support build mode.** *(session 007)*
   - `scripts/build-tiger.sh` learns `BYO_MACPORTS_LEGACY=1`
     (skip bundling + `install_name_tool` rewrite) and
     `RELEASE_REV=<rev>` (project-level revision marker for the
     tarball basename so we can cut releases at the same upstream
     SHA without filename collision).
   - BYO tarball verified on ibookg37 (lib loaded via absolute
     `/opt/macports-legacy-support-20221029/lib/libMacportsLegacySupport.dylib`
     install_name; no bundled copy in the tarball).

9. **✅ jpm install from git URL works.** *(session 007)*
   - `jpm install https://github.com/cellularmitosis/janet-lzo.git`
     on ibookg37 against a clean `/opt/janet-1.41.3-dev/` install.
   - Build chain (git fetch, gcc-4.9 compile + link, ar, cp) all
     rides on the `posix_spawn` fork+execve fallback.
   - `(import lzo) (lzo/decompress (lzo/compress …))` round-trips
     a 9 KB payload through the jpm-installed `lib/janet/lzo.so`.
   - Pass = posix_spawn fallback is solid AND `@loader_path`
     resolution from inside the freshly-built `.so` works.

10. **✅ Final M1 release.** *(session 007 — [v0.2.0](https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.2.0))*
    - Bundled tarball `janet-1.41.3-dev-r2-tiger-g3.tar.gz` and BYO
      tarball `janet-1.41.3-dev-r2-tiger-g3-byo.tar.gz` — both 1.7 MB,
      both attached to the GitHub release and mirrored at
      `http://leopard.sh/misc/beta/`.
    - Demo: [`demos/v0.2.0-jpm-install-lzo.{janet,sh}`](../demos/) —
      one-command pipeline (tigersh prereqs → curl tarball →
      bootstrap jpm with a Tiger-specific config → `jpm install
      janet-lzo` → `os/spawn` + lzo round-trip).  End-to-end
      verified on a wiped-clean ibookg37.
    - Upstream PR for the `posix_spawn` patches queued in
      [`deferred.md`](deferred.md) (independent timeline).

## M2 — G4 + AltiVec exploration *(✅ explored; no release artifact)*

Done in [session 009](sessions/009-m2-g4-altivec/).  Build
infrastructure now supports G3, G4, and G4+AltiVec via a single env
knob (`TIGER_ARCH={g3,g4,g4-altivec} scripts/build-tiger.sh`).
Empirical conclusion: non-invasive AltiVec at gcc-4.9 `-O2
-ftree-vectorize` gives essentially zero gain on Janet's standard
workload — the bytecode interpreter has no SIMD-shaped hot loop for
the auto-vectorizer to find.  No M2 release; v0.2.1's G3 tarball
remains the recommended download for G3/G4/G5 alike.

8. **✅ G4 build with `-mcpu=7450`.** *(session 009)*  Built on
   emac (1.42 GHz G4 eMac, Tiger 10.4.11).  Verified on emac,
   pbookg42 (Leopard G4), and mdd (Leopard G4 MDD, **no
   `/opt/macports-legacy-support-20221029` installed** — bundled
   `@loader_path` resolution does the lifting).  `bin/janet` is
   byte-different from the G3 build but coincidentally identical in
   size; `libjanet.dylib` grows by ~2 KB.  **Critically**: plain
   `-mcpu=7450` alone flips the Mach-O `cpu-subtype` to G4, so
   `dyld` on G3 prints `incompatible cpu-subtype` and refuses
   to load — better behavior than a mid-execution SIGILL.
   Tarball: `janet-1.41.3-dev-r3-tiger-g4.tar.gz` (1.75 MB).
   Released artifact: **none** — see point 9 for why.

9. **✅ AltiVec compiler flags (`-maltivec -mabi=altivec
   -ftree-vectorize`).** *(session 009)*  `-ftree-vectorize` added
   because gcc-4.9 at `-O2` doesn't auto-vectorize by default, so
   without it `-maltivec` would be a no-op vs plain `-mcpu=7450`.
   Benchmark on emac (5 runs each, best-of): **G3 baseline 3.288 s,
   G4 3.281 s (−0.2%), G4+AltiVec 3.283 s (−0.2%)** on a mixed
   fib/mandelbrot/peg/marshal workload.  Per-workload: mandelbrot
   −2.6% (FP gain from 7450 scheduling), fib +0.6%, peg +2.0%
   slower, marshal flat.  G4 vs G4+AltiVec indistinguishable
   (auto-vec finds essentially nothing in the interpreter).  **No
   release** — shipping a G4 / G4+AltiVec tarball at leopard.sh
   would advertise a no-op variant.  Build pipeline keeps the
   capability for anyone who wants it.

10. **❌ AltiVec source patches — won't do.** *(session 009)*
    Was conditional on M2's non-invasive AltiVec showing a clear
    win.  It didn't.  Hand-rolled intrinsics in Janet's VM would
    be speculative work targeting a scalar bytecode interpreter
    with no obvious SIMD-shaped hot loop.  Closing.

## M3 — G5 / 64-bit

11. **✅ G5 userland + native build verified, no workaround needed.**
    *(session 010)*  v0.2.1 G3 tarball runs unmodified on pmacg5
    (PowerMac G5 970, 2.3 GHz, Tiger 10.4.11) — full smoke
    including `os/spawn`, PEG, fibers, marshal, `int/s64`.  Native
    build pipeline also runs end-to-end on pmacg5 with
    `TIGER_HOST=pmacg5 scripts/build-tiger.sh`; the leopard.sh
    1.27.0-era "build/janet tools/patch-header.janet → Bus error"
    does not reproduce on our pinned SHA (1.41.3-dev) + toolchain
    (gcc-4.9.4 + ld64-97.17-tigerbrew).  G3-built and G5-built
    binaries are byte-identical (`bin/janet`, `libjanet.dylib`,
    `libMacportsLegacySupport.dylib`, `include/janet.h` all match
    bit-for-bit; `libjanet.a` differs only in `ar` archive
    timestamps).  No new release artifact this session — v0.2.1 G3
    tarball remains the canonical download for G3/G4/G5 alike.
    Bench on pmacg5: 1.701 s total best-of-5, **~1.93× faster
    than the 1.42 GHz G4** on the same workload, ~19% IPC win on
    top of the clock-speed ratio.  See
    [`sessions/010-m3-g5-bootstrap/`](sessions/010-m3-g5-bootstrap/).

12. **64-bit ppc64 build, with `JANET_NANBOX_64` enabled.**  Separate
    tarball: `janet-X.Y.Z-tiger-g5-ppc64.tar.gz`.  Scope expanded
    after the session-010 source dive
    ([`sessions/010-m3-g5-bootstrap/ppc64-value-representation.md`](sessions/010-m3-g5-bootstrap/ppc64-value-representation.md)):

    - **Toolchain plumbing.**  `-arch ppc64` propagated through
      Janet's build (`CFLAGS`/`LDFLAGS`, and decide what to do with
      `BOOT_CFLAGS` — bootstrap can stay 32-bit since it only runs
      on the build host).
    - **macports-legacy-support for ppc64.**  Build the dylib with
      `-arch ppc64`; bundle into the tarball under `@loader_path/`.
    - **`JANET_NANBOX_64` patch.**  Upstream's auto-detection at
      [`janet.h:313`](../external/janet/src/include/janet.h) lists
      `__x86_64__`/`_WIN64`/`__riscv`/`__aarch64__`/`_M_ARM64` but
      not `__PPC64__`.  Without intervention a ppc64 build falls
      back to the 8-byte split-payload `JANET_NANBOX_32` layout,
      forfeiting the single-register-per-value win.  Patch is ~5
      lines and is upstreamable in shape (same as our merged PRs).
      Verify the 47-bit-address-space invariant holds for Tiger
      ppc64 userland *first* — if it doesn't, fall back to the
      pointer-shift variant (`JANET_NANBOX_64_POINTER_SHIFT`) used
      by aarch64.
    - **Benchmark vs the ppc32 tarball on the same G5 hardware.**
      Same methodology as M2 / session 009.  Per the source dive,
      expect modest single-digit-% interpreter wins plus a real
      win on `int/s64`-heavy paths; no FP impact.  Ship the variant
      only if the gain is measurable (M2 settled the precedent
      that we don't ship no-op variants).

## Beyond M3

Anything not on the M1/M2/M3 critical path lives in
[`deferred.md`](deferred.md) — Leopard variants, the amalgamation
drop, upstream PR follow-ups, etc.  Pull items back into this
roadmap when they're scheduled for a specific milestone.
