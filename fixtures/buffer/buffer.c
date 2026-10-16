/* Original test fixture. Every mutant is intentional and labelled.
 * Resource lifetime bugs are made observable without dereferencing freed memory.
 * crash/hang are dedicated process-controller probes, not discovered defects. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <signal.h>
#include <unistd.h>
#endif
#include <moonbit.h>

typedef struct {
  int32_t holders;
  int32_t open_refs;
  int32_t len;
  int32_t alive;
  uint8_t *data;
} Buffer;
typedef struct { Buffer *buffer; int32_t closed; } Handle;

static int32_t live_resources = 0;

static void close_handle(Handle *h, int32_t mutant) {
  if (h->closed) return;
  h->closed = 1;
  Buffer *b = h->buffer;
  b->open_refs--;
  if (b->alive && (b->open_refs == 0 || mutant == 2)) {
    b->alive = 0;
    live_resources--;
    /* Keep the storage until final holders disappear, so the lifecycle
     * mutant is a deterministic contract failure rather than undefined UAF. */
  }
}

static void finalize_handle(void *self) {
  Handle *h = (Handle *)self;
  close_handle(h, 0);
  if (--h->buffer->holders == 0) {
    free(h->buffer->data);
    free(h->buffer);
  }
}

static Handle *wrap(Buffer *b) {
  Handle *h = (Handle *)moonbit_make_external_object(finalize_handle, sizeof(Handle));
  h->buffer = b;
  h->closed = 0;
  b->holders++;
  b->open_refs++;
  return h;
}

MOONBIT_FFI_EXPORT void *lab_buffer_new(moonbit_bytes_t data, int32_t len, int32_t mutant) {
  Buffer *b = (Buffer *)calloc(1, sizeof(Buffer));
  if (!b) abort();
  b->data = (uint8_t *)calloc((size_t)len + 1, 1);
  if (!b->data) abort();
  if (len) memcpy(b->data, data, (size_t)len);
  b->len = mutant == 1 ? (int32_t)strlen((const char *)b->data) : len;
  b->alive = 1;
  live_resources++;
  return wrap(b);
}

MOONBIT_FFI_EXPORT void *lab_buffer_share(Handle *h) { return wrap(h->buffer); }
MOONBIT_FFI_EXPORT void lab_buffer_close(Handle *h, int32_t mutant) { close_handle(h, mutant); }
MOONBIT_FFI_EXPORT int32_t lab_buffer_alive(Handle *h) { return !h->closed && h->buffer->alive; }
MOONBIT_FFI_EXPORT int32_t lab_buffer_live(void) { return live_resources; }

MOONBIT_FFI_EXPORT moonbit_bytes_t lab_buffer_read(Handle *h) {
  Buffer *b = h->buffer;
  moonbit_bytes_t result = moonbit_make_bytes(b->len, 0);
  if (b->len) memcpy(result, b->data, (size_t)b->len);
  return result;
}

MOONBIT_FFI_EXPORT int32_t lab_buffer_write(Handle *h, int32_t index, int32_t value, int32_t mutant) {
  Buffer *b = h->buffer;
  if (index < 0 || index >= b->len) {
    if (mutant == 3) memset(b->data, 0, (size_t)b->len);
    return -1;
  }
  b->data[index] = (uint8_t)value;
  return 0;
}

MOONBIT_FFI_EXPORT void lab_buffer_probe(int32_t mode) {
#ifdef _WIN32
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  if (mode == 4) { RaiseFailFastException(NULL, NULL, 0); }
  if (mode == 5) { for (;;) Sleep(1000); }
#else
  if (mode == 4) raise(SIGABRT);
  if (mode == 5) { for (;;) sleep(1); }
#endif
}
