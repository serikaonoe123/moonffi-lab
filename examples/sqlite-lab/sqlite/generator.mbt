///|
fn trace(
  seed : UInt64,
  mode : String,
  generator : String,
  operations : Array[Operation],
) -> @lab.Trace {
  {
    schema: 1,
    adapter: "community-sqlite3",
    adapter_version: "1",
    generator_version: generator,
    seed: seed.to_string(),
    environment: { "fixture_mode": mode, "profile": "behavior" },
    steps: operations.mapi((index, operation) => {
      operation_step("s\{index}", operation)
    }),
  }
}

///|
fn text_values() -> Array[String] {
  [
    "", "a", "MoonBit", "你好", "a\u{0000}b", "🌙", "月\u{0000}🌙", "e\u{0301}",
    "' ; -- ?1", "\r\n\t",
  ]
}

///|
/// A finite contract sequence for the unchanged dependency, with no mutant.
pub fn generate(seed : UInt64, mode : String, steps : Int32) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let values = text_values()
  let text = values[random
    .next_uint(limit=values.length().reinterpret_as_uint())
    .reinterpret_as_int()]
  let operations = [
    Open("db0"),
    Prepare("q0", "db0"),
    BindText("q0", text),
    BusyClose("db0"),
    Step("q0"),
    Read("q0"),
    Reset("q0", false),
    Step("q0"),
    Read("q0"),
    Reset("q0", true),
    Step("q0"),
    Read("q0"),
    Reset("q0", false),
    BindInt("q0", 73),
    Step("q0"),
    Read("q0"),
    Step("q0"),
    Finalize("q0"),
    Close("db0"),
  ]
  let limit = if steps < 0 {
    0
  } else if steps < operations.length() {
    steps
  } else {
    operations.length()
  }
  trace(seed, mode, "sqlite-contract-1", operations[:limit].to_owned())
}

///|
priv struct GenerationStatement {
  id : String
  connection : String
  mut phase : Int32
}

///|
/// This independent generator tracks enabled operations, not the oracle values.
pub fn generate_walk(seed : UInt64, mode : String, steps : Int32) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let mut connections : Array[String] = []
  let mut statements : Array[GenerationStatement] = []
  let operations : Array[Operation] = []
  let mut ordinal = 0
  let values = text_values()
  for _i = 0; _i < limit; _i = _i + 1 {
    let enabled : Array[Operation] = []
    if connections.length() < 2 {
      enabled.push(Open("db\{ordinal}"))
    }
    for db in connections {
      if statements.length() < 4 {
        enabled.push(Prepare("q\{ordinal}", db))
      }
      if statements.any(statement => statement.connection == db) {
        enabled.push(BusyClose(db))
      } else {
        enabled.push(Close(db))
      }
    }
    for statement in statements {
      enabled.push(Finalize(statement.id))
      enabled.push(Reset(statement.id, false))
      enabled.push(Reset(statement.id, true))
      if statement.phase < 2 {
        enabled.push(Step(statement.id))
      }
      if statement.phase == 1 {
        enabled.push(Read(statement.id))
      }
      if statement.phase == 0 {
        enabled.push(
          BindText(
            statement.id,
            values[random
            .next_uint(limit=values.length().reinterpret_as_uint())
            .reinterpret_as_int()],
          ),
        )
        enabled.push(
          BindInt(
            statement.id,
            random.next_uint(limit=201U).reinterpret_as_int() - 100,
          ),
        )
      }
    }
    let operation = enabled[random
      .next_uint(limit=enabled.length().reinterpret_as_uint())
      .reinterpret_as_int()]
    match operation {
      Open(db) => {
        connections.push(db)
        ordinal += 1
      }
      Prepare(id, db) => {
        statements.push({ id, connection: db, phase: 0, })
        ordinal += 1
      }
      Step(id) =>
        for statement in statements {
          if statement.id == id {
            statement.phase += 1
          }
        }
      Reset(id, _) =>
        for statement in statements {
          if statement.id == id {
            statement.phase = 0
          }
        }
      Finalize(id) =>
        statements = statements.filter(statement => statement.id != id)
      Close(db) => connections = connections.filter(id => id != db)
      _ => ()
    }
    operations.push(operation)
  }
  trace(seed, mode, "sqlite-walk-1", operations)
}
