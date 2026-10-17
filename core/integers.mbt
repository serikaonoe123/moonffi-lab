///| Finite, deterministic candidates for a signed 32-bit Int. Zero comes first;
/// then progressively smaller changes approach the input from the direction of
/// zero, ending at its immediate neighbour. Every candidate has smaller absolute
/// value, keeps the sign unless zero, and is unique. At most 32 are returned.
/// Division and same-sign subtraction also handle Int's minimum without abs or
/// negation overflow. The adapter must still validate its domain/preconditions;
/// these candidates do not imply a globally minimal failing argument.
pub fn shrink_int(value : Int) -> Array[Int] {
  if value == 0 { return [] }
  let candidates = [0]
  let mut distance = value / 2
  while distance != 0 {
    candidates.push(value - distance)
    distance = distance / 2
  }
  candidates
}
