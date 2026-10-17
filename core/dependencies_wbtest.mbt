///| Independent small-input oracle: plain arrays and full prefix reconstruction,
/// with no use of the incremental dependency state or production validator.
fn reference_dependencies(trace : Trace) -> String? {
  if trace.schema != 1 { return Some("unsupported trace schema") }
  if trace.steps.length() > 4096 { return Some("trace exceeds 4096 steps") }
  let ids : Array[String] = []
  let defined : Array[String] = []
  let live : Array[String] = []
  for step in trace.steps {
    if step.id == "" || ids.contains(step.id) { return Some("empty or duplicate step ID: \{step.id}") }
    ids.push(step.id)
    for handle in [..step.uses, ..step.releases] {
      if !live.contains(handle) { return Some("\{step.id}: unavailable handle \{handle}") }
    }
    let released : Array[String] = []
    for handle in step.releases {
      if released.contains(handle) { return Some("\{step.id}: repeated release \{handle}") }
      released.push(handle)
      let remaining = live.filter(value => value != handle)
      live.clear()
      for value in remaining { live.push(value) }
    }
    for handle in step.defines {
      if handle == "" || defined.contains(handle) { return Some("\{step.id}: duplicate or empty handle \{handle}") }
      defined.push(handle)
      live.push(handle)
    }
  }
  None
}

///| Call recording is test instrumentation, not modeled adapter state.
priv struct RejectModel { calls : Array[String] }
///|
impl StateModel for RejectModel with fn apply(self, step) {
  self.calls.push(step.id)
  if step.op == "reject" { Some("model rejected \{step.id}") } else { None }
}

///|
fn reference_repair(model : RejectModel, trace : Trace) -> Repair {
  let kept : Array[Step] = []
  let removed : Array[Removal] = []
  for step in trace.steps {
    kept.push(step)
    let structural = reference_dependencies(trace.with_steps(kept))
    let error = if structural is Some(_) { structural } else { StateModel::apply(model, step) }
    if error is Some(reason) {
      let _ = kept.pop()
      removed.push({ step_id: step.id, reason })
    }
  }
  { trace: trace.with_steps(kept), removed }
}

///|
fn dependency_pattern(pattern : Int, index : Int) -> Step {
  let step = sample_step(if pattern == 8 { "repeat" } else { "s\{index}" })
  match pattern {
    0 => { ..step, id: "" }
    1 => { ..step, defines: ["h"] }
    2 => { ..step, uses: ["h"] }
    3 => { ..step, releases: ["h"] }
    4 => { ..step, defines: ["h", "h"] }
    5 => { ..step, releases: ["h", "h"] }
    6 => { ..step, op: "reject", defines: ["h"] }
    7 => { ..step, op: "reject", releases: ["h"] }
    8 => step
    9 => { ..step, defines: [""] }
    10 => { ..step, defines: ["h"], uses: ["h"] }
    _ => { ..step, defines: ["x"], uses: ["h"] }
  }
}

///|
test "incremental validation and repair match 20736 independent trace oracles" {
  for code = 0; code < 20736; code = code + 1 {
    let mut encoded = code
    let steps : Array[Step] = []
    for index = 0; index < 4; index = index + 1 {
      steps.push(dependency_pattern(encoded % 12, index))
      encoded /= 12
    }
    let trace = sample_trace(steps)
    assert_true(validate_dependencies(trace) == reference_dependencies(trace))
    let reference_model : RejectModel = { calls: [] }
    let model : RejectModel = { calls: [] }
    let expected = reference_repair(reference_model, trace)
    let actual = repair_with_model(model, trace)
    assert_true(actual.trace == expected.trace && actual.removed == expected.removed)
    assert_true(model.calls == reference_model.calls)
  }
}

///|
test "rejected model releases and definitions do not change dependency state" {
  let trace = sample_trace([
    sample_step("new-h", defines=["h"]),
    { ..sample_step("reject-close", releases=["h"]), op: "reject" },
    sample_step("read-h", uses=["h"]),
    { ..sample_step("reject-new", defines=["x"]), op: "reject" },
    sample_step("new-x", defines=["x"]),
    sample_step("read-x", uses=["x"]),
  ])
  let model : RejectModel = { calls: [] }
  let repair = repair_with_model(model, trace)
  assert_true(repair.trace.steps.map(step => step.id) == ["new-h", "read-h", "new-x", "read-x"])
  assert_true(repair.removed.map(removal => removal.step_id) == ["reject-close", "reject-new"])
  assert_true(check_repair(trace, repair) is None)
}

