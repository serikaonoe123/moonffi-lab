/* Teaching fixture, not a discovered bug. Mode 1 intentionally corrupts the
 * value when an out-of-range addition returns an error. No undefined access. */
#include <stdint.h>
#include <moonbit.h>

typedef struct { int32_t value; int32_t closed; } Counter;
static int32_t live = 0;
static int32_t calls = 0;

static void close_counter(Counter *counter) {
  if (!counter->closed) { counter->closed = 1; --live; }
}
static void finalize_counter(void *counter) { close_counter((Counter *)counter); }

MOONBIT_FFI_EXPORT void *starter_counter_new(int32_t value) {
  Counter *counter = (Counter *)moonbit_make_external_object(finalize_counter, sizeof(Counter));
  counter->value = value;
  counter->closed = 0;
  ++live; ++calls;
  return counter;
}
MOONBIT_FFI_EXPORT int32_t starter_counter_add(Counter *counter, int32_t delta, int32_t mode) {
  ++calls;
  if (counter->closed) return -2;
  int64_t next = (int64_t)counter->value + delta;
  if (next < -100 || next > 100) {
    if (mode == 1) counter->value = 0; /* intentional error-path defect */
    return -1;
  }
  counter->value = (int32_t)next;
  return 0;
}
MOONBIT_FFI_EXPORT int32_t starter_counter_value(Counter *counter) {
  ++calls;
  return counter->closed ? INT32_MIN : counter->value;
}
MOONBIT_FFI_EXPORT void starter_counter_close(Counter *counter) { ++calls; close_counter(counter); }
MOONBIT_FFI_EXPORT int32_t starter_counter_live(void) { return live; }
MOONBIT_FFI_EXPORT int32_t starter_counter_calls(void) { return calls; }
