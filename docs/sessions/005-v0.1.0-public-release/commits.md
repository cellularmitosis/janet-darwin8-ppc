# commits — session 005

Outer-repo commits landed this session, oldest-first.

- [`73444b4`](https://github.com/cellularmitosis/janet-darwin8-ppc/commit/73444b4) — session 005: v0.1.0 public release
  - `README.md`:
    - Status section: M1.a flipped from "built and verified locally"
      to "released" with v0.1.0 GitHub release link and mention of
      the `leopard.sh/misc/beta/` mirror.
    - "Try it out!" — stripped the `_(Sketch — public release
      pending session 003.)_` stub.  Curl one-liner unchanged in
      shape (was already correct).  Added a pointer to the
      `demos/v0.1.0-hello.{janet,sh}` smoke.
    - Build-matrix row for G3: `M1.a built, M1.b pending` →
      `M1.a released, M1.b pending`.
    - Linking & install row for the standalone tarball:
      `✅ M1.a (local)` → `✅ M1.a` with the GitHub release link.
    - Releases table: placeholder row replaced with v0.1.0 row
      linking to the release tag.
  - `docs/roadmap.md`: M1.a item 6 flipped to ✅, with the per-bullet
    distribution-channel breakdown filled in.
  - `docs/sessions/005-v0.1.0-public-release/`:
    - `README.md` — narrative (arrival → exit).
    - `HANDOFF.md` — session-006 primer.  Next pickup is M1.b: the
      `posix_spawn` fork+execve fallback.
    - `release-notes.md` — body of the GitHub release.
    - `commits.md` — this file.
    - `build-logs/public-install-ibookg37.log` — curl-install on
      ibookg37 from the leopard.sh mirror URL, demo runs (with and
      without lzo.so).

External actions landed this session (not part of any commit):

- scp `releases/janet-1.41.3-dev-tiger-g3.tar.gz` →
  `mini10v:/var/www/html/misc/beta/`.
- scp same → `leopard.sh:/var/www/html/misc/beta/`.
- `gh release create v0.1.0 --repo cellularmitosis/janet-darwin8-ppc`,
  tarball attached, notes from `release-notes.md`.
  https://github.com/cellularmitosis/janet-darwin8-ppc/releases/tag/v0.1.0

Sha256 of the tarball at all three locations (local + both mirrors)
matches:
`ba1c32b3af07c7fd5a2b168b55f9749473ec09bd8fddcb567dd71b895a54394b`.

No changes to `external/janet/` or `patches/` this session — pure
distribution + paperwork.
