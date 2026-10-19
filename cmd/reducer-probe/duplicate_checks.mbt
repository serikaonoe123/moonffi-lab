///| Repeat passing candidates before a useful change, and separately repeat
/// inconclusive candidates. Coupled steps share payloads to expose accidental
/// reuse across step identities or after accepted trace changes.
fn duplicate_candidates(mode : String, step : @lab.Step) -> Array[@lab.Step] {
  if step.op != "fail" && !(mode == "duplicate-coupled" && step.op == "arm") { return [] }
  let args = numeric_args(step).unwrap()
  if args.value == 0 { return [] }
  let value = if mode == "duplicate-coupled" { 0 } else { 1 }
  let candidate = { ..step, args: { ..args, value }.to_json() }
  let candidates = Array::make(if mode == "duplicate" { 8 } else { 2 }, candidate)
  if mode == "duplicate" { candidates.push({ ..step, args: { ..args, value: 0 }.to_json() }) }
  candidates
}

///| These are controller/worker checks, not a simulation of the cache. Count
/// actual ledger reports and require three final confirmations within budget.
async fn check_duplicate_reduction(executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    for mode in ["duplicate", "duplicate-error", "duplicate-coupled"] {
      let base = iterative_trace(if mode == "duplicate-coupled" { "coupled" } else { "chain" })
      let trace = { ..base, environment: { "fixture_mode": mode } }
      let destination = output + "/" + mode + "-" + strategy
      let adapter : Oracle = { mode, ordinal: 0, armed: false, arm_value: 0, blocker: false }
      let controller = @runner.Controller::new(executable, destination)
      let reduction = controller.shrink(adapter, trace, strategy~, budget=if mode == "duplicate" { 12 } else { 100 })
      let progress = reduction.argument_search.unwrap()
      assert_true(reduction.confirmed && reduction.final_checks == 3)
      assert_true(reduction.deletion_minimal && progress.complete && reduction.stop_reason == "search_complete")
      assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
      let mut executions = 0
      let mut argument_executions = 0
      let arm_attempts : Array[String] = []
      let accepted_ids : Array[String] = []
      for record in read_ledger(destination) {
        let report : @lab.Report? = @json.from_json(record.get("report").unwrap())
        if report is Some(_) { executions += 1 }
        if record.get("phase") != Some(Json("arguments")) { continue }
        argument_executions += 1
        let candidate : @lab.Trace = @json.from_json(record.get("candidate").unwrap())
        if mode == "duplicate-coupled" {
          if numeric_args(candidate.steps[0]).unwrap().value == 0 {
            // The same arm payload must be retried in three distinct contexts:
            // before/after changing fail, then after deleting the blocker.
            let failure = candidate.steps[candidate.steps.length() - 1]
            arm_attempts.push("\{candidate.steps.length()}:\{numeric_args(failure).unwrap().value}")
            if record.get("decision") == Some(Json("accepted")) { accepted_ids.push("arm") }
          } else {
            assert_true(record.get("decision") == Some(Json("accepted")))
            accepted_ids.push("fail")
          }
        } else if mode == "duplicate-error" {
          assert_true(report.unwrap().outcome == @lab.HarnessError)
        } else {
          let value = numeric_args(candidate.steps[1]).unwrap().value
          assert_true((value == 1 && report.unwrap().outcome == @lab.Pass) ||
            (value == 0 && record.get("decision") == Some(Json("accepted"))))
        }
      }
      assert_true(executions == reduction.executions)
      let final_value = numeric_args(reduction.trace.steps[1]).unwrap().value
      if mode == "duplicate" {
        assert_true(final_value == 0 && reduction.executions <= 12 && argument_executions == 2)
        assert_true(progress.inconclusive_candidates == 0)
      } else if mode == "duplicate-error" {
        assert_true(final_value == 9 && argument_executions == 2 && progress.inconclusive_candidates == 2)
      } else {
        assert_true(final_value == 0 && numeric_args(reduction.trace.steps[0]).unwrap().value == 0)
        assert_true(argument_executions == 4 && arm_attempts == ["3:9", "3:0", "2:0"])
        assert_true(accepted_ids == ["fail", "arm"] && progress.inconclusive_candidates == 0)
      }
      checks.push({ "mode": Json(mode), "strategy": Json(strategy), "executions": Json(reduction.executions),
        "argument_executions": Json(argument_executions), "value": Json(final_value),
        "inconclusive_candidates": Json(progress.inconclusive_candidates), "arm_contexts": Json(arm_attempts),
        "confirmed": Json(reduction.confirmed), "complete": Json(progress.complete) })
    }
  }
  @fs.write_file(output + "/checks.json", Json(checks).stringify(indent=2))
  println("MoonBit duplicate candidate checks passed: " + output)
}
