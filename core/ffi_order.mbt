///| Keep the historical order for untagged numeric adapters. Typed values use
/// componentwise descent before JSON length so false < true has no reverse edge.
pub fn ffi_arguments_simpler(candidate : Json, original : Json) -> Bool {
  if ffi_typed(candidate) || ffi_typed(original) {
    ffi_descent(candidate, original) == Some(true)
  } else { arguments_simpler(candidate, original) }
}
///|
fn ffi_typed(value : Json) -> Bool {
  match value {
    Null | True | False => true
    Array(items) => items.any(ffi_typed)
    Object(fields) => fields.contains("$ffi_f64") || fields.contains("$ffi_text") || fields.contains("$ffi_bytes") || fields.values().any(ffi_typed)
    _ => false
  }
}
///| None is incomparable, false equal, true strictly smaller. Retained array
/// items are matched monotonically to non-smaller original items.
fn ffi_descent(candidate : Json, original : Json) -> Bool? {
  if candidate is Null { return Some(!(original is Null)) }
  if original is Null { return None }
  if decode_float64(candidate) is Some(small) {
    guard decode_float64(original) is Some(large) else { return None }
    let a = small.reinterpret_as_uint64()
    let b = large.reinterpret_as_uint64()
    let magnitude_a = a & 0x7fffffffffffffffUL
    let magnitude_b = b & 0x7fffffffffffffffUL
    if a == b { return Some(false) }
    if magnitude_a < magnitude_b || (magnitude_a == magnitude_b && a < b) { return Some(true) }
    return None
  }
  if decode_float64(original) is Some(_) { return None }
  if decode_text(candidate) is Some(small) {
    guard decode_text(original) is Some(large) else { return None }
    let a = small.iter().count()
    let b = large.iter().count()
    if small == large { return Some(false) }
    if a < b || (a == b && small < large) { return Some(true) }
    return None
  }
  if decode_text(original) is Some(_) { return None }
  match (candidate, original) {
    (Null, Null) | (True, True) | (False, False) => Some(false)
    (Null, _) | (False, True) => Some(true)
    (_, Null) | (True, False) => None
    (Number(_, ..), Number(_, ..)) => integer_descent(candidate, original)
    (String(a), String(b)) => if a == b { Some(false) } else if a.length() < b.length() { Some(true) } else { None }
    (Array(a), Array(b)) => {
      if a.length() > b.length() { return None }
      let mut smaller = a.length() < b.length()
      let mut cursor = 0
      for item in a {
        let mut found : Bool? = None
        while cursor < b.length() {
          let comparison = ffi_descent(item, b[cursor])
          cursor += 1
          if comparison is Some(_) { found = comparison; break }
          if a.length() == b.length() { return None }
        }
        guard found is Some(decreased) else { return None }
        smaller = smaller || decreased
      }
      Some(smaller)
    }
    (Object(a), Object(b)) => {
      if a.length() != b.length() { return None }
      let mut smaller = false
      for key, value in a {
        guard b.get(key) is Some(previous) else { return None }
        guard ffi_descent(value, previous) is Some(decreased) else { return None }
        smaller = smaller || decreased
      }
      Some(smaller)
    }
    _ => None
  }
}
