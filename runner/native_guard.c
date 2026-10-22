/* Opt-in, per-worker crash-site evidence. It records only faults in the main
 * executable; unknown modules, fail-fast and missing contexts stay unsupported.
 * The POSIX handler uses only a precomputed text range and write/sigaction/kill.
 * This is an observed site, not a root-cause identity or memory-safety claim. */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <stdint.h>
#include <stddef.h>
#include <moonbit.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <signal.h>
#include <unistd.h>
#include <ucontext.h>
#include <link.h>
#endif

static size_t append_text(char *out, size_t length, const char *text) {
  while (*text) out[length++] = *text++;
  return length;
}
static size_t append_number(char *out, size_t length, int64_t value) {
  char reverse[24]; size_t count = 0;
  uint64_t magnitude = value < 0 ? (uint64_t)(-value) : (uint64_t)value;
  if (value < 0) out[length++] = '-';
  do { reverse[count++] = (char)('0' + magnitude % 10); magnitude /= 10; } while (magnitude);
  while (count) out[length++] = reverse[--count];
  return length;
}
static void emit_site(const char *kind, int64_t code, int64_t detail, uintptr_t offset) {
  char out[192]; char reverse[2 * sizeof(uintptr_t)]; size_t count = 0, length = 0;
  length = append_text(out, length, "MOONFFI_CRASH_V1\t");
  length = append_text(out, length, kind); out[length++] = '\t';
  length = append_number(out, length, code); out[length++] = '\t';
  length = append_number(out, length, detail); out[length++] = '\t';
  length = append_text(out, length, "0x");
  do { reverse[count++] = "0123456789abcdef"[offset & 15]; offset >>= 4; } while (offset);
  while (count) out[length++] = reverse[--count];
  out[length++] = '\n';
#ifdef _WIN32
  DWORD written = 0; WriteFile(GetStdHandle(STD_ERROR_HANDLE), out, (DWORD)length, &written, NULL);
#else
  (void)write(STDERR_FILENO, out, length);
#endif
}

#ifdef _WIN32
static LONG recorded = 0;
static LONG CALLBACK crash_site(EXCEPTION_POINTERS *info) {
  DWORD code = info->ExceptionRecord->ExceptionCode;
  if (code != EXCEPTION_ACCESS_VIOLATION && code != EXCEPTION_INT_DIVIDE_BY_ZERO && code != EXCEPTION_ILLEGAL_INSTRUCTION) return EXCEPTION_CONTINUE_SEARCH;
  void *pc = info->ExceptionRecord->ExceptionAddress;
  HMODULE module = NULL;
  if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)pc, &module) || module != GetModuleHandleA(NULL)) return EXCEPTION_CONTINUE_SEARCH;
  if (InterlockedExchange(&recorded, 1) == 0) {
    int64_t detail = (code == EXCEPTION_ACCESS_VIOLATION && info->ExceptionRecord->NumberParameters) ? (int64_t)info->ExceptionRecord->ExceptionInformation[0] : 0;
    emit_site("windows", (int32_t)code, detail, (uintptr_t)pc - (uintptr_t)module);
  }
  return EXCEPTION_CONTINUE_SEARCH;
}
MOONBIT_FFI_EXPORT int32_t lab_native_guard_install(void) {
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  return AddVectoredExceptionHandler(0, crash_site) ? 0 : 1;
}
#else
static uintptr_t image_base = 0, text_start = 0, text_end = 0;
static volatile sig_atomic_t recorded = 0;
static const int watched[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT};
static struct sigaction previous[5];
static int find_main(struct dl_phdr_info *info, size_t size, void *data) {
  (void)size; (void)data;
  if (info->dlpi_name && info->dlpi_name[0]) return 0;
  image_base = info->dlpi_addr;
  for (int i = 0; i < info->dlpi_phnum; ++i) {
    if (info->dlpi_phdr[i].p_type == PT_LOAD && (info->dlpi_phdr[i].p_flags & PF_X)) {
      uintptr_t start = image_base + info->dlpi_phdr[i].p_vaddr;
      uintptr_t end = start + info->dlpi_phdr[i].p_memsz;
      if (!text_start || start < text_start) text_start = start;
      if (end > text_end) text_end = end;
    }
  }
  return 1;
}
static void crash_site(int signal, siginfo_t *info, void *context) {
  uintptr_t pc = 0;
#if defined(__x86_64__) && defined(REG_RIP)
  pc = (uintptr_t)((ucontext_t *)context)->uc_mcontext.gregs[REG_RIP];
#else
  (void)context;
#endif
  if (!recorded && text_start && pc >= text_start && pc < text_end) {
    recorded = 1; emit_site("signal", signal, info ? info->si_code : 0, pc - image_base);
  }
  for (int i = 0; i < 5; ++i) {
    if (watched[i] == signal) { (void)sigaction(signal, &previous[i], NULL); break; }
  }
  (void)kill(getpid(), signal);
}
MOONBIT_FFI_EXPORT int32_t lab_native_guard_install(void) {
  (void)dl_iterate_phdr(find_main, NULL);
  if (!text_start) return 1;
  struct sigaction action;
  action.sa_sigaction = crash_site; action.sa_flags = SA_SIGINFO | SA_ONSTACK;
  sigemptyset(&action.sa_mask);
  for (int i = 0; i < 5; ++i) {
    if (sigaction(watched[i], &action, &previous[i]) != 0) {
      for (int j = 0; j < i; ++j) (void)sigaction(watched[j], &previous[j], NULL);
      return 1;
    }
  }
  return 0;
}
#endif
