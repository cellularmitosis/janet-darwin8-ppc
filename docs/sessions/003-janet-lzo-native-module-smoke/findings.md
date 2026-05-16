# findings — session 003

Things learned this session that will matter later.

## jpm's macOS native-module link recipe

From [`janet-lang/jpm/configs/macos_config.janet`](https://github.com/janet-lang/jpm/blob/master/configs/macos_config.janet):

```
cflags          -std=c99
dynamic-cflags  -fPIC
dynamic-lflags  -shared -undefined dynamic_lookup -lpthread
modext          .so
modpath         <prefix>/lib/janet
```

Native modules **do not** link `-ljanet`.  `dynamic_lookup` defers
janet C-API symbol resolution to `dlopen()` time, when they're
already live in the host janet process (which is statically linked
against the core).  This is the link shape M1.b's `jpm install` will
produce; matching it now means no surprises later.

## native-module search path on our install

`(dyn :syspath)` on our tarball is `/opt/janet-1.41.3-dev/lib/janet`
(baked in at build time from `PREFIX`).  Combined with the
`:sys:/:all::native:` pattern in `module/paths`, the canonical
location for a third-party `.so` is
`/opt/janet-1.41.3-dev/lib/janet/<name>.so`.  No `JANET_PATH` env
needed for production installs.

## Tiger mktemp gotcha

Tiger's `mktemp` requires a template — `mktemp -d` alone errors with
`usage: mktemp [-d] [-q] [-t prefix] [-u] template ...`.  Use
`mktemp -d -t prefix.XXXXXX`.

## CA bundle on ibookg38

The `imacg3-dev` skill's convention is
`/Users/macuser/tmp/cacert-2026-03-19.pem`.  That file doesn't
exist on `ibookg38`; the local equivalent is
`/opt/tigersh-deps-0.1/share/cacert.pem` (bundled with
tigersh-deps-0.1).  Also present:
`/opt/ca-certificates-{20221011,20230110}/share/cacert.pem`.  Any
of them works for current GitHub TLS.

## gcc-4.9.4 vs gcc-libs-4.9.4 on the clean test host

ibookg37 has **both** `/opt/gcc-4.9.4/` and `/opt/gcc-libs-4.9.4/`
installed.  Session 002's initial host survey only listed
`gcc-libs-4.9.4`; both are present.  The dual `libgcc_s.1.dylib`
reference baked into gcc-4.9-produced binaries (`/usr/lib/...`
**and** `/opt/gcc-4.9.4/lib/...`) resolves cleanly on ibookg37.

## no git on ibookg38

`/opt/git-*` is not installed on ibookg38.  Use
`/opt/tigersh-deps-0.1/bin/curl` to pull tarballs from GitHub:
`curl -fsSL https://github.com/<owner>/<repo>/archive/refs/heads/<branch>.tar.gz`.
The resulting tarball untars to `<repo>-<branch>/` — rename to
`<repo>/` for cleanliness.

## /opt is admin-writable on the fleet

`/opt` is `drwxrwxr-x root admin` and `macuser` is in `admin`.  No
sudo needed to install tarballs or add files under `/opt/<pkg>/`
when the package dir is also macuser-owned (as ours is — janet was
installed in session 002 without sudo).
