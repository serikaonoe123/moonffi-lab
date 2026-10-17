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
  if original.with_steps([]) != repaired.with_steps([]) { return false }
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
  let kept : Map[String, Bool] = Map([])
  for step in repair.trace.steps { kept[step.id] = true }
  let skipped : Map[String, Bool] = Map([])
  let mut skipped_count = 0
  for step in original.steps {
    if !kept.contains(step.id) { skipped[step.id] = true; skipped_count += 1 }
  }
  let seen : Map[String, Bool] = Map([])
  for removal in repair.removed {
    if !skipped.contains(removal.step_id) || seen.contains(removal.step_id) || removal.reason == "" {
      return Some("repair has invalid or duplicate removal evidence")
    }
    seen[removal.step_id] = true
  }
  if seen.length() != skipped_count { return Some("repair is missing removal evidence") }
  None
}

///| Check dependencies on each retained prefix, advancing the supplied fresh
/// model only on accepted transitions. Structural changes commit after model
/// acceptance; a rejected transition must still leave the adapter model intact.
/// Dependency work is linear in steps and handle mentions on average with maps.
pub fn[M : StateModel] repair_with_model(model : M, trace : Trace) -> Repair {
  let dependencies = DependencyState::new(trace.schema)
  let kept : Array[Step] = []
  let removed : Array[Removal] = []
  for step in trace.steps {
    let structural = dependencies.check(step)
    let rejection = if structural is Some(_) { structural } else { model.apply(step) }
    if rejection is Some(reason) {
      removed.push({ step_id: step.id, reason })
    } else {
      dependencies.commit(step)
      kept.push(step)
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
