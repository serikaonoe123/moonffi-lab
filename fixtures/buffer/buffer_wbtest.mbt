///|
test "ten seeds times fifty bounded scenarios satisfy model and dependencies" {
  let adapter = BufferAdapter::new()
  for seed = 0; seed < 10; seed = seed + 1 {
    for offset = 0; offset < 50; offset = offset + 1 {
      let trace = generate((seed * 50 + offset).to_uint64())
      assert_true(@lab.validate_dependencies(trace) is None)
      assert_true(adapter.validate(trace) is None)
      assert_true(@lab.decode_trace(trace.encode()) == trace)
    }
  }
}

///|
test "same seed produces identical concrete operations" {
  assert_true(generate(42UL) == generate(42UL))
  assert_true(generate(42UL).steps != generate(43UL).steps)
}

///|
test "adapter rejects forged dependencies and missing detector" {
  let adapter = BufferAdapter::new()
  let trace = generate(1UL)
  let steps = trace.steps.copy()
  steps[0] = { ..steps[0], defines: [] }
  assert_true(adapter.validate(trace.with_steps(steps)) is Some(_))
  let environment = trace.environment.copy()
  environment["profile"] = "asan"
  assert_true(adapter.validate({ ..trace, environment }) is Some(_))
}

///|
test "correct binding respects shared state, binary bytes, error state, and teardown" {
  let trace = generate(17UL)
  let adapter = BufferAdapter::new()
  adapter.configure(trace)
  for step in trace.steps { assert_true(adapter.execute(step) is None) }
  assert_true(adapter.teardown() is None)
}

///|
test "intentional behavior mutants have distinguishable property failures" {
  let expected = ["bytes-roundtrip", "shared-reference-alive", "bytes-roundtrip"]
  for i, mode in ["nul", "share", "error"] {
    let trace = generate(17UL, mode~, noise=0)
    let adapter = BufferAdapter::new()
    adapter.configure(trace)
    let mut failure : @lab.Failure? = None
    for step in trace.steps {
      failure = adapter.execute(step)
      if failure is Some(_) { break }
    }
    let teardown = adapter.teardown()
    assert_true(teardown is None)
    assert_true(failure is Some(_))
    assert_true(failure.unwrap().property == expected[i])
  }
}
