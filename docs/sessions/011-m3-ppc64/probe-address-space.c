/* probe-address-space.c — verify the 47-bit-address-space invariant
 * holds for Tiger ppc64 userland.
 *
 * Janet's JANET_NANBOX_64 layout encodes a pointer inside a NaN-tagged
 * double.  It uses bits 0..46 for the pointer payload and reserves
 * bits 47..63 for the NaN signaling + 4-bit type tag.  Therefore: any
 * userland pointer that could be NaN-boxed must have bits 47..63 = 0
 * (after an optional alignment shift, but we use shift=0 for amd64-
 * style 47-bit layouts).
 *
 * This probe allocates pointers from a variety of sources and checks
 * that all of them fit in 47 bits, i.e. (p >> 47) == 0.
 *
 * Compile (on pmacg5):
 *   gcc-4.9 -arch ppc64 -O0 -g -o probe-address-space probe-address-space.c
 *
 * Then run, and check exit status (0 = all good, 1 = at least one
 * pointer had a bit set above bit 46).
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

static int g_fail = 0;

static void check(const char *label, void *p) {
    uintptr_t u = (uintptr_t)p;
    /* High 17 bits should all be zero for a 47-bit address space. */
    uintptr_t high = u >> 47;
    int bad = (high != 0);
    printf("  %-30s %p  high17=0x%05llx %s\n",
           label, p,
           (unsigned long long)high,
           bad ? "FAIL" : "ok");
    if (bad) g_fail = 1;
}

int main(int argc, char **argv) {
    printf("pointer size: %zu bytes\n", sizeof(void *));
    printf("uintptr_t bits: %zu\n", sizeof(uintptr_t) * 8);
    printf("checking that all userland pointers fit in 47 bits:\n");

    /* Stack. */
    int stack_var = 42;
    check("stack int*", &stack_var);

    /* main() argv. */
    check("argv", argv);
    if (argc > 0) check("argv[0]", argv[0]);

    /* Static / .data. */
    static int data_var = 0;
    check("static int* (.data)", &data_var);

    /* .text (function pointer). */
    check("&main (.text)", (void *)main);

    /* Heap, small. */
    void *h_small = malloc(64);
    check("malloc(64)", h_small);

    /* Heap, medium. */
    void *h_med = malloc(64 * 1024);
    check("malloc(64K)", h_med);

    /* Heap, large. */
    void *h_big = malloc(16 * 1024 * 1024);
    check("malloc(16M)", h_big);

    /* mmap, anonymous, small. */
    void *m_small = mmap(NULL, 64 * 1024,
                         PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANON, -1, 0);
    if (m_small != MAP_FAILED) check("mmap-anon(64K)", m_small);

    /* mmap, anonymous, large. */
    void *m_big = mmap(NULL, 64 * 1024 * 1024,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANON, -1, 0);
    if (m_big != MAP_FAILED) check("mmap-anon(64M)", m_big);

    /* Many mallocs in a row to see the heap-growth slope. */
    printf("walking the heap:\n");
    void *prev = NULL;
    int i;
    for (i = 0; i < 20; i++) {
        void *p = malloc(4 * 1024 * 1024);
        if (!p) { printf("  malloc failed at i=%d\n", i); break; }
        char label[32];
        snprintf(label, sizeof(label), "malloc[%d] 4M", i);
        check(label, p);
        prev = p;
    }
    (void)prev;

    if (g_fail) {
        printf("\nFAIL: at least one pointer had bits 47..63 set.\n");
        printf("Tiger ppc64 userland may NOT support the 47-bit\n");
        printf("nanbox layout.  Consider JANET_NANBOX_64_POINTER_SHIFT.\n");
        return 1;
    } else {
        printf("\nPASS: all pointers fit in 47 bits.  Tiger ppc64\n");
        printf("userland is compatible with the JANET_NANBOX_64 layout\n");
        printf("with shift=0 (same invariant as amd64/x86_64).\n");
        return 0;
    }
}
