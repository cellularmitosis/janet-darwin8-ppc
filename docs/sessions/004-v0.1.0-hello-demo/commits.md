# commits — session 004

Outer-repo commits landed this session, oldest-first.

- [`9541093`](https://github.com/cellularmitosis/janet-darwin8-ppc/commit/9541093) — session 004: v0.1.0-hello demo
  - `demos/v0.1.0-hello.janet` — four-step demo (peg/match, fiber,
    string/format, optional lzo round-trip).  Uses runtime `require`
    for lzo so the demo degrades cleanly when `lzo.so` is absent.
  - `demos/v0.1.0-hello.sh` — thin POSIX-sh wrapper that locates the
    `.janet` next to itself and execs `/opt/janet-1.41.3-dev/bin/janet`.
  - `demos/README.md` — replaces the placeholder sketch with the
    actual v0.1.0 entry; notes the `import`-vs-`require` fallback
    so future demos in the same shape don't re-step on snag 1.
  - `docs/sessions/004-v0.1.0-hello-demo/` — session write-up:
    - `README.md` — narrative (arrival → exit).
    - `HANDOFF.md` — session-005 primer.
    - `commits.md` — this file.
    - `build-logs/demo-ibookg37-with-lzo.log` — demo output on
      clean Tiger G3 with `lzo.so` installed.
    - `build-logs/demo-ibookg38-no-lzo.log` — demo output on
      build host without `lzo.so` (verifies skip path).
    - `build-logs/wrapper-ibookg37.log` — end-to-end run via the
      `.sh` wrapper on ibookg37.

No changes to `external/janet/` this session — pure additive
demos work, no upstream-relevant patches.  Patches 0001–0004 from
session 002 remain the canonical delta.
