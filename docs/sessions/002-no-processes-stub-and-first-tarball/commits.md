# Session 002 commits

## In `external/janet/` (janet fork, darwin-ppc branch)

- `66d03e3b` — `os.c: gate <spawn.h> include behind JANET_NO_PROCESSES`
- `d2acfcbe` — `features.h: auto-define JANET_NO_PROCESSES on pre-Leopard Apple`
- `51e4dc76` — `Makefile: honor CPPFLAGS in both boot and final compile phases`

Captured as:
- [`patches/0002-os.c-gate-spawn.h-include-behind-JANET_NO_PROCESSES.patch`](../../../patches/0002-os.c-gate-spawn.h-include-behind-JANET_NO_PROCESSES.patch)
- [`patches/0003-features.h-auto-define-JANET_NO_PROCESSES-on-pre-Leo.patch`](../../../patches/0003-features.h-auto-define-JANET_NO_PROCESSES-on-pre-Leo.patch)
- [`patches/0004-Makefile-honor-CPPFLAGS-in-both-boot-and-final-compi.patch`](../../../patches/0004-Makefile-honor-CPPFLAGS-in-both-boot-and-final-compi.patch)

## In outer repo

To be committed at session end:

- session 002: NO_PROCESSES stub patches, build-tiger.sh, first
  M1.a tarball verified on ibookg37.
