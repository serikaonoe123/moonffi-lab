///| This synthetic payload gives each proposed change an independent purpose:
/// decreasing one component cannot compensate for increasing another.
struct NumericArgs {
  value : Int
  guard_value : Int
  label : String
} derive(ToJson, @json.FromJson)

///|
extend NumericArgs with ToJson::{to_json}

///|
fn numeric_args(step : @lab.Step) -> NumericArgs? {
  try { Some(@json.from_json(step.args)) } catch { _ => None }
}

///|
fn numeric_candidates(step : @lab.Step) -> Array[@lab.Step] {
  let args = numeric_args(step).unwrap()
  [
    { ..step, args: { ..args, value: 0, guard_value: 9 }.to_json() },
    { ..step, args: { ..args, value: 1 }.to_json() },
    { ..step, args: { ..args, value: 0 }.to_json() },
    { ..step, args: { ..args, value: 8 }.to_json() },
    { ..step, args: { ..args, value: 0 }.to_json() },
    { ..step, args: { ..args, value: -1 }.to_json() },
  ]
}

///| Run real subprocess reductions and inspect their ledger in MoonBit. The
/// shell only launches this command; assertions and evidence stay with the probe.
async fn check_argument_reduction(executable : String, output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let args : NumericArgs = { value: 9, guard_value: 0, label: "fixed" }
  let trace : @lab.Trace = {
    schema: 1, adapter: "reducer-oracle", adapter_version: "1",
    generator_version: "numeric-oracle-1", seed: "0",
    environment: { "fixture_mode": "numeric" },
    steps: [
      { id: "arm", op: "arm", args: Json(""), defines: [], uses: [], releases: [] },
      { id: "fail", op: "fail", args: args.to_json(), defines: [], uses: [], releases: [] },
    ],
  }
  @fs.write_file(output + "/input.json", trace.encode())
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    let destination = output + "/" + strategy
    let adapter : Oracle = { mode: "numeric", ordinal: 0, armed: false }
    let controller = @runner.Controller::new(executable, destination)
    let reduction = controller.shrink(adapter, trace, strategy~, budget=100)
    assert_true(reduction.confirmed && reduction.deletion_minimal)
    assert_true(reduction.stop_reason == "search_complete")
    assert_true(reduction.baseline_checks == 3 && reduction.final_checks == 3)
    assert_true(reduction.trace.steps.map(step => step.id) == ["arm", "fail"])
    let final_args = numeric_args(reduction.trace.steps[1]).unwrap()
    assert_true(final_args.value == 0 && final_args.guard_value == 0 && final_args.label == "fixed")
    let ledger = @fs.read_file(destination + "/reduction-events.jsonl").text()
    let mut argument_executions = 0
    let mut accepted = 0
    let mut rejected = 0
    for line in ledger.split("\n") {
      if line == "" { continue }
      let record = @json.parse(line)
      guard record is Object(fields) else { fail("expected ledger object") }
      if fields.get("phase") != Some(Json("arguments")) { continue }
      argument_executions += 1
      let candidate : @lab.Trace = @json.from_json(fields.get("candidate").unwrap())
      let proposed = numeric_args(candidate.steps[1]).unwrap()
      // A compensated increase, stale 8, duplicate 0, or longer -1 must never
      // reach a worker. Value 1 passes and must be rejected; value 0 still fails.
      assert_true(proposed.guard_value == 0 && proposed.label == "fixed")
      match proposed.value {
        1 => {
          rejected += 1
          assert_true(fields.get("decision") == Some(Json("rejected")))
        }
        0 => {
          accepted += 1
          assert_true(fields.get("decision") == Some(Json("accepted")))
        }
        _ => fail("non-descending parameter candidate reached a worker")
      }
      let optional_report : @lab.Report? = @json.from_json(fields.get("report").unwrap())
      let report = optional_report.unwrap()
      let expected = if proposed.value == 1 { @lab.Pass } else { @lab.PropertyFailure }
      assert_true(report.outcome == expected)
    }
    assert_true(argument_executions == 2 && accepted == 1 && rejected == 1)
    checks.push({
      "strategy": Json(strategy), "confirmed": Json(reduction.confirmed),
      "deletion_minimal": Json(reduction.deletion_minimal),
      "argument_executions": Json(argument_executions),
      "accepted_value": Json(final_args.value), "executions": Json(reduction.executions),
    })
  }
  let controller = @runner.Controller::new(executable, output + "/budget-six")
  let adapter : Oracle = { mode: "numeric", ordinal: 0, armed: false }
  let bounded = controller.shrink(adapter, trace, budget=6)
  assert_true(bounded.executions == 6 && bounded.confirmed)
  assert_true(bounded.stop_reason == "execution_budget" && !bounded.deletion_minimal)
  assert_true(bounded.trace.encode() == trace.encode())
  checks.push({ "budget": Json(6), "executions": Json(bounded.executions), "stop_reason": Json(bounded.stop_reason) })
  @fs.write_file(output + "/checks.json", Json(checks).stringify(indent=2))
  println("MoonBit argument reduction checks passed: " + output)
}
