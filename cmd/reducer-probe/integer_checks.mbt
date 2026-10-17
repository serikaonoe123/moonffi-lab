///| Real subprocess checks for the reusable core candidate generator. The
/// worker's widened threshold predicate is independent of candidate generation.
/// Both the passing side and the accepted boundary must appear in the ledger.
async fn check_integer_reduction(executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    for sample in [(200, 73), (-200, 73), (9, 7), (-9, 7), (2147483647, 2147483646), (-2147483648, 2147483647)] {
      let (initial, threshold) = sample
      let mode = "integer-threshold"
      let args : NumericArgs = { value: initial, guard_value: threshold, label: "fixed" }
      let trace : @lab.Trace = {
        schema: 1, adapter: "reducer-oracle", adapter_version: "1", generator_version: "integer-oracle-1",
        seed: "0", environment: { "fixture_mode": mode }, steps: [
          { id: "arm", op: "arm", args: Json(""), defines: ["h"], uses: [], releases: [] },
          { id: "fail", op: "fail", args: args.to_json(), defines: [], uses: ["h"], releases: [] },
        ],
      }
      let destination = output + "/\{strategy}-\{initial}"
      let adapter : Oracle = { mode, ordinal: 0, armed: false, arm_value: 0, blocker: false }
      let controller = @runner.Controller::new(executable, destination)
      let reduction = controller.shrink(adapter, trace, strategy~, budget=200)
      let progress = reduction.argument_search.unwrap()
      assert_true(reduction.confirmed && reduction.deletion_minimal && progress.complete)
      assert_true(reduction.stop_reason == "search_complete" && progress.inconclusive_candidates == 0)
      assert_true(reduction.baseline_checks == 3 && reduction.final_checks == 3)
      assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
      let expected = if initial < 0 { -threshold } else { threshold }
      let result = numeric_args(reduction.trace.steps[1]).unwrap()
      assert_true(result.value == expected && result.guard_value == threshold && result.label == "fixed")
      let mut previous = initial
      let mut executed = 0
      let mut passing = 0
      let mut accepted = 0
      for record in read_ledger(destination) {
        let report : @lab.Report? = @json.from_json(record.get("report").unwrap())
        if report is Some(_) { executed += 1 }
        if record.get("phase") != Some(Json("arguments")) { continue }
        let candidate : @lab.Trace = @json.from_json(record.get("candidate").unwrap())
        assert_true(candidate.steps.length() == 2)
        let proposed = numeric_args(candidate.steps[1]).unwrap()
        assert_true(proposed.guard_value == threshold && proposed.label == "fixed")
        assert_true({ ..candidate.steps[1], args: trace.steps[1].args } == trace.steps[1])
        assert_true(@lab.arguments_simpler(Json(proposed.value), Json(previous)))
        let value = proposed.value.to_int64()
        let magnitude = if value < 0L { -value } else { value }
        if magnitude < threshold.to_int64() {
          passing += 1
          assert_true(record.get("decision") == Some(Json("rejected")) && report.unwrap().outcome == @lab.Pass)
        } else {
          accepted += 1
          assert_true(record.get("decision") == Some(Json("accepted")) && report.unwrap().outcome == @lab.PropertyFailure)
          previous = proposed.value
        }
      }
      assert_true(executed == reduction.executions && passing > 0 && accepted > 0 && previous == expected)
      checks.push({ "strategy": Json(strategy), "initial": Json(initial), "threshold": Json(threshold),
        "result": Json(result.value), "executions": Json(reduction.executions), "passing_candidates": Json(passing),
        "accepted_candidates": Json(accepted), "complete": Json(progress.complete), "confirmed": Json(reduction.confirmed) })
    }
  }
  @fs.write_file(output + "/checks.json", Json(checks).stringify(indent=2))
  println("MoonBit integer candidate checks passed: " + output)
}
