///| Deterministic synthetic oracle for reducer boundary tests. No native target
/// or foreign system is accessed. The launch ordinal is taken from case-N.
struct Oracle {
  mode : String
  ordinal : Int
  mut armed : Bool
}

///|
impl @lab.Adapter for Oracle with fn identity(_) { "reducer-oracle" }
///|
impl @lab.Adapter for Oracle with fn version(_) { "1" }
///|
impl @lab.Adapter for Oracle with fn repair(self, trace) {
  if self.mode == "bad-repair" {
    { trace: { ..trace, seed: "silently-rewritten" }, removed: [] }
  } else { @lab.repair_dependencies(trace) }
}
///|
impl @lab.Adapter for Oracle with fn validate(self, trace) {
  for step in trace.steps {
    if !["arm", "noise", "fail"].contains(step.op) { return Some("unknown oracle operation") }
    if self.mode == "numeric" && step.op == "fail" {
      if numeric_args(step) is None { return Some("oracle requires numeric payload") }
      continue
    }
    match step.args {
      String(_) => ()
      _ => return Some("oracle requires string payload")
    }
  }
  None
}
///|
impl @lab.Adapter for Oracle with fn execute(self, step) {
  if step.op == "arm" { self.armed = true }
  if step.op != "fail" || !self.armed { return None }
  if self.mode == "numeric" && numeric_args(step) is Some(args) && args.value == 1 { return None }
  if self.mode == "pass" || (self.mode == "flaky-baseline" && self.ordinal == 2) ||
    (self.mode == "flaky-final" && self.ordinal > 3) { return None }
  let property = if self.mode == "changing-fingerprint" && self.ordinal == 2 { "different" } else { "oracle" }
  Some({ property, step_id: step.id, message: "intentional synthetic reducer failure" })
}
///|
impl @lab.Adapter for Oracle with fn teardown(_) { None }
///|
impl @lab.Adapter for Oracle with fn shrink_arguments(self, step) {
  if step.op != "fail" { return [] }
  if self.mode == "numeric" { return numeric_candidates(step) }
  [
    { ..step, op: "noise", args: Json("") },
    { ..step, uses: ["forged-handle"], args: Json("") },
    { ..step, args: Json(0) },
    { ..step, args: Json("") },
  ]
}

///|
fn generate(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  let operations : Array[@lab.Step] = Array::makei(steps, i => {
    id: "s\{i}", op: if i == 0 { "arm" } else if i == steps - 1 { "fail" } else { "noise" },
    args: Json("long-value-for-reducer-argument-tests"), defines: [], uses: [], releases: [],
  })
  { schema: 1, adapter: "reducer-oracle", adapter_version: "1", generator_version: "oracle-1",
    seed: seed.to_string(), environment: { "fixture_mode": mode }, steps: operations }
}

///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"

///|
async fn main {
  let code = try {
    let arguments = @env.args()
    if arguments.length() == 3 && arguments[1] == "--check-arguments" {
      check_argument_reduction(arguments[0], arguments[2])
      exit_process(0)
    }
    let ordinal = if arguments.length() == 4 && arguments[1] == "--worker" {
      let parts = arguments[3].split("case-").to_array()
      @string.parse_int(parts[parts.length() - 1])
    } else { 0 }
    @runner.cli(arguments, trace => {
      let adapter : Oracle = {
        mode: trace.environment.get("fixture_mode").unwrap_or("stable"), ordinal, armed: false,
      }
      adapter
    }, generate)
  } catch {
    error => { println(error.to_string()); 2 }
  }
  exit_process(code)
}
