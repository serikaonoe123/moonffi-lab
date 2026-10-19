///| Anchor to the independently retained eigen-1 seed-17 input from the old
/// hosted toolchain: 3x1 shape and [6, -4, -1] initial matrix values.
test "historical fixture random stream preserves saved seed provenance" {
  let random = RandomState(seed=17UL)
  let actual = [
    random.next_uint(limit=3U),
    random.next_uint(limit=3U),
    random.next_uint(limit=21U),
    random.next_uint(limit=21U),
    random.next_uint(limit=21U),
  ]
  assert_eq(actual, [2U, 0U, 16U, 6U, 9U])
}
