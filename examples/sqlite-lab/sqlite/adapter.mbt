///|
/// Factories, validation, repair and argument proposals contain no target calls.
pub struct SqliteAdapter {
  connections : Map[String, @binding.Connection]
  statements : Map[String, @binding.Statement]
  model : Model
}

///|
pub fn SqliteAdapter::new(_ : @lab.Trace) -> SqliteAdapter {
  { connections: Map([]), statements: Map([]), model: Model::new(), }
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn identity(_) {
  "community-sqlite3"
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn version(_) {
  "1"
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn validate(_, trace) {
  if trace.environment.get("fixture_mode").unwrap_or("correct") != "correct" {
    return Some(
      "SQLite integration supports only the unchanged upstream implementation",
    )
  }
  if trace.environment.get("profile").unwrap_or("behavior") != "behavior" {
    return Some("SQLite integration supports behavior only")
  }
  if @lab.validate_dependencies(trace) is Some(error) {
    return Some(error)
  }
  let model = Model::new()
  for step in trace.steps {
    if model.apply(step) is Some(error) {
      return Some(error)
    }
  }
  None
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn repair(_, trace) {
  @lab.repair_with_model(Model::new(), trace)
}

///|
fn failure(
  step : @lab.Step,
  property : String,
  message : String,
) -> @lab.Failure? {
  Some({ step_id: step.id, property, message, })
}

///|
fn error_message(error : @binding.SqliteError) -> String {
  match error {
    @binding.SqliteError(msg~, ..) => msg
  }
}

///|
fn SqliteAdapter::read(
  self : SqliteAdapter,
  step : @lab.Step,
  id : String,
) -> @lab.Failure? raise @binding.SqliteError {
  let statement = self.statements.get(id).unwrap()
  let expected = self.model.statements.get(id).unwrap().bound
  // Read through a typed accessor before Value too, checking that coercion does
  // not change the cached storage class exposed by the dynamic accessor.
  let expected_value : @binding.Value = match expected {
    Unset => @binding.Value::Null
    Text(value) => {
      let observed : String = statement.column(index=0)
      if observed != value {
        return failure(
          step, "sqlite-text-roundtrip", "bound UTF-16 text did not round trip",
        )
      }
      let _ : Int64 = statement.column(index=0)
      @binding.Value::Text(value)
    }
    Integer(value) => {
      let observed : Int64 = statement.column(index=0)
      if observed != value.to_int64() {
        return failure(
          step, "sqlite-integer-roundtrip", "bound integer did not round trip",
        )
      }
      let rendered : String = statement.column(index=0)
      if rendered != value.to_string() {
        return failure(
          step, "sqlite-integer-text", "integer text conversion differs from its decimal representation",
        )
      }
      @binding.Value::Integer(value.to_int64())
    }
  }
  let dynamic : @binding.Value = statement.column(index=0)
  if dynamic != expected_value {
    return failure(
      step, "sqlite-storage-class", "dynamic value differs from the pure binding model",
    )
  }
  None
}

///|
fn SqliteAdapter::execute_operation(
  self : SqliteAdapter,
  step : @lab.Step,
  operation : Operation,
) -> @lab.Failure? raise @binding.SqliteError {
  match operation {
    Open(id) => self.connections[id] = @binding.Connection::open(":memory:")
    Prepare(id, db) =>
      self.statements[id] = self.connections
        .get(db)
        .unwrap()
        .prepare("SELECT ?1 AS value")
    BindText(id, text) => self.statements.get(id).unwrap().bind(index=1, text)
    BindInt(id, value) => self.statements.get(id).unwrap().bind(index=1, value)
    Step(id) => {
      let expected = self.model.statements.get(id).unwrap().phase == Ready
      if self.statements.get(id).unwrap().step() != expected {
        return failure(
          step, "sqlite-step", "one-row SELECT returned an unexpected step result",
        )
      }
    }
    Read(id) => return self.read(step, id)
    Reset(id, clear) =>
      self.statements.get(id).unwrap().reset(clear_bindings=clear)
    BusyClose(id) => {
      let code = try {
        self.connections.get(id).unwrap().close()
        None
      } catch {
        @binding.SqliteError(code~, ..) => Some(code)
      }
      if code != Some(@binding.ErrorCode::Busy) {
        return failure(
          step, "sqlite-busy-close", "closing a connection with live statements must return Busy",
        )
      }
    }
    Finalize(id) => {
      self.statements.get(id).unwrap().finalize()
      self.statements.remove(id)
    }
    Close(id) => {
      self.connections.get(id).unwrap().close()
      self.connections.remove(id)
    }
  }
  if self.model.apply(step) is Some(error) {
    return failure(step, "sqlite-model", error)
  }
  None
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn execute(self, step) {
  let operation : Operation = try! @json.from_json(step.args)
  self.execute_operation(step, operation) catch {
    error => failure(step, "sqlite-unexpected-error", error_message(error))
  }
}

///|
/// Explicit cleanup runs even after an observed failure, statements first.
/// Logical cleanup is not a claim of heap-leak or finalizer timing coverage.
pub impl @lab.Adapter for SqliteAdapter with fn teardown(self) {
  let mut observed : @lab.Failure? = None
  for statement in self.statements.values() {
    statement.finalize() catch {
      error =>
        if observed is None {
          observed = Some({
            step_id: "teardown",
            property: "sqlite-finalize",
            message: error_message(error),
          })
        }
    }
  }
  self.statements.clear()
  for connection in self.connections.values() {
    connection.close() catch {
      error =>
        if observed is None {
          observed = Some({
            step_id: "teardown",
            property: "sqlite-close",
            message: error_message(error),
          })
        }
    }
  }
  self.connections.clear()
  self.model.connections.clear()
  self.model.statements.clear()
  observed
}

///|
pub impl @lab.Adapter for SqliteAdapter with fn shrink_arguments(_, step) {
  let operation : Operation = @json.from_json(step.args) catch {
    _ => return []
  }
  match operation {
    BindInt(id, value) =>
      @lab.shrink_int(value).map(smaller => {
        operation_step(step.id, BindInt(id, smaller))
      })
    BindText(id, value) =>
      ["", "a", "\u{0000}", "月"]
      .filter(text => text != value)
      .map(text => operation_step(step.id, BindText(id, text)))
    _ => []
  }
}

///|
pub extend SqliteAdapter with @lab.Adapter::{
  identity,
  version,
  validate,
  execute,
  teardown,
  shrink_arguments,
  repair,
}
