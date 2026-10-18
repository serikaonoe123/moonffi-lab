///| Keep the joint zero fast path but independently vary only one component in
/// every other proposal. Exercise zero, sparse and full sixteen-entry matrices.
test "Eigen construction candidates preserve shape and vary individual components" {
  let adapter = EigenAdapter::new()
  let base = generate(0UL, steps=8)
  for data in [[0], [9], [9, 0, 0, 0], [9, -9, 3, 0], Array::makei(16, i => if i % 2 == 0 { 100 } else { -100 })] {
    let size = if data.length() == 1 { 1 } else if data.length() == 4 { 2 } else { 4 }
    let original = operation_step("new", New("a", size, size, data))
    let before = original.args.stringify()
    let candidates = adapter.shrink_arguments(original)
    assert_true(candidates == adapter.shrink_arguments(original) && candidates.length() <= 513)
    let seen : Map[String, Bool] = Map([])
    for candidate in candidates {
      assert_true({ ..candidate, args: original.args } == original)
      assert_true(@lab.arguments_simpler(candidate.args, original.args))
      guard (try! @json.from_json(candidate.args) : Operation) is New(id, rows, cols, changed) else { fail("changed operation") }
      assert_true(id == "a" && rows == size && cols == size && changed.length() == data.length())
      let mut changes = 0
      for index = 0; index < data.length(); index = index + 1 {
        if changed[index] != data[index] { changes += 1 }
      }
      assert_true(changes > 0 && (changes == 1 || changed.all(value => value == 0)))
      let key = candidate.args.stringify()
      assert_true(!seen.contains(key))
      seen[key] = true
      assert_true(adapter.validate(base.with_steps([candidate])) is None)
    }
    assert_true(original.args.stringify() == before)
    if data.all(value => value == 0) { assert_true(candidates.is_empty()) } else {
      guard (try! @json.from_json(candidates[0].args) : Operation) is New(_, _, _, zero) else { fail("expected construction") }
      assert_true(zero.all(value => value == 0))
    }
  }
  assert_true(adapter.handles.is_empty() && adapter.models.is_empty())
}

///|
test "Eigen signed assignment candidates preserve coordinates and validate" {
  let adapter = EigenAdapter::new()
  let base = generate(0UL, steps=8)
  for value = -100; value <= 100; value = value + 1 {
    let original = operation_step("set", Set("a", 1, 0, value))
    let candidates = adapter.shrink_arguments(original)
    assert_true(candidates.length() == @lab.shrink_int(value).length())
    for candidate in candidates {
      assert_true({ ..candidate, args: original.args } == original)
      assert_true(@lab.arguments_simpler(candidate.args, original.args))
      guard (try! @json.from_json(candidate.args) : Operation) is Set(id, row, col, smaller) else { fail("changed operation") }
      assert_true(id == "a" && row == 1 && col == 0 && smaller >= -100 && smaller <= 100)
      assert_true(adapter.validate(base.with_steps([operation_step("new", New("a", 2, 2, [0, 0, 0, 0])), candidate])) is None)
    }
  }
  assert_true(adapter.handles.is_empty() && adapter.models.is_empty())
}
