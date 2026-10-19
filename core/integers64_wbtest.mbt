///| Existing Int consumers keep their exact sequence, while the public wide
/// helper has a separately typed result and includes zero/nearest neighbours.
test "wide integer candidates agree with Int across its domain examples" {
  assert_true(shrink_int64(0L) == [])
  assert_true(shrink_int64(1L) == [0L] && shrink_int64(-1L) == [0L])
  assert_true(shrink_int64(9L) == [0L, 5L, 7L, 8L])
  assert_true(shrink_int64(-9L) == [0L, -5L, -7L, -8L])
  for original in [-2147483648, -2147483647, -1000, -2, -1, 0, 1, 2, 1000, 2147483647] {
    assert_true(shrink_int64(original.to_int64()) == shrink_int(original).map(value => value.to_int64()))
  }
}

///| The oracle compares signed values against an exhaustive threshold; it does
/// not reproduce the division/subtraction recurrence used by the generator.
test "wide candidates reach every small signed monotone threshold" {
  for original = -128; original <= 128; original = original + 1 {
    let magnitude = if original < 0 { -original } else { original }
    for threshold = 0; threshold <= magnitude; threshold = threshold + 1 {
      let boundary = (if original < 0 { -threshold } else { threshold }).to_int64()
      let mut current = original.to_int64()
      let mut accepted = 0
      while true {
        let mut next : Int64? = None
        for candidate in shrink_int64(current) {
          if (if original < 0 { candidate <= boundary } else { candidate >= boundary }) { next = Some(candidate); break }
        }
        guard next is Some(value) else { break }
        current = value
        accepted += 1
        assert_true(accepted <= magnitude)
      }
      assert_true(current == boundary)
    }
  }
}

///| Signed inequalities avoid computing abs(min). Parsing decimal tokens
/// independently checks the existing exact JSON descent gate at full width.
test "wide candidate bounds and exact numeric descent include Int64 minimum" {
  for original in [-9223372036854775808L, -9223372036854775807L, -9007199254740993L, -4294967296L, -2L, -1L, 0L, 1L, 2L, 4294967296L, 9007199254740993L, 9223372036854775807L] {
    let candidates = shrink_int64(original)
    assert_true(candidates == shrink_int64(original) && candidates.length() <= 64)
    let seen : Map[Int64, Bool] = Map([])
    let mut previous : Int64? = None
    for candidate in candidates {
      assert_true(!seen.contains(candidate))
      if original < 0L {
        assert_true(candidate <= 0L && candidate > original)
        if previous is Some(before) { assert_true(candidate < before) }
      } else {
        assert_true(candidate >= 0L && candidate < original)
        if previous is Some(before) { assert_true(candidate > before) }
      }
      assert_true(arguments_simpler(@json.parse(candidate.to_string()), @json.parse(original.to_string())))
      seen[candidate] = true
      previous = Some(candidate)
    }
    if original == 0L { assert_true(candidates.is_empty()) } else {
      assert_true(candidates[0] == 0L)
      assert_true(previous == Some(if original < 0L { original + 1L } else { original - 1L }))
    }
  }
  let large = @json.parse("9007199254740993")
  let neighbour = @json.parse("9007199254740992")
  assert_true(large == neighbour && large.stringify() != neighbour.stringify())
  assert_true(arguments_simpler(neighbour, large) && !arguments_simpler(large, neighbour))
  assert_true(Json(9007199254740993L) is String(_))
  assert_true(!arguments_simpler(Json(9007199254740992L), Json(9007199254740993L)))
}

///| Test large thresholds, exact neighbours beyond Double, and the unshrinkable
/// minimum itself without ever negating that minimum or narrowing to Int.
test "wide threshold search converges at precision and signed boundaries" {
  for sample in [
    (9223372036854775807L, 0L), (9223372036854775807L, 4294967296L),
    (9223372036854775807L, 9007199254740993L), (9223372036854775807L, 9223372036854775806L),
    (-9223372036854775808L, 0L), (-9223372036854775808L, -4294967296L),
    (-9223372036854775808L, -9007199254740993L), (-9223372036854775808L, -9223372036854775807L),
    (-9223372036854775808L, -9223372036854775808L),
  ] {
    let (original, boundary) = sample
    let mut current = original
    let mut accepted = 0
    while true {
      let mut next : Int64? = None
      for candidate in shrink_int64(current) {
        if (if original < 0L { candidate <= boundary } else { candidate >= boundary }) { next = Some(candidate); break }
      }
      guard next is Some(value) else { break }
      assert_true(arguments_simpler(@json.parse(value.to_string()), @json.parse(current.to_string())))
      current = value
      accepted += 1
      assert_true(accepted <= 128)
    }
    assert_true(current == boundary)
  }
}
