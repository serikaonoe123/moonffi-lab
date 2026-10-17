///| Duplicate, reverse and forged-operation proposals surround a one-level
/// simplification. Reaching zero requires asking the adapter again each time.
fn chain_candidates(step : @lab.Step) -> Array[@lab.Step] {
  let args = numeric_args(step).unwrap()
  let candidates = [step]
  if args.value != 0 {
    candidates.push({ ..step, args: { ..args, value: args.value / 2 }.to_json() })
  }
  candidates.push({ ..step, op: "noise", args: Json("") })
  candidates.push({ ..step, args: { ..args, value: 9 }.to_json() })
  candidates
}

///|
fn iterative_trace(mode : String) -> @lab.Trace {
  let payload : NumericArgs = { value: 9, guard_value: 0, label: "fixed" }
  let arm : @lab.Step = {
    id: "arm", op: "arm", args: if mode == "coupled" { payload.to_json() } else { Json("") },
    defines: ["h"], uses: [], releases: [],
  }
  let noise : @lab.Step = { id: "blocker", op: "noise", args: Json(""), defines: [], uses: [], releases: [] }
  let failure : @lab.Step = { id: "fail", op: "fail", args: payload.to_json(), defines: [], uses: ["h"], releases: [] }
  let steps = match mode {
    "coupled" => [arm, noise, failure]
    "repair-shift" => [noise, arm, failure]
    _ => [arm, failure]
  }
  { schema: 1, adapter: "reducer-oracle", adapter_version: "1", generator_version: "iterative-oracle-1",
    seed: "0", environment: { "fixture_mode": mode }, steps }
}

///|
async fn read_ledger(output : String) -> Array[Map[String, Json]] {
  let text = @fs.read_file(output + "/reduction-events.jsonl").text()
  let records : Array[Map[String, Json]] = []
  for line in text.split("\n") {
    if line != "" {
      guard @json.parse(line) is Object(fields) else { fail("expected reduction event") }
      records.push(fields)
    }
  }
  records
}

///| All assertions run in MoonBit against real subprocess execution evidence.
async fn check_iterative_reduction(executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    for mode in ["chain", "coupled"] {
      let destination = output + "/" + mode + "-" + strategy
      let controller = @runner.Controller::new(executable, destination)
      let adapter : Oracle = { mode, ordinal: 0, armed: false, arm_value: 0, blocker: false }
      let reduction = controller.shrink(adapter, iterative_trace(mode), strategy~, budget=100)
      let progress = reduction.argument_search.unwrap()
      assert_true(reduction.confirmed && reduction.deletion_minimal && progress.complete)
      assert_true(reduction.stop_reason == "search_complete" && progress.inconclusive_candidates == 0)
      assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
      assert_true(numeric_args(reduction.trace.steps[1]).unwrap().value == 0)
      let ledger = read_ledger(destination)
      let accepted_values : Array[Int] = []
      let accepted_ids : Array[String] = []
      let accepted_phases : Array[String] = []
      let mut previous = iterative_trace(mode)
      let mut executed = 0
      for record in ledger {
        let report : @lab.Report? = @json.from_json(record.get("report").unwrap())
        if report is Some(_) { executed += 1 }
        if record.get("decision") != Some(Json("accepted")) { continue }
        let candidate : @lab.Trace = @json.from_json(record.get("candidate").unwrap())
        let phase : String = @json.from_json(record.get("phase").unwrap())
        accepted_phases.push(phase)
        if phase == "arguments" {
          // Identify the changed payload independently from the previous
          // accepted concrete trace, including intervening step deletions.
          if mode == "chain" {
            accepted_ids.push("fail")
            accepted_values.push(numeric_args(candidate.steps[candidate.steps.length() - 1]).unwrap().value)
          } else {
            for step in candidate.steps {
              if step.op != "arm" && step.op != "fail" { continue }
              let original = previous.steps.filter(old => old.id == step.id)[0]
              if numeric_args(step).unwrap().value != numeric_args(original).unwrap().value {
                accepted_ids.push(step.id)
              }
            }
          }
        }
        previous = candidate
      }
      assert_true(executed == reduction.executions)
      if mode == "chain" {
        assert_true(accepted_values == [4, 2, 1, 0])
        assert_true(progress.passes == 5)
      } else {
        assert_true(accepted_ids == ["fail", "arm"])
        assert_true(accepted_phases == ["arguments", "delete_single", "arguments"])
        assert_true(numeric_args(reduction.trace.steps[0]).unwrap().value == 0)
        assert_true(progress.passes == 4)
      }
      checks.push({ "mode": Json(mode), "strategy": Json(strategy), "passes": Json(progress.passes),
        "executions": Json(reduction.executions), "complete": Json(progress.complete),
        "accepted_values": Json(accepted_values), "accepted_ids": Json(accepted_ids) })
    }
    // This budget permits a strict prefix of the chain, then exactly three
    // final confirmations. A stable partial result must not claim completion.
    let mode = "chain"
    let destination = output + "/bounded-" + strategy
    let adapter : Oracle = { mode, ordinal: 0, armed: false, arm_value: 0, blocker: false }
    let controller = @runner.Controller::new(executable, destination)
    let reduction = controller.shrink(adapter, iterative_trace(mode), strategy~, budget=10)
    assert_true(reduction.confirmed && reduction.executions == 10 && reduction.final_checks == 3)
    assert_true(reduction.stop_reason == "execution_budget")
    assert_true(!reduction.argument_search.unwrap().complete && !reduction.neighborhood_complete && !reduction.deletion_minimal)
    let value = numeric_args(reduction.trace.steps[1]).unwrap().value
    assert_true(value > 0 && value < 9)
    checks.push({ "mode": "bounded-chain", "strategy": Json(strategy), "executions": Json(reduction.executions),
      "value": Json(value), "stop_reason": Json(reduction.stop_reason) })
  }
  for mode in ["repair-shift", "argument-error"] {
    let destination = output + "/" + mode
    let adapter : Oracle = { mode, ordinal: 0, armed: false, arm_value: 0, blocker: false }
    let controller = @runner.Controller::new(executable, destination)
    let reduction = controller.shrink(adapter, iterative_trace(mode), budget=100)
    let progress = reduction.argument_search.unwrap()
    assert_true(reduction.confirmed && reduction.deletion_minimal && progress.complete)
    let ledger = read_ledger(destination)
    if mode == "repair-shift" {
      assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
      assert_true(numeric_args(reduction.trace.steps[1]).unwrap().value == 0)
      assert_true(ledger.any(record => record.get("phase") == Some(Json("arguments")) &&
        record.get("decision") == Some(Json("accepted")) && record.get("repair_removals") is Some(Array([_]))) )
    } else {
      assert_true(numeric_args(reduction.trace.steps[1]).unwrap().value == 9)
      assert_true(progress.inconclusive_candidates == 1)
      assert_true(ledger.any(record => record.get("phase") == Some(Json("arguments")) &&
        record.get("decision") == Some(Json("rejected"))))
    }
    checks.push({ "mode": Json(mode), "complete": Json(progress.complete),
      "inconclusive_candidates": Json(progress.inconclusive_candidates), "executions": Json(reduction.executions) })
  }
  @fs.write_file(output + "/checks.json", Json(checks).stringify(indent=2))
  println("MoonBit iterative reduction checks passed: " + output)
}
