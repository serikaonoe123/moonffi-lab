///| Dependency changes are committed only after both structural checks and
/// the adapter's pure model accept a step. In particular a rejected release
/// must not close a handle, and a rejected definition must not reserve its ID.
priv struct DependencyState {
  schema : Int
  ids : Map[String, Bool]
  defined : Map[String, Bool]
  live : Map[String, Bool]
  mut count : Int
}

///|
fn DependencyState::new(schema : Int) -> DependencyState {
  { schema, ids: Map([]), defined: Map([]), live: Map([]), count: 0 }
}

///| Keep the historical diagnostic priority: all availability checks precede
/// repeated-release checks, which in turn precede definition checks.
fn DependencyState::check(self : DependencyState, step : Step) -> String? {
  if self.schema != 1 { return Some("unsupported trace schema") }
  if self.count >= 4096 { return Some("trace exceeds 4096 steps") }
  if step.id == "" || self.ids.contains(step.id) {
    return Some("empty or duplicate step ID: \{step.id}")
  }
  for handle in step.uses {
    if !self.live.contains(handle) { return Some("\{step.id}: unavailable handle \{handle}") }
  }
  for handle in step.releases {
    if !self.live.contains(handle) { return Some("\{step.id}: unavailable handle \{handle}") }
  }
  let mentioned : Map[String, Bool] = Map([])
  for handle in step.releases {
    if mentioned.contains(handle) { return Some("\{step.id}: repeated release \{handle}") }
    mentioned[handle] = true
  }
  for handle in step.defines {
    if handle == "" || self.defined.contains(handle) || mentioned.contains(handle) {
      return Some("\{step.id}: duplicate or empty handle \{handle}")
    }
    mentioned[handle] = true
  }
  None
}

///| The caller must have checked this exact step and received model acceptance.
fn DependencyState::commit(self : DependencyState, step : Step) -> Unit {
  self.ids[step.id] = true
  for handle in step.releases { self.live.remove(handle) }
  for handle in step.defines {
    self.defined[handle] = true
    self.live[handle] = true
  }
  self.count += 1
}
