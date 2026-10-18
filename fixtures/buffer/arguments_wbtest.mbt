///| Every byte value uses the public integer candidates without changing the
/// target position, handle, operation identity or dependency declarations.
test "Buffer byte candidates preserve metadata and valid write bounds" {
  let adapter = BufferAdapter::new()
  let base = generate(0UL, noise=0)
  for value = 0; value <= 255; value = value + 1 {
    let original = operation_step("write", Write("a", 0, value))
    let before = original.args.stringify()
    let candidates = adapter.shrink_arguments(original)
    assert_true(candidates == adapter.shrink_arguments(original))
    assert_true(candidates.length() == @lab.shrink_int(value).length())
    let seen : Map[String, Bool] = Map([])
    for candidate in candidates {
      assert_true({ ..candidate, args: original.args } == original)
      assert_true(@lab.arguments_simpler(candidate.args, original.args))
      guard (try! @json.from_json(candidate.args) : Operation) is Write(id, index, smaller) else { fail("changed operation") }
      assert_true(id == "a" && index == 0 && smaller >= 0 && smaller < value)
      let key = candidate.args.stringify()
      assert_true(!seen.contains(key))
      seen[key] = true
      assert_true(adapter.validate(base.with_steps([
        operation_step("new", New("a", "00")), candidate, operation_step("read", Read("a")),
      ])) is None)
    }
    assert_true(original.args.stringify() == before)
  }
  assert_true(adapter.handles.is_empty() && adapter.model.is_empty())
}
