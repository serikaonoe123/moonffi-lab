///| An adapter's pure transition must leave the model unchanged on rejection.
pub(open) trait StateModel {
  apply(Self, Step) -> String?
}

///|
pub(all) struct Removal {
  step_id : String
  reason : String
} derive(Eq, ToJson, @json.FromJson)

///|
pub(all) struct Repair {
  trace : Trace
  removed : Array[Removal]
} derive(ToJson, @json.FromJson)

///| Repair only by deletion, preserving order, concrete inputs and metadata.
/// This guard prevents an adapter from silently rewriting the tested scenario.
pub fn deletion_only(original : Trace, repaired : Trace) -> Bool {
  if original.with_steps(repaired.steps) != repaired { return false }
  let mut cursor = 0
  for step in repaired.steps {
    while cursor < original.steps.length() && original.steps[cursor] != step { cursor += 1 }
    if cursor == original.steps.length() { return false }
    cursor += 1
  }
  true
}

///| Verify the repair's explanation covers exactly the skipped concrete steps.
pub fn check_repair(original : Trace, repair : Repair) -> String? {
  if !deletion_only(original, repair.trace) { return Some("repair changed metadata, order or concrete operations") }
  let kept = repair.trace.steps.map(s => s.id)
  let skipped = original.steps.filter(s => !kept.contains(s.id)).map(s => s.id)
  let seen : Map[String, Bool] = Map([])
  for removal in repair.removed {
    if !skipped.contains(removal.step_id) || seen.contains(removal.step_id) || removal.reason == "" {
      return Some("repair has invalid or duplicate removal evidence")
    }
    seen[removal.step_id] = true
  }
  if seen.length() != skipped.length() { return Some("repair is missing removal evidence") }
  None
}

///| Check dependencies on each retained prefix, advancing the supplied fresh
/// model only on accepted transitions. A rejected transition must not mutate it.
/// Prefix validation is quadratic in trace length (bounded by the trace limit).
pub fn[M : StateModel] repair_with_model(model : M, trace : Trace) -> Repair {
  let kept : Array[Step] = []
  let removed : Array[Removal] = []
  for step in trace.steps {
    kept.push(step)
    let structural = validate_dependencies(trace.with_steps(kept))
    let rejection = if structural is Some(_) { structural } else { model.apply(step) }
    if rejection is Some(reason) {
      let _ = kept.pop()
      removed.push({ step_id: step.id, reason })
    }
  }
  { trace: trace.with_steps(kept), removed }
}

///|
priv struct DependencyModel {}
///|
impl StateModel for DependencyModel with fn apply(_, _) { None }

///| Safe fallback for adapters with no additional semantic repair rules.
pub fn repair_dependencies(trace : Trace) -> Repair {
  repair_with_model(DependencyModel::{}, trace)
}

///|
#deprecated
pub extend Removal with Eq::{equal, not_equal}
///|
pub extend Removal with ToJson::{to_json}
///|
#deprecated
pub extend Removal with @json.FromJson::{from_json}
///|
pub extend Repair with ToJson::{to_json}
///|
#deprecated
pub extend Repair with @json.FromJson::{from_json}
