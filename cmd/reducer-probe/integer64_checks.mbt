///| Int64's standard ToJson is a string. This synthetic adapter deliberately
/// persists decimal number tokens so the existing exact numeric gate applies.
fn wide_payload(value : Int64, boundary : Int64) -> Json {
  try! @json.parse("[\{value},\{boundary}]")
}

///| Decode the retained decimal representation, never the rounded Double.
fn wide_args(step : @lab.Step) -> (Int64, Int64)? {
  guard step.args is Array(items) && items.length() == 2 else { return None }
  guard items[0] is Number(_, ..) && items[1] is Number(_, ..) else { return None }
  let text = items[0].stringify()
  let bound = items[1].stringify()
  let value = try { @string.parse_int64(text[:]) } catch { _ => return None }
  let boundary = try { @string.parse_int64(bound[:]) } catch { _ => return None }
  Some((value, boundary))
}

///|
fn wide_trace(value : Int64, boundary : Int64) -> @lab.Trace {
  { schema: 1, adapter: "reducer-oracle", adapter_version: "1", generator_version: "integer64-oracle-1",
    seed: "0", environment: { "fixture_mode": "integer64-threshold" }, steps: [
      { id: "arm", op: "arm", args: Json(""), defines: ["h"], uses: [], releases: [] },
      { id: "fail", op: "fail", args: wide_payload(value, boundary), defines: [], uses: ["h"], releases: [] },
    ] }
}

///| Real subprocess reductions cross the Double precision boundary and both
/// signed limits. The worker independently compares signed threshold values.
async fn check_wide_reduction(executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    for sample in [(200L, 73L), (-200L, -73L),
      (9007199254740993L, 9007199254740992L), (-9007199254740993L, -9007199254740992L),
      (9223372036854775807L, 9223372036854775806L), (-9223372036854775808L, -9223372036854775807L)] {
      let (initial, boundary) = sample
      let trace = wide_trace(initial, boundary)
      assert_true(@lab.decode_trace(trace.encode()) == trace)
      let destination = output + "/\{strategy}-\{initial}"
      let adapter : Oracle = { mode: "integer64-threshold", ordinal: 0, armed: false, arm_value: 0, blocker: false }
      let controller = @runner.Controller::new(executable, destination)
      let reduction = controller.shrink(adapter, trace, strategy~, budget=200)
      let progress = reduction.argument_search.unwrap()
      assert_true(reduction.confirmed && reduction.deletion_minimal && progress.complete)
      assert_true(reduction.stop_reason == "search_complete" && progress.inconclusive_candidates == 0)
      assert_true(reduction.baseline_checks == 3 && reduction.final_checks == 3)
      assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
      let saved = @lab.decode_trace(@fs.read_file(destination + "/reduced.json").text())
      assert_true(saved == reduction.trace && wide_args(saved.steps[1]) == Some((boundary, boundary)))
      let mut executed = 0
      let mut passing = 0
      let mut accepted = 0
      let mut previous = initial
      for record in read_ledger(destination) {
        let report : @lab.Report? = @json.from_json(record.get("report").unwrap())
        if report is Some(_) { executed += 1 }
        if record.get("phase") != Some(Json("arguments")) { continue }
        let candidate : @lab.Trace = @json.from_json(record.get("candidate").unwrap())
        assert_true(candidate.steps.length() == 2)
        assert_true({ ..candidate.steps[1], args: trace.steps[1].args } == trace.steps[1])
        let (value, threshold) = wide_args(candidate.steps[1]).unwrap()
        assert_true(threshold == boundary && @lab.arguments_simpler(wide_payload(value, threshold), wide_payload(previous, boundary)))
        if (boundary < 0L && value > boundary) || (boundary > 0L && value < boundary) {
          passing += 1
          assert_true(report.unwrap().outcome == @lab.Pass && record.get("decision") == Some(Json("rejected")))
        } else {
          accepted += 1
          assert_true(report.unwrap().outcome == @lab.PropertyFailure && record.get("decision") == Some(Json("accepted")))
          previous = value
        }
      }
      assert_true(executed == reduction.executions && passing > 0 && accepted > 0 && previous == boundary)
      let independent = @runner.Controller::new(executable, destination + "/independent")
      let replay = independent.run(adapter, saved)
      assert_true(replay.outcome == @lab.PropertyFailure && replay.fingerprint == reduction.baseline.fingerprint)
      let environment = saved.environment.copy()
      environment["fixture_mode"] = "integer64-pass"
      let control = independent.run(adapter, { ..saved, environment })
      assert_true(control.outcome == @lab.Pass)
      checks.push({ "strategy": Json(strategy), "initial": Json(initial), "boundary": Json(boundary),
        "result": Json(previous), "bounded": false, "executions": Json(reduction.executions),
        "passing_candidates": Json(passing), "accepted_candidates": Json(accepted),
        "confirmed": true, "complete": true, "independent_replay": true, "pass_control": true })
    }
    let trace = wide_trace(9007199254740993L, 9007199254740992L)
    let adapter : Oracle = { mode: "integer64-threshold", ordinal: 0, armed: false, arm_value: 0, blocker: false }
    let controller = @runner.Controller::new(executable, output + "/bounded-" + strategy)
    let bounded = controller.shrink(adapter, trace, strategy~, budget=6)
    assert_true(bounded.confirmed && bounded.executions == 6 && bounded.trace == trace)
    assert_true(bounded.stop_reason == "execution_budget" && !bounded.deletion_minimal && !bounded.argument_search.unwrap().complete)
    checks.push({ "strategy": Json(strategy), "initial": Json(9007199254740993L), "bounded": true,
      "executions": Json(bounded.executions), "confirmed": Json(bounded.confirmed), "complete": false,
      "stop_reason": Json(bounded.stop_reason) })
  }
  @fs.write_file(output + "/checks.json", Json(checks).stringify(indent=2))
  println("MoonBit Int64 candidate checks passed: " + output)
}
