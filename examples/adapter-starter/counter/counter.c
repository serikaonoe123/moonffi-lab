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

/* Parameter-strategy consumer. Mode 1 is a labelled NUL truncation mutant. */
#include <string.h>
MOONBIT_FFI_EXPORT int32_t starter_echo_i32(int32_t value) { return value; }
MOONBIT_FFI_EXPORT uint32_t starter_echo_u32(uint32_t value) { return value; }
MOONBIT_FFI_EXPORT int64_t starter_echo_i64(int64_t value) { return value; }
MOONBIT_FFI_EXPORT uint64_t starter_echo_u64(uint64_t value) { return value; }
MOONBIT_FFI_EXPORT int32_t starter_not_bool(int32_t value) { return value ? 0 : 1; }
MOONBIT_FFI_EXPORT uint64_t starter_float_bits(double value) {
  uint64_t bits; memcpy(&bits, &value, sizeof(bits)); return bits;
}
MOONBIT_FFI_EXPORT double starter_float_from_bits(uint64_t bits) {
  double value; memcpy(&value, &bits, sizeof(value)); return value;
}
MOONBIT_FFI_EXPORT moonbit_bytes_t starter_echo_bytes(moonbit_bytes_t data, int32_t length, int32_t mode) {
  int32_t count = length;
  if (mode == 1) { count = 0; while (count < length && data[count] != 0) ++count; }
  moonbit_bytes_t result = moonbit_make_bytes(count, 0);
  if (count) memcpy(result, data, (size_t)count);
  return result;
}
MOONBIT_FFI_EXPORT int64_t starter_array_checksum(const int32_t *values, int32_t length) {
  int64_t sum = 0;
  for (int32_t i = 0; i < length; ++i) sum += (int64_t)(i + 1) * values[i];
  return sum;
}
MOONBIT_FFI_EXPORT int64_t starter_nullable_value(int32_t present, int64_t value) {
  const int64_t *pointer = present ? &value : NULL;
  return pointer ? *pointer : 0;
}
