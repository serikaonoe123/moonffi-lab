///|
extern "C" fn native_fault(mode : Int) -> Unit = "lab_owned_native_fault"

///|
pub struct Target {
  mode : String
  ordinal : Int
}

///|
pub extend Target with @lab.Adapter::{identity, version, validate, execute, teardown, repair, shrink_arguments}

///|
pub fn Target::new(mode : String, ordinal~ : Int = 0) -> Target { { mode, ordinal } }
///|
pub impl @lab.Adapter for Target with fn identity(_) { "owned-native-errors" }
///|
pub impl @lab.Adapter for Target with fn version(_) { "1" }
///|
pub impl @lab.Adapter for Target with fn validate(_, trace) {
  for step in trace.steps {
    if !["arm", "noise", "fault"].contains(step.op) { return Some("unknown fixture operation") }
    match step.args {
      Number(value, ..) => if value < 0 || value > 64 { return Some("fixture integer out of bounds") }
      _ => return Some("fixture requires integer argument")
    }
  }
  None
}
///|
pub impl @lab.Adapter for Target with fn execute(self, step) {
  if step.op != "fault" { return None }
  let value : Int = try { @json.from_json(step.args) } catch { _ => 0 }
  if self.mode == "correct" ||
    ((self.mode == "flaky-baseline" || self.mode == "asan-flaky-baseline") && self.ordinal == 2) ||
    ((self.mode == "flaky-final" || self.mode == "asan-flaky-final") && self.ordinal > 3) { return None }
  let kind = if self.mode == "asan-weak" { 6 }
    else if self.mode == "weak" { 5 }
    else if self.mode == "asan-b" || (self.mode == "asan" && value == 0) { 4 }
    else if self.mode == "asan" || self.mode == "asan-flaky-baseline" || self.mode == "asan-flaky-final" { 3 }
    else if self.mode == "crash-b" || value == 0 { 2 }
    else { 1 }
  native_fault(kind)
  None
}
///|
pub impl @lab.Adapter for Target with fn teardown(_) { None }
///|
pub impl @lab.Adapter for Target with fn repair(_, trace) { @lab.repair_dependencies(trace) }
///|
pub impl @lab.Adapter for Target with fn shrink_arguments(_, step) {
  if step.op != "fault" { return [] }
  let value : Int = try { @json.from_json(step.args) } catch { _ => return [] }
  @lab.shrink_int(value).filter(v => v >= 0).map(v => { ..step, args: Json(v) })
}
///|
pub fn generate(seed : UInt64, mode : String, count : Int) -> @lab.Trace {
  let steps : Array[@lab.Step] = Array::makei(count, i => {
    id: "s\{i}", op: if i == 0 { "arm" } else if i == count - 1 { "fault" } else { "noise" },
    args: Json(if i == count - 1 { 64 } else { 0 }),
    defines: if i == 0 { ["armed"] } else { [] },
    uses: if i == count - 1 { ["armed"] } else { [] }, releases: [],
  })
  { schema: 1, adapter: "owned-native-errors", adapter_version: "1", generator_version: "native-faults-1",
    seed: seed.to_string(), environment: { "fixture_mode": mode }, steps }
}
