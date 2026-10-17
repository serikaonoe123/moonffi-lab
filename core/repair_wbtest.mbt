///|
test "repair cannot rewrite inputs, metadata or operation order" {
  let trace = sample_trace([sample_step("a"), sample_step("b"), sample_step("c")])
  assert_true(deletion_only(trace, trace.with_steps([trace.steps[0], trace.steps[2]])))
  assert_true(!deletion_only(trace, { ..trace, seed: "different" }))
  assert_true(!deletion_only(trace, trace.with_steps([trace.steps[1], trace.steps[0]])))
  assert_true(!deletion_only(trace, trace.with_steps([{ ..trace.steps[0], args: Json(1) }])))
}

///|
test "every skipped step requires one nonempty explanation" {
  let trace = sample_trace([sample_step("a"), sample_step("b")])
  let repaired = trace.with_steps([trace.steps[1]])
  assert_true(check_repair(trace, { trace: repaired, removed: [{ step_id: "a", reason: "precondition" }] }) is None)
  assert_true(check_repair(trace, { trace: repaired, removed: [] }) is Some(_))
  assert_true(check_repair(trace, { trace: repaired, removed: [{ step_id: "b", reason: "wrong" }] }) is Some(_))
  assert_true(check_repair(trace, { trace: repaired, removed: [{ step_id: "a", reason: "" }] }) is Some(_))
}

///|
test "dependency repair matches deletion closure for every constructor removal" {
  let trace = sample_trace([
    sample_step("new-a", defines=["a"]), sample_step("share-b", uses=["a"], defines=["b"]),
    sample_step("new-x", defines=["x"]), sample_step("close-a", releases=["a"]),
    sample_step("read-b", uses=["b"]), sample_step("read-x", uses=["x"]),
  ])
  for start = 0; start < trace.steps.length(); start = start + 1 {
    let raw : Array[Step] = []
    for i, step in trace.steps { if i != start { raw.push(step) } }
    let proposal = trace.with_steps(raw)
    let repair = repair_dependencies(proposal)
    assert_true(repair.trace == delete_block(trace, start, 1))
    assert_true(check_repair(proposal, repair) is None)
    assert_true(validate_dependencies(repair.trace) is None)
  }
}