///|
test "late structural rejection leaves releases definitions and step IDs intact" {
  let trace = sample_trace([
    sample_step("new-h", defines=["h"]),
    sample_step("retry", releases=["h"], defines=["x", "x"]),
    sample_step("retry", uses=["h"], defines=["x"]),
    sample_step("read-x", uses=["x"]),
  ])
  let model : RejectModel = { calls: [] }
  let repair = repair_with_model(model, trace)
  assert_true(repair.trace.steps.map(step => step.id) == ["new-h", "retry", "read-x"])
  assert_true(model.calls == ["new-h", "retry", "read-x"])
  assert_true(repair.removed[0].reason == "retry: duplicate or empty handle x")
  // The malformed original contains duplicate IDs; its historical explanation
  // check rejects this ambiguous removal even though structural repair succeeds.
  assert_true(check_repair(trace, repair) == Some("repair has invalid or duplicate removal evidence"))
}

///|
test "availability diagnostics precede repeated release and definition errors" {
  let trace = sample_trace([
    sample_step("new", defines=["h"]),
    sample_step("bad", releases=["h", "h", "missing"], defines=["", ""]),
  ])
  assert_true(validate_dependencies(trace) == Some("bad: unavailable handle missing"))
  assert_true(validate_dependencies(trace.with_steps([
    trace.steps[0], { ..trace.steps[1], releases: ["h", "h"] },
  ])) == Some("bad: repeated release h"))
}

///|
test "schema and length boundaries preserve prefix repair semantics" {
  let model : RejectModel = { calls: [] }
  let trace = { ..sample_trace([sample_step("a")]), schema: 2 }
  let repair = repair_with_model(model, trace)
  assert_true(model.calls.length() == 0 && repair.trace.steps.length() == 0)
  assert_true(repair.removed[0].reason == "unsupported trace schema")
  assert_true(validate_dependencies({ ..trace, steps: [] }) == Some("unsupported trace schema"))
  let long_trace = sample_trace(Array::makei(4097, index => sample_step("s\{index}")))
  assert_true(validate_dependencies(long_trace) == Some("trace exceeds 4096 steps"))
  let model : RejectModel = { calls: [] }
  let repair = repair_with_model(model, long_trace)
  assert_true(repair.trace.steps.length() == 4096 && model.calls.length() == 4096)
  assert_true(repair.removed.length() == 1 && repair.removed[0].reason == "trace exceeds 4096 steps")
  assert_true(check_repair(long_trace, repair) is None)
  let steps = long_trace.steps.copy()
  steps[0] = { ..steps[0], op: "reject" }
  let model : RejectModel = { calls: [] }
  let repair = repair_with_model(model, long_trace.with_steps(steps))
  assert_true(repair.trace.steps.length() == 4096 && repair.trace.steps[4095].id == "s4096")
  assert_true(repair.removed.length() == 1 && repair.removed[0].reason == "model rejected s0")
}

///|
test "indexed removal evidence retains exact historical membership rules" {
  let trace = sample_trace([sample_step("a"), sample_step("b"), sample_step("c")])
  let repaired = trace.with_steps([trace.steps[1]])
  assert_true(check_repair(trace, { trace: repaired, removed: [
    { step_id: "c", reason: "later" }, { step_id: "a", reason: "earlier" },
  ] }) is None)
  assert_true(check_repair(trace, { trace: repaired, removed: [
    { step_id: "a", reason: "first" }, { step_id: "a", reason: "duplicate" },
  ] }) == Some("repair has invalid or duplicate removal evidence"))
  let duplicate = sample_trace([sample_step("same"), sample_step("same")])
  assert_true(check_repair(duplicate, {
    trace: duplicate.with_steps([]), removed: [{ step_id: "same", reason: "one explanation" }],
  }) == Some("repair is missing removal evidence"))
}
