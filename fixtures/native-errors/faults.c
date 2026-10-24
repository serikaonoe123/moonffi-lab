/* Owned, intentional fault fixtures for isolated process reduction tests.
 * Never called in a controller. These are not defects in an external library. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <moonbit.h>
#ifdef _WIN32
#define NOINLINE __declspec(noinline)
#else
#define NOINLINE __attribute__((noinline))
#endif
/* Read the address at runtime: a compiler may discard a call whose only
 * effect is a compile-time undefined null access. Keep two distinct sites. */
static volatile uintptr_t fault_address = 0;
static NOINLINE void crash_a(void) {
  volatile uint8_t *p = (volatile uint8_t *)fault_address; *p = 1;
}
static NOINLINE void crash_b(void) {
  volatile uint8_t *p = (volatile uint8_t *)fault_address; *p = 2;
}
static volatile int outside = 8;
static NOINLINE void memory_a(void) {
  volatile uint8_t *p = (volatile uint8_t *)malloc(8);
  if (!p) exit(2);
  p[outside] = 1;
  free((void *)p);
}
static NOINLINE void memory_b(void) {
  volatile uint8_t *p = (volatile uint8_t *)malloc(8);
  if (!p) exit(2);
  p[outside] = 2;
  free((void *)p);
}
MOONBIT_FFI_EXPORT void lab_owned_native_fault(int32_t mode) {
  switch (mode) {
    case 1: crash_a(); break;
    case 2: crash_b(); break;
    case 3: memory_a(); break;
    case 4: memory_b(); break;
    case 5: exit(7); break;
    /* Deliberately synthetic, incomplete diagnostic: classification alone
     * must not supply a reducible ASan fingerprint without stack frames. */
    case 6:
      fputs("ERROR: AddressSanitizer: heap-buffer-overflow\n"
            "SUMMARY: AddressSanitizer: heap-buffer-overflow\n", stderr);
      exit(7);
      break;
    default: break;
  }
}
