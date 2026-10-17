///|
fn state_trace(operations : Array[Operation]) -> @lab.Trace {
  generate(1UL, noise=0).with_steps(operations.mapi((i, operation) => operation_step("s\{i}", operation)))
}

///|
test "resize through an alias preserves shared values and changes all alias bounds" {
  let trace = state_trace([
    New("a", "41"), Share("a", "b"), Resize("b", 3), Write("a", 2, 9),
    Read("b"), Close("a"), Resize("b", 1), Read("b"),
  ])
  let adapter = BufferAdapter::new()
  assert_true(adapter.validate(trace) is None)
  for step in trace.steps { assert_true(adapter.execute(step) is None) }
  assert_true(adapter.teardown() is None)
}

///|
test "state repair drops writes made invalid by deleting a resize" {
  let original = state_trace([New("a", "41"), Share("a", "b"), Resize("b", 3), Write("a", 2, 9), Read("b")])
  let proposal = original.with_steps([original.steps[0], original.steps[1], original.steps[3], original.steps[4]])
  let adapter = BufferAdapter::new()
  assert_true(adapter.validate(proposal) is Some(_))
  let repair = adapter.repair(proposal)
  assert_true(repair.trace.steps.map(s => s.id) == ["s0", "s1", "s4"])
  assert_true(repair.removed.length() == 1 && repair.removed[0].step_id == "s3")
  assert_true(repair.removed[0].reason == "write precondition violated")
  assert_true(@lab.check_repair(proposal, repair) is None)
  assert_true(adapter.validate(repair.trace) is None)
}

///| Independent state oracle: explicit booleans and a scalar length, with no
/// calls to BufferModel, repair_with_model or delete_block. All 128 subsets
/// exercise alias lifetime and the semantic dependency on resize.
test "state repair agrees with independent oracle on all seven-step subsets" {
  let original = state_trace([
    New("a", "41"), Share("a", "b"), Resize("b", 3), Write("a", 2, 9),
    Close("a"), RejectWrite("b", 7), Read("b"),
  ])
  let adapter = BufferAdapter::new()
  for mask = 0; mask < 128; mask = mask + 1 {
    let selected : Array[@lab.Step] = []
    let expected : Array[String] = []
    let mut a = false
    let mut b = false
    let mut length = 0
    for i, step in original.steps {
      if (mask & (1 << i)) == 0 { continue }
      selected.push(step)
      let keep = match i {
        0 => { a = true; length = 1; true }
        1 => if a { b = true; true } else { false }
        2 => if b { length = 3; true } else { false }
        3 => a && length > 2
        4 => if a { a = false; true } else { false }
        5 => b && 7 >= length
        _ => b
      }
      if keep { expected.push(step.id) }
    }
    let proposal = original.with_steps(selected)
    let repair = adapter.repair(proposal)
    assert_true(repair.trace.steps.map(s => s.id) == expected)
    assert_true(@lab.check_repair(proposal, repair) is None)
    assert_true(adapter.validate(repair.trace) is None)
  }
}

///|
test "a rejected transition cannot change shared model state" {
  let model = BufferModel::new()
  assert_true(model.apply(operation_step("n", New("a", "41"))) is None)
  assert_true(model.apply(operation_step("s", Share("a", "b"))) is None)
  assert_true(model.apply(operation_step("bad", Resize("b", 999))) is Some(_))
  assert_true(model.apply(operation_step("w", Write("a", 1, 1))) is Some(_))
  assert_true(model.apply(operation_step("ok", RejectWrite("b", 1))) is None)
}
