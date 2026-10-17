///|
test "integer candidates are ordered toward a boundary and include zero" {
  assert_true(shrink_int(0) == [])
  assert_true(shrink_int(1) == [0] && shrink_int(-1) == [0])
  assert_true(shrink_int(2) == [0, 1] && shrink_int(-2) == [0, -1])
  assert_true(shrink_int(9) == [0, 5, 7, 8])
  assert_true(shrink_int(-9) == [0, -5, -7, -8])
  assert_true(shrink_int(200) == [0, 100, 150, 175, 188, 194, 197, 199])
}

///| The independent oracle uses widened magnitude and an exhaustive monotone
/// failure predicate, not the generator's division/subtraction recurrence.
test "signed candidates converge to every small monotone failure threshold" {
  for original = -128; original <= 128; original = original + 1 {
    let magnitude = if original < 0 { -original } else { original }
    for threshold = 0; threshold <= magnitude; threshold = threshold + 1 {
      let mut current = original
      let mut accepted = 0
      while true {
        let mut next : Int? = None
        for candidate in shrink_int(current) {
          let size = if candidate < 0 { -candidate } else { candidate }
          if size >= threshold { next = Some(candidate); break }
        }
        guard next is Some(value) else { break }
        assert_true(arguments_simpler(Json(value), Json(current)))
        current = value
        accepted += 1
        assert_true(accepted <= magnitude)
      }
      let expected = if original < 0 { -threshold } else { threshold }
      assert_true(current == expected)
    }
  }
}

///|
test "integer candidate bounds and descent hold at full width without overflow" {
  for original in [-2147483648, -2147483647, -1073741824, -2, -1, 0, 1, 2, 1073741824, 2147483647] {
    let candidates = shrink_int(original)
    assert_true(candidates == shrink_int(original) && candidates.length() <= 32)
    let wide = original.to_int64()
    let magnitude = if wide < 0L { -wide } else { wide }
    let seen : Map[Int, Bool] = Map([])
    let mut previous = -1L
    for candidate in candidates {
      let value = candidate.to_int64()
      let size = if value < 0L { -value } else { value }
      assert_true(size < magnitude && size > previous && !seen.contains(candidate))
      assert_true(candidate == 0 || (candidate < 0) == (original < 0))
      assert_true(arguments_simpler(Json(candidate), Json(original)))
      seen[candidate] = true
      previous = size
    }
    if original == 0 { assert_true(candidates.is_empty()) } else {
      assert_true(candidates[0] == 0 && previous == magnitude - 1L)
    }
    for threshold in [0L, 1L, 2L, 999L, 1073741824L, 2147483647L] {
      if threshold > magnitude { continue }
      let mut current = original
      let mut accepted = 0
      while true {
        let mut next : Int? = None
        for candidate in shrink_int(current) {
          let value = candidate.to_int64()
          if (if value < 0L { -value } else { value }) >= threshold { next = Some(candidate); break }
        }
        guard next is Some(value) else { break }
        current = value
        accepted += 1
        assert_true(accepted <= 64)
      }
      let expected = if original < 0 { -threshold } else { threshold }
      assert_true(current.to_int64() == expected)
    }
  }
}
