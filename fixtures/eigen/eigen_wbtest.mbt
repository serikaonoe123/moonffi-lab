///|
test "500 Eigen sequences are pure-model valid and roundtrip losslessly" {
  let adapter = EigenAdapter::new()
  for i = 0; i < 500; i = i + 1 {
    let trace = generate(i.to_uint64())
    assert_true(@lab.validate_dependencies(trace) is None)
    assert_true(adapter.validate(trace) is None)
    assert_true(@lab.decode_trace(trace.encode()) == trace)
  }
}

///|
test "Eigen reads, transpose independence and rejected addition preserve state" {
  for i = 0; i < 20; i = i + 1 {
    let trace = generate(i.to_uint64())
    let adapter = EigenAdapter::new()
    for step in trace.steps { assert_true(adapter.execute(step) is None) }
    assert_true(adapter.teardown() is None)
  }
}

///|
test "Eigen rejects compatible reject_add and forged dependencies" {
  let adapter = EigenAdapter::new()
  let trace = generate(1UL)
  assert_true(adapter.validate(trace.with_steps([
    operation_step("1", New("a", 1, 1, [1])),
    operation_step("2", New("b", 1, 1, [2])),
    operation_step("3", RejectAdd("a", "b")),
  ])) is Some(_))
  let steps = trace.steps.copy()
  steps[0] = { ..steps[0], defines: [] }
  assert_true(adapter.validate(trace.with_steps(steps)) is Some(_))
}
