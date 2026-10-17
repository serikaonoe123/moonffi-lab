///| A stable operation ID survives deletion of surrounding steps.
pub(all) struct Step {
  id : String
  op : String
  args : Json
  defines : Array[String]
  uses : Array[String]
  releases : Array[String]
} derive(ToJson, @json.FromJson)

///| Concrete arguments must not inherit Json's rounded Double equality. This
/// also makes deletion-only repair guards distinguish adjacent large integers.
pub impl Eq for Step with fn equal(a, b) {
  a.id == b.id && a.op == b.op && a.defines == b.defines &&
    a.uses == b.uses && a.releases == b.releases &&
    integer_descent(a.args, b.args) == Some(false)
}

///| Concrete inputs are authoritative; a seed is provenance, not a replay format.
pub(all) struct Trace {
  schema : Int
  adapter : String
  adapter_version : String
  generator_version : String
  seed : String
  environment : Map[String, String]
  steps : Array[Step]
} derive(Eq, ToJson, @json.FromJson)

///|
pub(all) struct Failure {
  property : String
  step_id : String
  message : String
} derive(Eq, ToJson, @json.FromJson)

///|
pub(all) struct Completion {
  protocol : Int
  completed : Bool
  executed : Int
  failure : Failure?
} derive(Eq, ToJson, @json.FromJson)

///|
pub(all) enum Outcome {
  Pass
  PropertyFailure
  MemoryError
  Crash
  Timeout
  InvalidCase
  SetupError
  HarnessError
  Flaky
} derive(Eq, ToJson, @json.FromJson)

///|
pub(all) struct Report {
  outcome : Outcome
  fingerprint : String?
  raw_exit_code : Int?
  last_step : String?
  executed : Int
  elapsed_ms : Int64
  message : String
} derive(Eq, ToJson, @json.FromJson)

///| Adapter code must not call the target before the worker starts.
pub(open) trait Adapter {
  identity(Self) -> String
  version(Self) -> String
  validate(Self, Trace) -> String?
  execute(Self, Step) -> Failure?
  teardown(Self) -> Failure?
  shrink_arguments(Self, Step) -> Array[Step]
  repair(Self, Trace) -> Repair
}

///|
pub fn Trace::with_steps(self : Trace, steps : Array[Step]) -> Trace {
  { ..self, steps }
}

///|
pub fn Trace::encode(self : Trace) -> String {
  self.to_json().stringify(indent=2)
}

///|
pub fn decode_trace(text : String) -> Trace raise {
  @json.from_json(@json.parse(text))
}

///| Validate handle and step identities independently of adapter semantics.
pub fn validate_dependencies(trace : Trace) -> String? {
  if trace.schema != 1 { return Some("unsupported trace schema") }
  if trace.steps.length() > 4096 { return Some("trace exceeds 4096 steps") }
  let state = DependencyState::new(trace.schema)
  for step in trace.steps {
    if state.check(step) is Some(error) { return Some(error) }
    state.commit(step)
  }
  None
}

///| Remove a block and transitively remove users of objects defined in it.
/// The adapter must still validate the complete candidate from its initial model.
pub fn delete_block(trace : Trace, start : Int, count : Int) -> Trace {
  let unavailable : Map[String, Bool] = Map([])
  let kept : Array[Step] = []
  for i, step in trace.steps {
    let dependent = [..step.uses, ..step.releases].any(h => unavailable.contains(h))
    if (i >= start && i < start + count) || dependent {
      for handle in step.defines { unavailable[handle] = true }
    } else {
      kept.push(step)
    }
  }
  trace.with_steps(kept)
}

///|
pub fn Report::exit_code(self : Report) -> Int {
  match self.outcome {
    Pass => 0
    PropertyFailure | MemoryError | Crash => 1
    Timeout | Flaky => 3
    InvalidCase | SetupError | HarnessError => 2
  }
}
