///| These checks use the real Buffer/Eigen executables as fresh workers. The
/// controller only validates traces and generates candidates in the parent.
async fn check_binding_arguments(buffer_executable : String, eigen_executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let buffer_checks : Array[Json] = []
  let input = @buffer.generate(0UL, mode="error", noise=0).with_steps([
    { id: "new", op: "new", args: ["New", "a", "00"], defines: ["a"], uses: [], releases: [] },
    { id: "write", op: "write", args: ["Write", "a", 0, 200], defines: [], uses: ["a"], releases: [] },
    { id: "reject", op: "reject_write", args: ["RejectWrite", "a", 99], defines: [], uses: ["a"], releases: [] },
    { id: "observe", op: "read", args: ["Read", "a"], defines: [], uses: ["a"], releases: [] },
  ])
  @fs.write_file(output + "/buffer-input.json", input.encode())
  for strategy in ["plain", "dependency", "state"] {
    let destination = output + "/buffer-" + strategy
    let adapter = @buffer.BufferAdapter::new()
    adapter.configure(input)
    let controller = @runner.Controller::new(buffer_executable, destination)
    let reduction = controller.shrink(adapter, input, strategy~, budget=200)
    assert_true(reduction.confirmed && reduction.deletion_minimal && reduction.argument_search.unwrap().complete)
    assert_true(reduction.stop_reason == "search_complete" && reduction.argument_search.unwrap().inconclusive_candidates == 0)
    assert_true(reduction.trace.steps.map(step => step.id) == ["new", "write", "reject", "observe"])
    assert_true(reduction.baseline.fingerprint == Some("property:bytes-roundtrip:observe"))
    let mut zero_rejections = 0
    let accepted_values : Array[Int] = []
    let mut previous = 200
    for record in read_ledger(destination) {
      if record.get("phase") != Some(Json("arguments")) { continue }
      let candidate : @lab.Trace = @json.from_json(record.get("candidate").unwrap())
      let write = candidate.steps.filter(step => step.id == "write")[0]
      guard write.args is Array(args) else { fail("expected Buffer operation array") }
      let value : Int = @json.from_json(args[3])
      if value == 0 {
        zero_rejections += 1
        let report : @lab.Report? = @json.from_json(record.get("report").unwrap())
        assert_true(record.get("decision") == Some(Json("rejected")) && report.unwrap().outcome == @lab.Pass)
      } else if record.get("decision") == Some(Json("accepted")) && value != previous {
        assert_true(value < previous)
        accepted_values.push(value)
        previous = value
      }
    }
    assert_true(previous == 1 && zero_rejections > 0)
    assert_true(accepted_values == [100, 50, 25, 13, 7, 4, 2, 1])
    let replays = @runner.Controller::new(buffer_executable, destination + "/independent")
    let replay = replays.run(adapter, reduction.trace)
    assert_true(replay.outcome == @lab.PropertyFailure && replay.fingerprint == reduction.baseline.fingerprint)
    let environment = reduction.trace.environment.copy()
    environment["fixture_mode"] = "correct"
    let corrected = replays.run(adapter, { ..reduction.trace, environment })
    assert_true(corrected.outcome == @lab.Pass)
    // Independently enumerate all proper subsets, without using reducer repair.
    for mask = 0; mask < 15; mask = mask + 1 {
      let steps : Array[@lab.Step] = []
      for index = 0; index < 4; index = index + 1 {
        if (mask & (1 << index)) != 0 { steps.push(reduction.trace.steps[index]) }
      }
      let report = replays.run(adapter, reduction.trace.with_steps(steps))
      assert_true(report.outcome == @lab.Pass || report.outcome == @lab.InvalidCase)
      assert_true(report.fingerprint != reduction.baseline.fingerprint)
    }
    buffer_checks.push({ "strategy": Json(strategy), "executions": Json(reduction.executions),
      "write_value": Json(previous), "zero_rejections": Json(zero_rejections), "accepted_values": Json(accepted_values),
      "confirmed": Json(reduction.confirmed), "deletion_minimal": Json(reduction.deletion_minimal),
      "proper_subsets": Json(15), "corrected_replay": Json("Pass") })
  }
  let eigen_checks : Array[Json] = []
  for sign in [-1, 1] {
    let base = @eigen.generate(0UL, steps=8).with_steps([
      { id: "new", op: "new", args: ["New", "a", 2, 2, Json([9 * sign, -9 * sign, 3 * sign, 0])], defines: ["a"], uses: [], releases: [] },
      { id: "set", op: "set", args: ["Set", "a", 0, 0, Json(7 * sign)], defines: [], uses: ["a"], releases: [] },
      { id: "transpose", op: "transpose", args: ["Transpose", "a", "t"], defines: ["t"], uses: ["a"], releases: [] },
      { id: "identity", op: "new", args: ["New", "b", 2, 2, [1, 0, 0, 1]], defines: ["b"], uses: [], releases: [] },
      { id: "product", op: "mul", args: ["Mul", "t", "b", "c"], defines: ["c"], uses: ["t", "b"], releases: [] },
      { id: "check", op: "check", args: ["Check", "c"], defines: [], uses: ["c"], releases: [] },
    ])
    let adapter = @eigen.EigenAdapter::new()
    let controller = @runner.Controller::new(eigen_executable, output + "/eigen-\{sign}")
    let report = controller.run(adapter, base)
    assert_true(report.outcome == @lab.Pass && report.executed == 6)
    eigen_checks.push({ "sign": Json(sign), "step": Json("baseline"), "candidate": Json(-1), "outcome": Json("Pass"), "executed": Json(report.executed) })
    let mut proposals = 0
    for index = 0; index < base.steps.length(); index = index + 1 {
      let original = base.steps[index]
      let candidates = adapter.shrink_arguments(original)
      for ordinal = 0; ordinal < candidates.length(); ordinal = ordinal + 1 {
        let candidate = candidates[ordinal]
        assert_true({ ..candidate, args: original.args } == original)
        assert_true(@lab.arguments_simpler(candidate.args, original.args))
        let steps = base.steps.copy()
        steps[index] = candidate
        let report = controller.run(adapter, base.with_steps(steps))
        assert_true(report.outcome == @lab.Pass && report.executed == 6)
        proposals += 1
        eigen_checks.push({ "sign": Json(sign), "step": Json(original.id), "candidate": Json(ordinal), "outcome": Json("Pass"), "executed": Json(report.executed) })
      }
    }
    assert_true(proposals == 17 && controller.executions() == 18)
  }
  @fs.write_file(output + "/checks.json", Json({ "buffer": Json(buffer_checks), "eigen": Json(eigen_checks) }).stringify(indent=2))
  println("MoonBit binding argument checks passed: " + output)
}
