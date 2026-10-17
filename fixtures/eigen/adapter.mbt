///|
enum Operation {
  New(String, Int, Int, Array[Int])
  Set(String, Int, Int, Int)
  Check(String)
  Transpose(String, String)
  RejectAdd(String, String)
  Drop(String)
} derive(ToJson, @json.FromJson)

///|
struct Model {
  rows : Int
  cols : Int
  data : Array[Int]
}

///| All native resources are allocated only by execute in the worker.
pub struct EigenAdapter {
  handles : Map[String, @binding.Matrix]
  models : Map[String, Model]
}

///|
pub fn EigenAdapter::new() -> EigenAdapter {
  { handles: Map([]), models: Map([]) }
}

///|
fn operation_step(id : String, operation : Operation) -> @lab.Step {
  let (op, defines, uses, releases) = match operation {
    New(id, _, _, _) => ("new", [id], [], [])
    Set(id, _, _, _) => ("set", [], [id], [])
    Check(id) => ("check", [], [id], [])
    Transpose(id, other) => ("transpose", [other], [id], [])
    RejectAdd(a, b) => ("reject_add", [], [a, b], [])
    Drop(id) => ("drop", [], [], [id])
  }
  { id, op, defines, uses, releases, args: operation.to_json() }
}

///|
fn transpose(model : Model) -> Model {
  { rows: model.cols, cols: model.rows,
    data: Array::makei(model.data.length(), i => model.data[(i % model.rows) * model.cols + i / model.rows]) }
}

///|
pub impl @lab.Adapter for EigenAdapter with fn identity(_) { "eigen" }
///|
pub impl @lab.Adapter for EigenAdapter with fn version(_) { "1" }

///|
pub impl @lab.Adapter for EigenAdapter with fn repair(_, trace) {
  @lab.repair_dependencies(trace)
}

///| Bounded integers keep the trace lossless and expectations independent of
/// native Eigen. Shape/argument validation is pure and starts from scratch.
pub impl @lab.Adapter for EigenAdapter with fn validate(_, trace) {
  if trace.environment.get("fixture_mode").unwrap_or("correct") != "correct" {
    return Some("Eigen adapter has no injected defect modes")
  }
  if trace.environment.get("profile").unwrap_or("behavior") != "behavior" {
    return Some("Eigen adapter requires behavior profile")
  }
  let models : Map[String, Model] = Map([])
  for step in trace.steps {
    let operation : Operation = try { @json.from_json(step.args) } catch {
      _ => return Some("invalid Eigen operation payload")
    }
    let expected = operation_step(step.id, operation)
    if expected != step { return Some("operation/dependency declarations mismatch") }
    match operation {
      New(id, rows, cols, data) => {
        if rows < 1 || rows > 4 || cols < 1 || cols > 4 || data.length() != rows * cols ||
          data.any(v => v < -100 || v > 100) { return Some("matrix construction bounds violated") }
        models[id] = { rows, cols, data }
      }
      Set(id, row, col, value) => {
        guard models.get(id) is Some(model) else { return Some("set unavailable matrix") }
        if row < 0 || row >= model.rows || col < 0 || col >= model.cols || value < -100 || value > 100 {
          return Some("set bounds violated")
        }
      }
      Check(id) => if !models.contains(id) { return Some("check unavailable matrix") }
      Transpose(id, other) => {
        guard models.get(id) is Some(model) else { return Some("transpose unavailable matrix") }
        models[other] = transpose(model)
      }
      RejectAdd(a, b) => {
        guard models.get(a) is Some(left) && models.get(b) is Some(right) else { return Some("add unavailable matrix") }
        if left.rows == right.rows && left.cols == right.cols { return Some("reject_add requires different shapes") }
      }
      Drop(id) => models.remove(id)
    }
  }
  None
}

///|
fn failure(step : @lab.Step, property : String, message : String) -> @lab.Failure? {
  Some({ step_id: step.id, property, message })
}

///| Values are deliberately bounded integers; still reject NaN and Infinity
/// before the error comparison, so a non-finite observation cannot pass.
fn EigenAdapter::check(self : EigenAdapter, step : @lab.Step, id : String) -> @lab.Failure? {
  let matrix = self.handles.get(id).unwrap()
  let model = self.models.get(id).unwrap()
  if matrix.rows() != model.rows || matrix.cols() != model.cols {
    return failure(step, "matrix-shape", "matrix \{id}: observed shape differs from model")
  }
  match matrix.to_array() {
    Err(message) => failure(step, "matrix-values", message)
    Ok(values) => {
      if values.length() != model.data.length() { return failure(step, "matrix-values", "wrong array length") }
      for i, value in values {
        if value.is_nan() || value.is_inf() || (value - model.data[i].to_double()).abs() > 0.000000001 {
          return failure(step, "matrix-values", "matrix \{id}: element differs from pure model")
        }
      }
      None
    }
  }
}

