///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"

///| Execute actual disposable native workers; every assertion keeps its logs.
async fn check_native(executable : String, output : String, mode : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let trace = @faults.generate(0UL, mode, 32)
  @fs.write_file(output + "/input.json", trace.encode())
  let checks : Array[Json] = []
  for strategy in ["plain", "dependency", "state"] {
    let target = @faults.Target::new(mode)
    let controller = @runner.Controller::new(executable, output + "/" + strategy, native_errors=true, timeout_ms=10000)
    let result = controller.shrink(target, trace, strategy~, budget=150, wall_ms=180000)
    assert_true(result.confirmed && result.deletion_minimal)
    assert_true(result.baseline_checks == 3 && result.final_checks == 3)
    assert_true(result.reduced_steps == 2 && result.trace.steps[1].args == Json(1))
    let expected_outcome : @lab.Outcome = if mode == "asan" { MemoryError } else { Crash }
    assert_true(result.baseline.outcome == expected_outcome)
    let replay = @runner.Controller::new(executable, output + "/replay-" + strategy, native_errors=true, timeout_ms=10000)
    let replayed = replay.run(target, result.trace)
    assert_true(replayed.outcome == result.baseline.outcome && replayed.fingerprint == result.baseline.fingerprint)
    let other_mode = if mode == "asan" { "asan-b" } else { "crash-b" }
    let other_env = trace.environment.copy()
    other_env["fixture_mode"] = other_mode
    let other_trace = { ..result.trace, environment: other_env }
    let other = replay.run(@faults.Target::new(other_mode), other_trace)
    assert_true(other.outcome == result.baseline.outcome && other.fingerprint is Some(_) && other.fingerprint != result.baseline.fingerprint)
    let correct_env = trace.environment.copy()
    correct_env["fixture_mode"] = "correct"
    let correct = replay.run(@faults.Target::new("correct"), { ..result.trace, environment: correct_env })
    assert_true(correct.outcome == Pass)
    checks.push({ "strategy": strategy, "reduction": result.to_json(), "replay": replayed.to_json(),
      "different_site": other.to_json(), "correct": correct.to_json() })
  }
  if mode == "crash" {
    for label in ["flaky-baseline", "flaky-final", "weak"] {
      let input = @faults.generate(0UL, label, 32)
      let controller = @runner.Controller::new(executable, output + "/" + label, native_errors=true)
      let result = controller.shrink(@faults.Target::new(label), input, budget=6)
      let expected = if label == "flaky-baseline" { "unstable_baseline" }
        else if label == "flaky-final" { "unstable_final" } else { "unsupported_outcome" }
      assert_true(!result.confirmed && result.stop_reason == expected)
      checks.push({ "control": label, "result": result.to_json() })
    }
    let controller = @runner.Controller::new(executable, output + "/budget", native_errors=true)
    let limited = controller.shrink(@faults.Target::new(mode), trace, budget=6)
    assert_true(limited.executions == 6 && limited.confirmed && limited.stop_reason == "execution_budget" && !limited.deletion_minimal)
    checks.push({ "control": "budget", "result": limited.to_json() })
    let legacy = @runner.Controller::new(executable, output + "/disabled")
    let disabled = legacy.shrink(@faults.Target::new(mode), trace)
    assert_true(!disabled.confirmed && disabled.stop_reason == "unsupported_outcome")
    checks.push({ "control": "disabled", "result": disabled.to_json() })
  }
  let verification : Json = { "state": "passed", "mode": mode, "checks": checks }
  @fs.write_file(output + "/verification.json", verification.stringify(indent=2))
}

///|
async fn main {
  let code = try {
    let args = @env.args()
    if args.length() == 4 && args[1] == "--self-check" {
      check_native(args[0], args[3], args[2])
      0
    } else {
      let ordinal = if args.length() == 4 && args[1] == "--worker" {
        let parts = args[3].split("case-").to_array()
        @string.parse_int(parts[parts.length() - 1])
      } else { 0 }
      @runner.cli(args, trace => @faults.Target::new(trace.environment.get("fixture_mode").unwrap_or("correct"), ordinal~),
        @faults.generate, native_errors=true)
    }
  } catch { error => { println(error.to_string()); 2 } }
  exit_process(code)
}
