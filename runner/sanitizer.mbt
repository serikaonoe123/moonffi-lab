///| Require a matching diagnostic header and summary. A runtime name, an
/// address, a printed "ERROR", or an unexplained non-zero exit is insufficient.
/// The category is evidence of an ASan report, not a same-root-cause fingerprint.
pub fn asan_category(stderr : String) -> String? {
  for category in ["heap-buffer-overflow", "heap-use-after-free", "stack-buffer-overflow", "global-buffer-overflow", "double-free", "alloc-dealloc-mismatch"] {
    if stderr.contains("ERROR: AddressSanitizer: " + category) &&
      stderr.contains("SUMMARY: AddressSanitizer: " + category) {
      return Some(category)
    }
  }
  None
}
