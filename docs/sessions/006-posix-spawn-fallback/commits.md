# Commits — session 006

Outer repo (`janet-darwin8-ppc`):

- `d2dc3d8` — `session 006: posix_spawn fork+execve fallback`
  - `patches/` reshuffled: old 0002 / 0003 (`JANET_NO_PROCESSES`
    stub) dropped, new 0002 / 0003 / 0004 ship the fallback +
    Tiger auto-detection.  Old 0004 (Makefile CPPFLAGS) renumbers
    to 0005.
  - `docs/sessions/006-posix-spawn-fallback/{README.md,
    HANDOFF.md, build-logs/}`
  - `docs/roadmap.md` flips item 7 from pending to ✅.

Inner working copy (`external/janet/`, captured in `patches/`):

- `ee93b660` — features.h: skip _POSIX_C_SOURCE / _XOPEN_SOURCE on
  pre-Leopard macOS  *(unchanged from session 001, re-applied)*
- `c601c315` — os.c: gate `<spawn.h>` include behind
  `JANET_NO_POSIX_SPAWN`  *(revised from session 002)*
- `b126d683` — os.c: fork+execve fallback for systems without
  posix_spawn  *(NEW — the substantive M1.b commit)*
- `7b550d0a` — features.h: auto-define `JANET_NO_POSIX_SPAWN` on
  pre-Leopard Apple  *(revised from session 002)*
- `61ecb2da` — Makefile: honor CPPFLAGS in both boot and final
  compile phases  *(unchanged from session 002, renumbered)*

The SHAs above are pre-fetch-janet.sh re-application; after the
next `scripts/fetch-janet.sh` run they'll be different (timestamps
in committer fields drift on re-apply).  `patches/` is the
canonical record.
