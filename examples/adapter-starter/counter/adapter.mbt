///| Native handles are created only by execute, never by constructors/models.
type Handle
///|
extern "C" fn native_new(value : Int) -> Handle = "starter_counter_new"
///|
#borrow(handle)
extern "C" fn native_add(handle : Handle, delta : Int, mode : Int) -> Int = "starter_counter_add"
///|
#borrow(handle)
extern "C" fn native_value(handle : Handle) -> Int = "starter_counter_value"
///|
#borrow(handle)
extern "C" fn native_close(handle : Handle) -> Unit = "starter_counter_close"
///|
extern "C" fn native_live() -> Int = "starter_counter_live"

///|
enum Operation {
  New(String, Int)
  Add(String, Int)
  RejectAdd(String, Int)
  Check(String)
  Close(String)
} derive(ToJson, @json.FromJson)

///| These declarations must agree with the actual operation, not just parse.
fn operation_step(id : String, operation : Operation) -> @lab.Step {
  let (op, defines, uses, releases) = match operation {
    New(handle, _) => ("new", [handle], [], [])
    Add(handle, _) => ("add", [], [handle], [])
    RejectAdd(handle, _) => ("reject_add", [], [handle], [])
    Check(handle) => ("check", [], [handle], [])
    Close(handle) => ("close", [], [], [handle])
  }
  { id, op, args: operation.to_json(), defines, uses, releases }
}

///| A fresh pure model is shared by validation and deletion-only repair.
struct Model { values : Map[String, Int] }
///|
fn Model::new() -> Model { { values: Map([]) } }
///|
impl @lab.StateModel for Model with fn apply(self, step) {
  let operation : Operation = try { @json.from_json(step.args) } catch {
    _ => return Some("invalid counter payload")
  }
  if operation_step(step.id, operation) != step { return Some("counter dependency declarations mismatch") }
  match operation {
    New(id, value) => {
      if value < -100 || value > 100 { return Some("counter initial value outside bounds") }
      self.values[id] = value
    }
    Add(id, delta) | RejectAdd(id, delta) => {
      guard self.values.get(id) is Some(value) else { return Some("counter unavailable") }
      if delta < -200 || delta > 200 { return Some("counter delta outside bounds") }
      let next = value + delta
      let valid = next >= -100 && next <= 100
      match operation {
        Add(_, _) => {
          if !valid { return Some("add precondition violated") }
          self.values[id] = next
        }
        _ => if valid { return Some("reject_add requires an out-of-range sum") }
      }
    }
    Check(id) => if !self.values.contains(id) { return Some("counter unavailable") }
    Close(id) => {
      if !self.values.contains(id) { return Some("counter unavailable") }
      self.values.remove(id)
    }
  }
  None
}

///|
pub struct CounterAdapter {
  handles : Map[String, Handle]
  model : Model
  mode : Int
}
///| Pure factory. Unknown environment values are rejected by validate.
pub fn CounterAdapter::new(trace : @lab.Trace) -> CounterAdapter {
  { handles: Map([]), model: Model::new(), mode: if trace.environment.get("fixture_mode") == Some("error") { 1 } else { 0 } }
}
///|
pub impl @lab.Adapter for CounterAdapter with fn identity(_) { "starter-counter" }
///|
pub impl @lab.Adapter for CounterAdapter with fn version(_) { "1" }
///|
pub impl @lab.Adapter for CounterAdapter with fn validate(_, trace) {
  if !["correct", "error"].contains(trace.environment.get("fixture_mode").unwrap_or("correct")) {
    return Some("unknown counter fixture mode")
  }
  if trace.environment.get("profile").unwrap_or("behavior") != "behavior" { return Some("counter example supports behavior only") }
  if @lab.validate_dependencies(trace) is Some(message) { return Some(message) }
  let model = Model::new()
  for step in trace.steps { if model.apply(step) is Some(message) { return Some(message) } }
  None
}
///|
pub impl @lab.Adapter for CounterAdapter with fn repair(_, trace) {
  @lab.repair_with_model(Model::new(), trace)
}
///|
fn observed_failure(step : @lab.Step, property : String, message : String) -> @lab.Failure? {
  Some({ step_id: step.id, property, message })
}
///|
fn CounterAdapter::check(self : CounterAdapter, step : @lab.Step, id : String) -> @lab.Failure? {
  if native_value(self.handles.get(id).unwrap()) != self.model.values.get(id).unwrap() {
    observed_failure(step, "counter-value", "native value differs from the pure counter model")
  } else { None }
}
///|
pub impl @lab.Adapter for CounterAdapter with fn execute(self, step) {
  let operation : Operation = try! @json.from_json(step.args)
  match operation {
    New(id, value) => {
      self.handles[id] = native_new(value)
      self.model.values[id] = value
      self.check(step, id)
    }
    Add(id, delta) => {
      if native_add(self.handles.get(id).unwrap(), delta, self.mode) != 0 {
        return observed_failure(step, "counter-add", "valid addition was rejected")
      }
      self.model.values[id] = self.model.values.get(id).unwrap() + delta
      self.check(step, id)
    }
    RejectAdd(id, delta) => {
      if native_add(self.handles.get(id).unwrap(), delta, self.mode) != -1 {
        return observed_failure(step, "counter-error", "out-of-range addition did not return the promised error")
      }
      self.check(step, id) // the correct reference model must remain unchanged
    }
    Check(id) => self.check(step, id)
    Close(id) => {
      native_close(self.handles.get(id).unwrap())
      self.handles.remove(id)
      self.model.values.remove(id)
      None
    }
  }
}
///| Explicitly close remaining handles, including after a property failure.
pub impl @lab.Adapter for CounterAdapter with fn teardown(self) {
  for handle in self.handles.values() { native_close(handle) }
  self.handles.clear()
  self.model.values.clear()
  if native_live() == 0 { None } else {
    Some({ step_id: "teardown", property: "counter-lifecycle", message: "counter still logically open" })
  }
}
///| Only propose arguments: the runner revalidates them and enforces progress.
pub impl @lab.Adapter for CounterAdapter with fn shrink_arguments(_, step) {
  let operation : Operation = try { @json.from_json(step.args) } catch { _ => return [] }
  match operation {
    New(id, value) => if value != 0 { [operation_step(step.id, New(id, 0))] } else { [] }
    Add(id, delta) => if delta != 0 { [operation_step(step.id, Add(id, 0))] } else { [] }
    _ => []
  }
}
///|
pub extend CounterAdapter with @lab.Adapter::{identity, version, validate, execute, teardown, shrink_arguments, repair}
///|
pub extend Model with @lab.StateModel::{apply}
///|
pub extend Operation with ToJson::{to_json}
///|
#deprecated
pub extend Operation with @json.FromJson::{from_json}
