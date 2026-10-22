/* Owned, intentional fault fixtures for isolated process reduction tests.
 * Never called in a controller. These are not defects in an external library. */
#include <stdint.h>
#include <stdlib.h>
#include <moonbit.h>
#ifdef _WIN32
#define NOINLINE __declspec(noinline)
#else
#define NOINLINE __attribute__((noinline))
#endif
static NOINLINE void crash_a(void) {
  volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)0; *p = 1;
}
static NOINLINE void crash_b(void) {
  volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)0; *p = 2;
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
    default: break;
  }
}
