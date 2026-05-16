# v0.2.0-jpm-install-lzo.janet — janet-darwin8-ppc v0.2.0 demo
#
# Acceptance gate for M1.b: jpm-installed native module round-trip
# on a clean Tiger PPC box.  The wrapper (v0.2.0-jpm-install-lzo.sh)
# does the curl/install/bootstrap/`jpm install` orchestration; this
# script just exercises the installed module and reports.
#
# Exercises:
#   1. os/spawn round-trip via /bin/echo                — proves the
#                                                          posix_spawn
#                                                          fork+execve
#                                                          fallback
#   2. jpm-installed lzo native module round-trip       — proves jpm,
#                                                          gcc-4.9,
#                                                          @loader_path
#                                                          all chained
#                                                          end-to-end
#
# The wrapper does the install legwork; if you're running this script
# directly, make sure `jpm install https://github.com/cellularmitosis/janet-lzo`
# has succeeded against this janet install first.

(print)
(print (string/format "=== janet-darwin8-ppc v0.2.0 jpm-install — Janet %s on %s/%s ==="
                      janet/version (os/which) (os/arch)))
(print)

# --- 1. os/spawn round-trip ----------------------------------------------------
#
# The whole point of M1.b: subprocess support.  Use os/spawn with a
# captured stdout pipe so the fork+execve fallback is fully exercised
# (file actions / dup2 / close / exec).

(def proc (os/spawn ["/bin/echo" "hello-from-os/spawn"] :px {:out :pipe}))
(def captured (string/trim (:read (proc :out) :all)))
(def exit-code (os/proc-wait proc))
(print (string/format "[1] os/spawn captured stdout=%j  exit=%d" captured exit-code))
(unless (and (= captured "hello-from-os/spawn") (= exit-code 0))
  (error "os/spawn round-trip failed"))

# --- 2. jpm-installed lzo native module ----------------------------------------

(def lzo-mod (try (require "lzo") ([err] (error (string "lzo not installed — run the wrapper first: " err)))))
(def compress   (get-in lzo-mod [(symbol "compress")   :value]))
(def decompress (get-in lzo-mod [(symbol "decompress") :value]))
(def payload    (buffer (string/repeat "the quick brown fox jumps over the lazy dog. " 200)))
(def compressed (compress payload))
(def decompressed (decompress compressed))
(def ok         (= (string payload) (string decompressed)))
(print (string/format "[2] lzo (via jpm install): %d -> %d bytes (ratio %.4f), round-trip ok=%j"
                      (length payload)
                      (length compressed)
                      (/ (length compressed) (length payload))
                      ok))
(unless ok (error "lzo round-trip mismatch"))

(print)
(print "ok.")
(print)
