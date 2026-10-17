///| Generation tracks only ordered live IDs and shapes, without FFI or the
/// adapter's numerical model. A transpose creates a new independent handle.
priv struct GenerationShape {
  id : String
  rows : Int
  cols : Int
}

///|
fn generation_value(random : @splitmix.RandomState) -> Int {
  let boundaries = [-100, -1, 0, 1, 100]
  if random.next_uint(limit=2U) == 0U {
    boundaries[random.next_uint(limit=5U).reinterpret_as_int()]
  } else { random.next_uint(limit=201U).reinterpret_as_int() - 100 }
}

///| Select from enabled operations; incompatible addition is enabled only for
/// two different shapes. No fixed transpose/error suffix is appended.
pub fn generate_stateful(seed : UInt64, mode~ : String = "correct", steps~ : Int = 32) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let operations : Array[Operation] = []
  let mut live : Array[GenerationShape] = []
  let mut next_handle = 0
  for _i = 0; _i < limit; _i = _i + 1 {
    let incompatible : Array[(Int, Int)] = []
    for left = 0; left < live.length(); left = left + 1 {
      for right = left + 1; right < live.length(); right = right + 1 {
        if live[left].rows != live[right].rows || live[left].cols != live[right].cols {
          incompatible.push((left, right))
        }
      }
    }
    let enabled = if live.is_empty() { [0] } else {
      let choices = [1, 2, 5]
      if live.length() < 8 { choices.push(0); choices.push(3) }
      if !incompatible.is_empty() { choices.push(4) }
      choices
    }
    let choice = enabled[random.next_uint(limit=enabled.length().reinterpret_as_uint()).reinterpret_as_int()]
    let operation = if choice == 0 {
      let id = "m\{next_handle}"
      next_handle += 1
      let rows = random.next_uint(limit=4U).reinterpret_as_int() + 1
      let cols = random.next_uint(limit=4U).reinterpret_as_int() + 1
      let data = Array::makei(rows * cols, _ => generation_value(random))
      live.push({ id, rows, cols })
      New(id, rows, cols, data)
    } else if choice == 4 {
      let (left, right) = incompatible[random.next_uint(limit=incompatible.length().reinterpret_as_uint()).reinterpret_as_int()]
      if random.next_uint(limit=2U) == 0U {
        RejectAdd(live[left].id, live[right].id)
      } else { RejectAdd(live[right].id, live[left].id) }
    } else {
      let target = live[random.next_uint(limit=live.length().reinterpret_as_uint()).reinterpret_as_int()]
      match choice {
        1 => {
          let row = random.next_uint(limit=target.rows.reinterpret_as_uint()).reinterpret_as_int()
          let col = random.next_uint(limit=target.cols.reinterpret_as_uint()).reinterpret_as_int()
          Set(target.id, row, col, generation_value(random))
        }
        2 => Check(target.id)
        3 => {
          let id = "m\{next_handle}"
          next_handle += 1
          live.push({ id, rows: target.cols, cols: target.rows })
          Transpose(target.id, id)
        }
        _ => {
          live = live.filter(handle => handle.id != target.id)
          Drop(target.id)
        }
      }
    }
    operations.push(operation)
  }
  {
    schema: 1, adapter: "eigen", adapter_version: "1", generator_version: "eigen-stateful-1",
    seed: seed.to_string(), environment: { "fixture_mode": mode, "profile": "behavior",
      "binding_revision": "f7037a92cae92ac1c0e54e3bfa03b2e2e0e9f8ae", "eigen_revision": "1f05f51517ec4fd91eed711e0f89e97a7c028c0e" },
    steps: operations.mapi((index, operation) => operation_step("s\{index}", operation)),
  }
}
