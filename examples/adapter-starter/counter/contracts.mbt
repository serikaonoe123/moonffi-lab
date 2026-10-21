///| A second public integration uses the same C target through explicit state
/// contracts rather than putting checks inside Adapter.execute.
struct CounterState { handle : String?; value : Int } derive(Eq, ToJson, @json.FromJson)
///|
fn counter_state(value : Json) -> CounterState { try! @json.from_json(value) }
///|
pub struct CounterContract {}
///|
pub fn CounterContract::new() -> CounterContract { CounterContract::{} }
///|
pub impl @lab.ContractModel for CounterContract with fn initial_state(_) {
  CounterState::{ handle: None, value: 0 }.to_json()
}
///|
pub impl @lab.ContractModel for CounterContract with fn commands(_, json, index, random) {
  let state = counter_state(json)
  match state.handle {
    None => [operation_step("", New("h\{index}", (random % 201U).reinterpret_as_int() - 100))]
    Some(id) => [operation_step("", Add(id, (random % 41U).reinterpret_as_int() - 20)),
      operation_step("", RejectAdd(id, if state.value >= 0 { 200 } else { -200 })),
      operation_step("", Check(id)), operation_step("", Close(id))]
  }
}
///|
pub impl @lab.ContractModel for CounterContract with fn precondition(_, json, step) {
  let state = counter_state(json)
  let operation : Operation = try { @json.from_json(step.args) } catch { _ => return Some("invalid operation") }
  if operation_step(step.id, operation) != step { return Some("counter dependency declaration mismatch") }
  match operation {
    New(_, value) => if state.handle is Some(_) || value < -100 || value > 100 { Some("new requires closed counter and bounded initial value") } else { None }
    Add(id, delta) | RejectAdd(id, delta) => {
      if state.handle != Some(id) || delta < -200 || delta > 200 { return Some("counter missing or delta outside bounds") }
      let next = state.value + delta
      let valid = next >= -100 && next <= 100
      if (step.op == "add") != valid { Some("addition precondition not satisfied") } else { None }
    }
    Check(id) | Close(id) => if state.handle == Some(id) { None } else { Some("counter unavailable") }
  }
}
///|
pub impl @lab.ContractModel for CounterContract with fn next_state(_, json, step) {
  let state = counter_state(json)
  let operation : Operation = try! @json.from_json(step.args)
  (match operation {
    New(id, value) => CounterState::{ handle: Some(id), value }
    Add(_, delta) => { ..state, value: state.value + delta }
    Close(_) => { handle: None, value: 0 }
    _ => state
  }).to_json()
}
///|
pub impl @lab.ContractModel for CounterContract with fn postcondition(self, before, step, observed) {
  let expected = @lab.ContractModel::next_state(self, before, step)
  let status = if step.op == "reject_add" { -1 } else { 0 }
  let wanted : Json = { "status": status, "state": expected }
  if observed == wanted { None } else { Some("native result or error-path state differs from contract") }
}
///|
pub impl @lab.ContractModel for CounterContract with fn invariant(_, state, observed) {
  if state == observed { None } else { Some("native counter differs from model") }
}
///|
pub struct ContractCounterTarget { handles : Map[String, Handle]; mode : Int }
///|
pub fn ContractCounterTarget::new(trace : @lab.Trace) -> ContractCounterTarget {
  { handles: Map([]), mode: if trace.environment.get("fixture_mode") == Some("error") { 1 } else { 0 } }
}
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn identity(_) { "contract-counter" }
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn version(_) { "1" }
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn validate(_, trace) {
  if !["correct", "error"].contains(trace.environment.get("fixture_mode").unwrap_or("correct")) {
    return Some("unknown contract counter mode")
  }
  if trace.environment.get("profile").unwrap_or("behavior") != "behavior" {
    return Some("contract counter supports behavior only")
  }
  None
}
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn observe(self) {
  let mut state = CounterState::{ handle: None, value: 0 }
  for id, handle in self.handles { state = { handle: Some(id), value: native_value(handle) } }
  state.to_json()
}
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn invoke(self, step) {
  let operation : Operation = try! @json.from_json(step.args)
  let status = match operation {
    New(id, value) => { self.handles[id] = native_new(value); 0 }
    Add(id, delta) | RejectAdd(id, delta) => native_add(self.handles.get(id).unwrap(), delta, self.mode)
    Check(_) => 0
    Close(id) => { native_close(self.handles.get(id).unwrap()); self.handles.remove(id); 0 }
  }
  { "status": status, "state": @lab.ContractTarget::observe(self) }
}
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn close(self) {
  for handle in self.handles.values() { native_close(handle) }
  self.handles.clear()
  if native_live() == 0 { None } else { Some({ property: "contract-counter-cleanup", step_id: "teardown", message: "native counter remains logically open" }) }
}
///|
pub impl @lab.ContractTarget for ContractCounterTarget with fn shrink_arguments(_, step) {
  let operation : Operation = try { @json.from_json(step.args) } catch { _ => return [] }
  match operation {
    New(id, value) => @lab.shrink_int(value).map(value => operation_step(step.id, New(id, value)))
    Add(id, delta) => @lab.shrink_int(delta).map(delta => operation_step(step.id, Add(id, delta)))
    RejectAdd(id, delta) => @lab.shrink_int(delta).map(delta => operation_step(step.id, RejectAdd(id, delta)))
    _ => []
  }
}
///|
pub fn contract_template(mode : String) -> @lab.Trace {
  { schema: 1, adapter: "contract-counter", adapter_version: "1", generator_version: "contract-counter-1", seed: "0", environment: { "fixture_mode": mode }, steps: [] }
}
///| Labelled failure case preserves a long prefix and a specific failing step.
pub fn generate_contract(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let operations : Array[Operation] = if limit > 0 { [New("h", 7)] } else { [] }
  for _i = 0; _i < limit - 3; _i = _i + 1 { operations.push(Check("h")) }
  if limit >= 2 { operations.push(RejectAdd("h", 200)) }
  if limit >= 3 { operations.push(Close("h")) }
  { ..contract_template(mode), seed: seed.to_string(), steps: operations.mapi((i, op) => operation_step("s\{i}", op)) }
}
///|
pub fn generate_contract_walk(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  @lab.generate_contract_trace(CounterContract::new(), contract_template(mode), steps, seed=seed.to_uint()).unwrap()
}
///|
pub extend CounterState with ToJson::{to_json}
///|
#deprecated
pub extend CounterState with Eq::{equal, not_equal}
///|
#deprecated
pub extend CounterState with @json.FromJson::{from_json}
///|
pub extend CounterContract with @lab.ContractModel::{initial_state, commands, precondition, next_state, postcondition, invariant}
///|
pub extend ContractCounterTarget with @lab.ContractTarget::{identity, version, validate, invoke, observe, close, shrink_arguments}
