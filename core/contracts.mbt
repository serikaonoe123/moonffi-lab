///| A deterministic, side-effect-free specification. State and observations use
/// concrete JSON so they can be saved without native pointers. Preconditions and
/// next_state are shared by generation, validation and deletion-only repair.
/// postcondition receives the PRE-operation model and the actual target result;
/// invariant sees the whole observed target both initially and after each step.
pub(open) trait ContractModel {
  initial_state(Self) -> Json
  commands(Self, Json, Int, UInt) -> Array[Step]
  precondition(Self, Json, Step) -> String?
  next_state(Self, Json, Step) -> Json
  postcondition(Self, Json, Step, Json) -> String?
  invariant(Self, Json, Json) -> String?
}

///| Constructors must not call native code. All target access, including observe
/// and close, is performed by the worker through the Adapter implementation.
pub(open) trait ContractTarget {
  identity(Self) -> String
  version(Self) -> String
  validate(Self, Trace) -> String?
  invoke(Self, Step) -> Json
  observe(Self) -> Json
  close(Self) -> Failure?
  shrink_arguments(Self, Step) -> Array[Step]
}

///|
pub struct ContractAdapter[M, T] {
  model : M
  target : T
  mut state : Json
}

///|
pub fn[M : ContractModel, T] ContractAdapter::new(model : M, target : T) -> ContractAdapter[M, T] {
  { model, target, state: model.initial_state() }
}

///|
priv struct ContractReplay[M] {
  model : M
  mut state : Json
}

///|
impl[M : ContractModel] StateModel for ContractReplay[M] with fn apply(self, step) {
  if self.model.precondition(self.state, step) is Some(message) { return Some(message) }
  self.state = self.model.next_state(self.state, step)
  None
}

///| Validate the complete trace using a fresh pure state; never inspect a target.
pub fn[M : ContractModel] validate_contract(model : M, trace : Trace) -> String? {
  if validate_dependencies(trace) is Some(message) { return Some(message) }
  let replay = ContractReplay::{ model, state: model.initial_state() }
  for step in trace.steps {
    if StateModel::apply(replay, step) is Some(message) { return Some(message) }
  }
  None
}

///|
pub fn[M : ContractModel] repair_contract(model : M, trace : Trace) -> Repair {
  repair_with_model(ContractReplay::{ model, state: model.initial_state() }, trace)
}

///| Bounded command enumeration. Rejected commands do not advance either model
/// or dependency state. Exhaustion returns an explicit error, not a short test.
/// The caller supplies a versioned template and seed; generated IDs are stable.
pub fn[M : ContractModel] generate_contract_trace(model : M, template : Trace, count : Int, seed~ : UInt = 0U) -> Result[Trace, String] {
  if count < 0 || count > 4096 { return Err("contract step count outside 0..4096") }
  let mut state = model.initial_state()
  let dependencies = DependencyState::new(template.schema)
  let steps : Array[Step] = []
  let mut random = seed
  for index = 0; index < count; index = index + 1 {
    random = random * 1664525U + 1013904223U
    let commands = model.commands(state, index, random)
    if commands.is_empty() || commands.length() > 128 { return Err("contract requires 1..128 command candidates") }
    let offset = (random % commands.length().reinterpret_as_uint()).reinterpret_as_int()
    let mut chosen : Step? = None
    for position = 0; position < commands.length(); position = position + 1 {
      let candidate = { ..commands[(position + offset) % commands.length()], id: "s\{index}" }
      if dependencies.check(candidate) is None && model.precondition(state, candidate) is None {
        chosen = Some(candidate)
        break
      }
    }
    guard chosen is Some(step) else { return Err("no command satisfies the current precondition") }
    dependencies.commit(step)
    state = model.next_state(state, step)
    steps.push(step)
  }
  let trace = { ..template, seed: seed.to_string(), steps }
  if validate_contract(model, trace) is Some(message) { Err(message) } else { Ok(trace) }
}

///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn identity(self) { ContractTarget::identity(self.target) }
///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn version(self) { ContractTarget::version(self.target) }
///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn validate(self, trace) {
  if ContractTarget::validate(self.target, trace) is Some(message) { return Some(message) }
  validate_contract(self.model, trace)
}
///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn repair(self, trace) { repair_contract(self.model, trace) }
///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn shrink_arguments(self, step) { ContractTarget::shrink_arguments(self.target, step) }
///|
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn teardown(self) {
  let invariant = self.model.invariant(self.state, ContractTarget::observe(self.target))
  let cleanup = ContractTarget::close(self.target)
  if invariant is Some(message) {
    Some({ property: "contract-invariant:teardown", step_id: "teardown", message })
  } else { cleanup }
}

///|
fn contract_failure(step : Step, phase : String, message : String) -> Failure? {
  Some({ property: "contract-\{phase}:\{step.op}", step_id: step.id, message })
}

///| Runtime order is initial invariant, precondition, invoke, postcondition,
/// next_state, invariant. Target cleanup remains the worker's responsibility even
/// on failure. The pure model advances only after the postcondition succeeds.
pub impl[M : ContractModel, T : ContractTarget] Adapter for ContractAdapter[M, T] with fn execute(self, step) {
  if self.model.invariant(self.state, ContractTarget::observe(self.target)) is Some(message) {
    return contract_failure(step, "invariant-before", message)
  }
  if self.model.precondition(self.state, step) is Some(message) {
    return contract_failure(step, "precondition", message)
  }
  let result = ContractTarget::invoke(self.target, step)
  if self.model.postcondition(self.state, step, result) is Some(message) {
    return contract_failure(step, "postcondition", message)
  }
  self.state = self.model.next_state(self.state, step)
  if self.model.invariant(self.state, ContractTarget::observe(self.target)) is Some(message) {
    return contract_failure(step, "invariant-after", message)
  }
  None
}

///|
pub extend ContractAdapter with Adapter::{identity, version, validate, execute, teardown, repair, shrink_arguments}
