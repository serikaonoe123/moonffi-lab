///|
fn trace(seed : UInt64, mode : String, version : String, operations : Array[Operation]) -> @lab.Trace {
  { schema: 1, adapter: "starter-counter", adapter_version: "1", generator_version: version,
    seed: seed.to_string(), environment: { "fixture_mode": mode, "profile": "behavior" },
    steps: operations.mapi((index, operation) => operation_step("s\{index}", operation)) }
}
///| A labelled contract case guarantees the teaching mutant is observed.
pub fn generate(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let operations : Array[Operation] = if limit > 0 { [New("a", 1)] } else { [] }
  for _i = 0; _i < limit - 3; _i = _i + 1 { operations.push(Check("a")) }
  if limit >= 2 { operations.push(RejectAdd("a", 200)) }
  if limit >= 3 { operations.push(Close("a")) }
  trace(seed, mode, "counter-contract-1", operations)
}
///| Optional generator registration needs no engine changes. This short walk
/// keeps one live counter and chooses enabled actions without a fixed suffix.
pub fn generate_walk(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let operations : Array[Operation] = []
  let mut value : Int? = None
  let mut ordinal = 0
  let mut id = ""
  for _i = 0; _i < limit; _i = _i + 1 {
    let operation = if value is Some(before) {
      match random.next_uint(limit=4U) {
        0U => {
          let delta = random.next_uint(limit=21U).reinterpret_as_int() - 10
          if before + delta < -100 || before + delta > 100 { Check(id) } else {
            value = Some(before + delta)
            Add(id, delta)
          }
        }
        1U => RejectAdd(id, if before >= 0 { 200 } else { -200 })
        2U => Check(id)
        _ => { value = None; Close(id) }
      }
    } else {
      id = "c\{ordinal}"
      ordinal += 1
      let initial = random.next_uint(limit=201U).reinterpret_as_int() - 100
      value = Some(initial)
      New(id, initial)
    }
    operations.push(operation)
  }
  trace(seed, mode, "counter-walk-1", operations)
}
