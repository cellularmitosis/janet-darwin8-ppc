/* probe-address-space-v2.c — focused probe for what Janet would
 * actually NaN-box.  v1 showed stack pointers at bit 50, which would
 * fail the 47-bit invariant — but Janet doesn't wrap stack pointers,
 * so the question is whether anything Janet *does* wrap reaches there.
 *
 * Janet wraps:
 *   - heap allocations (malloc'd via the GC) — JanetTable, JanetArray,
 *     JanetFunction, JanetFiber, etc.
 *   - C function pointers (janet_wrap_cfunction)
 *   - static C string literals (janet_cstringv)
 *   - user-provided pointers via janet_wrap_pointer / abstracts
 *
 * Janet does NOT wrap stack-allocated values.  So we don't care about
 * stack-pointer-bit-50, only about:
 *   - heap addresses (any size, repeated)
 *   - function pointers in main binary
 *   - function pointers in any dynamically-loaded dylib (libSystem,
 *     libMacportsLegacySupport)
 *   - static strings (.rodata)
 *
 * Compile:
 *   gcc-4.9 -m64 -O0 -g -o probe-address-space-v2 \
 *     probe-address-space-v2.c
 *
 * Or to test against legacy-support (where macros that retarget
 * libc symbols live), link it in:
 *   gcc-4.9 -m64 -O0 -g \
 *     -I/opt/macports-legacy-support-20221029/include/LegacySupport \
 *     -L/opt/macports-legacy-support-20221029/lib \
 *     -lMacportsLegacySupport \
 *     -o probe-address-space-v2 probe-address-space-v2.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <math.h>

static int g_fail = 0;

static void check(const char *label, void *p) {
    uintptr_t u = (uintptr_t)p;
    uintptr_t high = u >> 47;
    int bad = (high != 0);
    printf("  %-38s %p  high17=0x%05llx %s\n",
           label, p,
           (unsigned long long)high,
           bad ? "FAIL" : "ok");
    if (bad) g_fail = 1;
}

static int dummy_function(int x) { return x + 1; }
static const char dummy_string[] = "hello";

int main(int argc, char **argv) {
    (void)argv;
    printf("checking pointers Janet would actually NaN-box:\n");

    /* C function pointers in the main binary (.text). */
    check("&main",                      (void *)main);
    check("&dummy_function",            (void *)dummy_function);
    check("&printf (libc)",             (void *)printf);
    check("&malloc (libc)",             (void *)malloc);
    check("&free  (libc)",              (void *)free);
    check("&exit  (libc)",              (void *)exit);
    check("&pthread_self",              (void *)dlsym(RTLD_DEFAULT, "pthread_self"));
    check("&dlopen",                    (void *)dlopen);
    check("&pow   (libm)",              (void *)pow);
    check("&sqrt  (libm)",              (void *)sqrt);

    /* Static read-only data (.rodata / cstring literals). */
    check("\"hello\" literal",          (void *)"hello");
    check("dummy_string (.rodata)",     (void *)dummy_string);

    /* Static writable data (.data / .bss). */
    static int s_int = 7;
    static int s_bss_int;
    check("&s_int (.data)",             &s_int);
    check("&s_bss_int (.bss)",          &s_bss_int);
    check("&stdout (libc)",             (void *)stdout);

    /* Heap allocations: very small ... very large. */
    check("malloc(1)",                  malloc(1));
    check("malloc(15)",                 malloc(15));
    check("malloc(16)",                 malloc(16));
    check("malloc(63)",                 malloc(63));
    check("malloc(64)",                 malloc(64));
    check("malloc(4096)",               malloc(4096));
    check("malloc(64*1024)",            malloc(64 * 1024));
    check("malloc(1<<20)",              malloc(1 << 20));
    check("malloc(1<<24)",              malloc(1 << 24)); /* 16 MB */
    check("malloc(1<<26)",              malloc(1 << 26)); /* 64 MB */

    /* Heap stress: allocate lots of 1 MB blocks, see the high water. */
    printf("heap stress (allocate 1 MB blocks until 256 MB or failure):\n");
    void *highest = NULL;
    uintptr_t highest_u = 0;
    int i;
    for (i = 0; i < 256; i++) {
        void *p = malloc(1 << 20);
        if (!p) {
            printf("  malloc[%d] failed\n", i);
            break;
        }
        uintptr_t u = (uintptr_t)p;
        if (u > highest_u) { highest_u = u; highest = p; }
    }
    printf("  allocated %d MB; highest heap address: %p (high17=0x%05llx)\n",
           i, highest,
           (unsigned long long)(highest_u >> 47));
    if ((highest_u >> 47) != 0) {
        printf("  FAIL: heap reached bit 47+\n");
        g_fail = 1;
    }

    if (g_fail) {
        printf("\nFAIL: at least one Janet-wrappable pointer had bits 47..63 set.\n");
        printf("Pointer-shift cannot save us — function pointers and static\n");
        printf("data are not 16-byte aligned, so JANET_NANBOX_64 with shift>0\n");
        printf("would corrupt them.\n");
        return 1;
    } else {
        printf("\nPASS: every Janet-wrappable pointer fits in 47 bits.\n");
        printf("Tiger ppc64 userland is compatible with JANET_NANBOX_64 at\n");
        printf("the default shift=0.  Janet doesn't wrap stack pointers,\n");
        printf("so the high stack at bit 50 is irrelevant.\n");
        return 0;
    }
}
