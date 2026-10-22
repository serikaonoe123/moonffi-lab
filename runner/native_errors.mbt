///| Explicitly opt in inside a disposable worker, never in the controller.
extern "C" fn install_native_guard() -> Int = "lab_native_guard_install"

///| Records supported main-image crash sites; does not recover from a fault.
pub fn enable_native_crash_evidence() -> Unit raise {
  if install_native_guard() != 0 { fail("native crash evidence unavailable on this platform") }
}

///| A fingerprint must be accompanied by a supported outcome. Equality is
/// scoped to an unchanged executable in a single Controller, not root cause.
fn reducible(report : @lab.Report) -> Bool {
  report.fingerprint is Some(_) &&
    (report.outcome == PropertyFailure || report.outcome == Crash || report.outcome == MemoryError)
}

///|
fn same_failure(baseline : @lab.Report, candidate : @lab.Report) -> Bool {
  reducible(baseline) && candidate.outcome == baseline.outcome &&
    candidate.fingerprint == baseline.fingerprint
}

///| Strict single complete marker; raw exit/category/address alone is refused.
fn crash_fingerprint(stderr : String, exit_code : Int) -> String? {
  let mut found : String? = None
  for line in stderr.split("\n") {
    if !line.has_prefix("MOONFFI_CRASH_V1\t") { continue }
    if found is Some(_) { return None }
    let fields = line.trim().split("\t").map(v => v.to_owned()).to_array()
    if fields.length() != 5 { return None }
    let code = try { @string.parse_int(fields[2]) } catch { _ => return None }
    let detail = try { @string.parse_int(fields[3]) } catch { _ => return None }
    let supported = if fields[1] == "windows" {
      code == exit_code && ((code == -1073741819 && [0, 1, 8].contains(detail)) ||
        ((code == -1073741795 || code == -1073741676) && detail == 0))
    } else if fields[1] == "signal" {
      // async's POSIX process status is checked against the observed signal.
      [4, 7, 8, 11].contains(code) && detail > 0 && (exit_code == -code || exit_code == 128 + code)
    } else { false }
    let offset = fields[4]
    if !supported || !offset.has_prefix("0x") || offset.length() <= 2 || offset.length() > 18 { return None }
    for c in offset.view(start_offset=2).to_owned().iter() {
      if !(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'f') { return None }
    }
    found = Some("native-site-v1:" + fields[1] + ":" + code.to_string() + ":" + detail.to_string() + ":" + offset)
  }
  found
}

///| Retain two diagnostic frames, excluding ASLR addresses. A symbolized frame
/// must contain a source location; an unsymbolized frame needs a module offset.
fn stable_asan_frame(line : String, index : Int) -> String? {
  let text = line.trim().to_owned()
  if !text.has_prefix("#\{index} 0x") { return None }
  let parts = text.split(" in ").map(v => v.to_owned()).to_array()
  if parts.length() == 2 && parts[1].contains(":") && !parts[1].contains("0x") {
    return Some(parts[1])
  }
  let module_parts = text.split(" (").map(v => v.to_owned()).to_array()
  if module_parts.length() == 2 && module_parts[1].has_suffix(")") && module_parts[1].contains("+0x") {
    return Some(module_parts[1])
  }
  None
}

///| Only one matching ASan diagnostic, with a full first two-frame stack.
fn asan_fingerprint(stderr : String) -> String? {
  guard asan_category(stderr) is Some(category) else { return None }
  let mut headers = 0
  let mut summaries = 0
  let mut first : String? = None
  let mut second : String? = None
  let mut in_stack = false
  for line in stderr.split("\n") {
    if line.contains("ERROR: AddressSanitizer:") { headers += 1; in_stack = true; continue }
    if line.contains("SUMMARY: AddressSanitizer:") { summaries += 1; in_stack = false }
    if in_stack && first is None { first = stable_asan_frame(line.to_owned(), 0) }
    else if in_stack && second is None {
      second = stable_asan_frame(line.to_owned(), 1)
      if first is Some(_) { in_stack = false }
    }
  }
  if headers != 1 || summaries != 1 { return None }
  match (first, second) {
    (Some(a), Some(b)) => Some("asan-frames-v1:" + category + ":" + Json([a, b]).stringify())
    _ => None
  }
}
