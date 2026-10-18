///|
enum Operation {
  New(String, Int, Int, Array[Int])
  Set(String, Int, Int, Int)
  Check(String)
  Transpose(String, String)
  Add(String, String, String)
  Mul(String, String, String)
  RejectAdd(String, String)
  Drop(String)
} derive(ToJson, @json.FromJson)

///|
struct Model {
  rows : Int
  cols : Int
  data : Array[Int64]
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
    Add(a, b, other) => ("add", [other], [a, b], [])
    Mul(a, b, other) => ("mul", [other], [a, b], [])
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

///| Stored elements are bounded by 10^6. At most four products contribute
/// to an entry, so all Int64 and binary64 intermediates are exact integers
/// with magnitude at most 4*10^12, below both Int64 and binary64 limits.
fn arithmetic(left : Model, right : Model, multiply : Bool) -> Model? {
  if multiply {
    if left.cols != right.rows { return None }
  } else if left.rows != right.rows || left.cols != right.cols { return None }
  let rows = left.rows
  let cols = if multiply { right.cols } else { left.cols }
  let data = Array::makei(rows * cols, index => {
    if !multiply { left.data[index] + right.data[index] } else {
      let row = index / cols
      let col = index % cols
      let mut sum = 0L
      for k = 0; k < left.cols; k = k + 1 {
        sum += left.data[row * left.cols + k] * right.data[k * right.cols + col]
      }
      sum
    }
  })
  if data.any(value => value < -1000000L || value > 1000000L) { return None }
  Some({ rows, cols, data })
}

///| Validation and repair advance fresh exact-integer state. Every rejection
/// occurs before changing any retained model, including rejected arithmetic.
struct EigenState { models : Map[String, Model] }
///|
fn EigenState::new() -> EigenState { { models: Map([]) } }
///|
impl @lab.StateModel for EigenState with fn apply(self, step) {
  let operation : Operation = try { @json.from_json(step.args) } catch {
    _ => return Some("invalid Eigen operation payload")
  }
  if operation_step(step.id, operation) != step { return Some("operation/dependency declarations mismatch") }
  match operation {
    New(id, rows, cols, data) => {
      if rows < 1 || rows > 4 || cols < 1 || cols > 4 || data.length() != rows * cols ||
        data.any(v => v < -100 || v > 100) { return Some("matrix construction bounds violated") }
      self.models[id] = { rows, cols, data: data.map(v => v.to_int64()) }
    }
    Set(id, row, col, value) => {
      guard self.models.get(id) is Some(model) else { return Some("set unavailable matrix") }
      if row < 0 || row >= model.rows || col < 0 || col >= model.cols || value < -100 || value > 100 {
        return Some("set bounds violated")
      }
      model.data[row * model.cols + col] = value.to_int64()
    }
    Check(id) => if !self.models.contains(id) { return Some("check unavailable matrix") }
    Transpose(id, other) => {
      guard self.models.get(id) is Some(model) else { return Some("transpose unavailable matrix") }
      self.models[other] = transpose(model)
    }
    Add(a, b, other) | Mul(a, b, other) => {
      guard self.models.get(a) is Some(left) && self.models.get(b) is Some(right) else {
        return Some("arithmetic operand unavailable")
      }
      let multiply = match operation { Mul(_, _, _) => true; _ => false }
      guard arithmetic(left, right, multiply) is Some(result) else {
        return Some("arithmetic shape or exact-integer bound violated")
      }
      self.models[other] = result
    }
    RejectAdd(a, b) => {
      guard self.models.get(a) is Some(left) && self.models.get(b) is Some(right) else { return Some("add unavailable matrix") }
      if left.rows == right.rows && left.cols == right.cols { return Some("reject_add requires different shapes") }
    }
    Drop(id) => self.models.remove(id)
  }
  None
}

///|
pub impl @lab.Adapter for EigenAdapter with fn identity(_) { "eigen" }
///|
pub impl @lab.Adapter for EigenAdapter with fn version(_) { "1" }

///|
pub impl @lab.Adapter for EigenAdapter with fn repair(_, trace) {
  @lab.repair_with_model(EigenState::new(), trace)
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
  if @lab.validate_dependencies(trace) is Some(message) { return Some(message) }
  let state = EigenState::new()
  for step in trace.steps {
    if state.apply(step) is Some(message) { return Some(message) }
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
        if value.is_nan() || value.is_inf() || value != model.data[i].to_double() {
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
      self.models[id] = { rows, cols, data: data.map(v => v.to_int64()) }
      self.check_all(step)
    }
    Set(id, row, col, value) => {
      match self.handles.get(id).unwrap().set(row, col, value.to_double()) {
        Err(message) => return failure(step, "matrix-set", message)
        Ok(_) => ()
      }
      let model = self.models.get(id).unwrap()
      model.data[row * model.cols + col] = value.to_int64()
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
    Add(a, b, other) | Mul(a, b, other) => {
      let left = self.handles.get(a).unwrap()
      let right = self.handles.get(b).unwrap()
      let multiply = match operation { Mul(_, _, _) => true; _ => false }
      let result = if multiply { left.mul(right) } else { left.add(right) }
      match result {
        Err(message) => return failure(step, "matrix-arithmetic", message)
        Ok(matrix) => self.handles[other] = matrix
      }
      self.models[other] = arithmetic(self.models.get(a).unwrap(), self.models.get(b).unwrap(), multiply).unwrap()
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
    New(id, rows, cols, data) => {
      let zero = data.map(_ => 0)
      let candidates : Array[@lab.Step] = []
      if data != zero { candidates.push(operation_step(step.id, New(id, rows, cols, zero))) }
      // A valid construction has at most sixteen entries. Keep the fast all-zero
      // proposal, then change one component at a time without reshaping data.
      for index = 0; index < data.length(); index = index + 1 {
        for smaller in @lab.shrink_int(data[index]) {
          let changed = data.copy()
          changed[index] = smaller
          if changed != zero { candidates.push(operation_step(step.id, New(id, rows, cols, changed))) }
        }
      }
      candidates
    }
    Set(id, row, col, value) => @lab.shrink_int(value).map(smaller => operation_step(step.id, Set(id, row, col, smaller)))
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
pub extend EigenState with @lab.StateModel::{apply}

///|
pub extend Operation with ToJson::{to_json}

///|
#deprecated
pub extend Operation with @json.FromJson::{from_json}
