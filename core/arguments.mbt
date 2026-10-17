///| A shorter JSON encoding remains a valid descent. At equal length, only
/// componentwise integer magnitude decreases are allowed: containers keep their
/// shape, nonnumeric leaves stay identical, and no numeric leaf may increase.
/// Decimal digits are compared directly, without rounding through Double or
/// overflowing Int64. This is an ordering gate, not a candidate generator or a
/// claim that the resulting arguments are minimal.
pub fn arguments_simpler(candidate : Json, original : Json) -> Bool {
  let candidate_length = candidate.stringify().length()
  let original_length = original.stringify().length()
  if candidate_length != original_length {
    return candidate_length < original_length
  }
  integer_descent(candidate, original) == Some(true)
}

///| None means incomparable; Some(false) means unchanged; Some(true) means a
/// strict descent. Avoid Json's numeric equality, which compares rounded Double
/// values even when the parser preserved distinct large integer representations.
fn integer_descent(candidate : Json, original : Json) -> Bool? {
  match (candidate, original) {
    (Number(_, ..), Number(_, ..)) => {
      let candidate_text = candidate.stringify()
      let original_text = original.stringify()
      if candidate_text == original_text { return Some(false) }
      guard decimal_magnitude(candidate_text) is Some(a) else { return None }
      guard decimal_magnitude(original_text) is Some(b) else { return None }
      if a.length() < b.length() || (a.length() == b.length() && a < b) {
        Some(true)
      } else { None }
    }
    (Array(a), Array(b)) => {
      if a.length() != b.length() { return None }
      let mut decreased = false
      for index = 0; index < a.length(); index = index + 1 {
        guard integer_descent(a[index], b[index]) is Some(smaller) else { return None }
        decreased = decreased || smaller
      }
      Some(decreased)
    }
    (Object(a), Object(b)) => {
      if a.length() != b.length() { return None }
      let mut decreased = false
      for key, value in a {
        guard b.get(key) is Some(previous) else { return None }
        guard integer_descent(value, previous) is Some(smaller) else { return None }
        decreased = decreased || smaller
      }
      Some(decreased)
    }
    (String(a), String(b)) => if a == b { Some(false) } else { None }
    (Null, Null) | (True, True) | (False, False) => Some(false)
    _ => None
  }
}

///| Only canonical decimal integers participate in equal-length descent.
/// Fractions/exponents retain the old length rule. Negative zero has magnitude
/// zero; changing its sign alone is not an equal-length numeric descent.
fn decimal_magnitude(text : String) -> StringView? {
  let digits = if text.has_prefix("-") { text[1:] } else { text[:] }
  if digits.length() == 0 { return None }
  for digit in digits {
    if digit < '0' || digit > '9' { return None }
  }
  if digits.length() > 1 && digits.has_prefix("0") { return None }
  Some(digits)
}