///| Check every live matrix after mutations, so an aliased transpose cannot
/// hide until a later random Check. Logical steps still bound all native work.
fn EigenAdapter::check_all(self : EigenAdapter, step : @lab.Step) -> @lab.Failure? {
  let ids = self.models.keys().to_array()
  ids.sort()
  for id in ids {
    if self.check(step, id) is Some(found) { return Some(found) }
  }
  None
}

///|
pub impl @lab.Adapter for EigenAdapter with fn execute(self, step) {
  let operation : Operation = try! @json.from_json(step.args)
  match operation {
    New(id, rows, cols, data) => {
      match @binding.Matrix::from_array(rows, cols, data.map(v => v.to_double())) {
        Err(message) => return failure(step, "matrix-create", message)
        Ok(matrix) => self.handles[id] = matrix
      }
      self.models[id] = { rows, cols, data: data.copy() }
      self.check_all(step)
    }
    Set(id, row, col, value) => {
      match self.handles.get(id).unwrap().set(row, col, value.to_double()) {
        Err(message) => return failure(step, "matrix-set", message)
        Ok(_) => ()
      }
      let model = self.models.get(id).unwrap()
      model.data[row * model.cols + col] = value
      self.check_all(step)
    }
    Check(id) => self.check(step, id)
    Transpose(id, other) => {
      match self.handles.get(id).unwrap().transpose() {
        Err(message) => return failure(step, "matrix-transpose", message)
        Ok(matrix) => self.handles[other] = matrix
      }
      self.models[other] = transpose(self.models.get(id).unwrap())
      self.check_all(step)
    }
    RejectAdd(a, b) => {
      match self.handles.get(a).unwrap().add(self.handles.get(b).unwrap()) {
        Ok(_) => return failure(step, "shape-error-rejected", "incompatible addition succeeded")
        Err(_) => ()
      }
      self.check_all(step)
    }
    Drop(id) => { self.handles.remove(id); self.models.remove(id); None }
  }
}

///| Dropping references is observable here; this adapter does not claim to
/// verify the exact finalizer time or native allocation balance.
pub impl @lab.Adapter for EigenAdapter with fn teardown(self) {
  self.handles.clear()
  self.models.clear()
  None
}

///|
pub impl @lab.Adapter for EigenAdapter with fn shrink_arguments(_, step) {
  let operation : Operation = try! @json.from_json(step.args)
  match operation {
    New(id, rows, cols, data) => [operation_step(step.id, New(id, rows, cols, data.map(_ => 0)))]
    Set(id, row, col, value) => if value != 0 { [operation_step(step.id, Set(id, row, col, 0))] } else { [] }
    _ => []
  }
}

///|
pub fn generate(seed : UInt64, mode~ : String = "correct", steps~ : Int = 32) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let rows = random.next_uint(limit=3U).reinterpret_as_int() + 1
  let cols = random.next_uint(limit=3U).reinterpret_as_int() + 1
  let data = Array::makei(rows * cols, _ => random.next_uint(limit=21U).reinterpret_as_int() - 10)
  let operations : Array[Operation] = [New("a", rows, cols, data)]
  for _i = 0; _i < steps - 8; _i = _i + 1 {
    if random.next_uint(limit=2U) == 0U {
      operations.push(Set("a", 0, 0, random.next_uint(limit=21U).reinterpret_as_int() - 10))
    } else { operations.push(Check("a")) }
  }
  operations.push(Transpose("a", "t"))
  operations.push(Set("a", 0, 0, 99))
  operations.push(Check("t")) // transpose must own independent storage
  operations.push(New("b", 4, 4, Array::make(16, 1)))
  operations.push(RejectAdd("a", "b")) // promises Err, preserve both operands
  operations.push(Drop("a"))
  operations.push(Check("t"))
  {
    schema: 1, adapter: "eigen", adapter_version: "1", generator_version: "eigen-1",
    seed: seed.to_string(), environment: { "fixture_mode": mode, "profile": "behavior",
      "binding_revision": "f7037a92cae92ac1c0e54e3bfa03b2e2e0e9f8ae", "eigen_revision": "1f05f51517ec4fd91eed711e0f89e97a7c028c0e" },
    steps: operations.mapi((index, operation) => operation_step("s\{index}", operation)),
  }
}

///|
pub extend EigenAdapter with @lab.Adapter::{identity, version, validate, execute, teardown, shrink_arguments, repair}

///|
pub extend Operation with ToJson::{to_json}

///|
#deprecated
pub extend Operation with @json.FromJson::{from_json}
