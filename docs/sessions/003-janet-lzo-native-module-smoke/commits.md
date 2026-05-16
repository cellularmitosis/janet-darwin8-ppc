# commits — session 003

Outer-repo commits landed this session, oldest-first.

- `TBD` — session 003: janet-lzo native-module smoke
  - `scripts/build-janet-lzo-remote.sh` — canonical recipe for
    building a Janet native module against this project's tarball
    on a Tiger PPC host.  Implements jpm's macOS link defaults
    directly (`-fPIC -shared -undefined dynamic_lookup -lpthread`).
  - `README.md` — native-module row flips to ✅ M1.a; points at
    `scripts/build-janet-lzo-remote.sh`.
  - `docs/roadmap.md` — M1.a item 5 marked done with session-003
    pointer and a recap of what was validated.
  - `docs/sessions/003-janet-lzo-native-module-smoke/` — session
    write-up:
    - `README.md` — narrative (arrival → exit).
    - `findings.md` — jpm darwin recipe, syspath baking, Tiger
      mktemp gotcha, CA bundle path on ibookg38, gcc-4.9.4 vs
      gcc-libs-4.9.4 on ibookg37, no-git-on-ibookg38, /opt admin-
      writable.
    - `HANDOFF.md` — session-004 primer.
    - `lzo.so` — the built module (10,480 bytes), kept as a
      reference artifact.
    - `build-logs/build-lzo-ibookg38.log` — build-host output.
    - `build-logs/round-trip-ibookg37.log` — clean-host round-trip
      output (both `JANET_PATH` and canonical-syspath tests).

No changes to `external/janet/` this session — no Janet-source
patches were needed for the native-module smoke.  Patches 0001–0004
from session 002 remain the canonical delta.
