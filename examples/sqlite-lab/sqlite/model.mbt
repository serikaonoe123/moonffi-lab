///|
/// Operations use the public upstream API. SQL and filenames are fixed;
/// generated values are bound parameters in isolated in-memory databases.
enum Operation {
  Open(String)
  Prepare(String, String)
  BindText(String, String)
  BindInt(String, Int32)
  Step(String)
  Read(String)
  Reset(String, Bool)
  BusyClose(String)
  Finalize(String)
  Close(String)
} derive(ToJson, @json.FromJson)

///|
fn operation_step(id : String, operation : Operation) -> @lab.Step {
  let (op, defines, uses, releases) = match operation {
    Open(db) => ("open", [db], [], [])
    Prepare(statement, db) => ("prepare", [statement], [db], [])
    BindText(statement, _) => ("bind_text", [], [statement], [])
    BindInt(statement, _) => ("bind_int", [], [statement], [])
    Step(statement) => ("step", [], [statement], [])
    Read(statement) => ("read", [], [statement], [])
    Reset(statement, _) => ("reset", [], [statement], [])
    BusyClose(db) => ("busy_close", [], [db], [])
    Finalize(statement) => ("finalize", [], [], [statement])
    Close(db) => ("close", [], [], [db])
  }
  { id, op, args: operation.to_json(), defines, uses, releases, }
}

///|
enum Bound {
  Unset
  Text(String)
  Integer(Int32)
} derive(Eq)

///|
enum Phase {
  Ready
  Row
  Done
} derive(Eq)

///|
priv struct StatementState {
  connection : String
  mut bound : Bound
  mut phase : Phase
}

///|
struct Model {
  connections : Map[String, Bool]
  statements : Map[String, StatementState]
}

///|
fn Model::new() -> Model {
  { connections: Map([]), statements: Map([]), }
}

///|
fn Model::has_statement(self : Model, db : String) -> Bool {
  self.statements.values().any(statement => statement.connection == db)
}

///|
/// Every rejecting branch precedes mutation. Connections cannot be closed
/// while statements are live; BusyClose deliberately checks the error contract.
impl @lab.StateModel for Model with fn apply(self, step) {
  let operation : Operation = @json.from_json(step.args) catch {
    _ => return Some("invalid SQLite payload")
  }
  if operation_step(step.id, operation) != step {
    return Some("SQLite dependency declarations mismatch")
  }
  match operation {
    Open(db) => {
      if self.connections.contains(db) || self.connections.length() >= 2 {
        return Some("connection unavailable or limit reached")
      }
      self.connections[db] = true
    }
    Prepare(statement, db) => {
      if !self.connections.contains(db) ||
        self.statements.contains(statement) ||
        self.statements.length() >= 4 {
        return Some("prepare requires a live connection and a fresh statement")
      }
      self.statements[statement] = {
        connection: db,
        bound: Unset,
        phase: Ready,
      }
    }
    BusyClose(db) =>
      if !self.connections.contains(db) || !self.has_statement(db) {
        return Some("busy close requires a live statement")
      }
    Close(db) => {
      if !self.connections.contains(db) || self.has_statement(db) {
        return Some("close requires no live statements")
      }
      self.connections.remove(db)
    }
    _ => {
      let statement_id = match operation {
        BindText(id, _)
        | BindInt(id, _)
        | Step(id)
        | Read(id)
        | Reset(id, _)
        | Finalize(id) => id
        _ => abort("handled connection operation")
      }
      guard self.statements.get(statement_id) is Some(statement) else {
        return Some("statement unavailable")
      }
      if !self.connections.contains(statement.connection) {
        return Some("statement connection unavailable")
      }
      match operation {
        BindText(_, value) => {
          if statement.phase != Ready || value.length() > 128 {
            return Some(
              "text binding requires a ready statement and bounded text",
            )
          }
          statement.bound = Text(value)
        }
        BindInt(_, value) => {
          if statement.phase != Ready || value < -1000000 || value > 1000000 {
            return Some(
              "integer binding requires a ready statement and bounded integer",
            )
          }
          statement.bound = Integer(value)
        }
        Step(_) =>
          match statement.phase {
            Ready => statement.phase = Row
            Row => statement.phase = Done
            Done => return Some("exhausted statement must be reset")
          }
        Read(_) =>
          if statement.phase != Row {
            return Some("read requires a current row")
          }
        Reset(_, clear) => {
          statement.phase = Ready
          if clear {
            statement.bound = Unset
          }
        }
        Finalize(_) => self.statements.remove(statement_id)
        _ => abort("handled connection operation")
      }
    }
  }
  None
}

///|
pub extend Model with @lab.StateModel::{apply}

///|
pub extend Operation with ToJson::{to_json}

///|
#deprecated
pub extend Operation with @json.FromJson::{from_json}

///|
#deprecated
pub extend Bound with Eq::{equal, not_equal}

///|
#deprecated
pub extend Phase with Eq::{equal, not_equal}
