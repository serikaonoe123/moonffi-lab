///| Generation tracks lengths and alias identity independently of BufferModel.
/// No FFI calls or native resources are created while selecting operations.
priv struct GenerationResource {
  mut length : Int
}

///|
priv struct GenerationHandle {
  id : String
  resource : GenerationResource
}

///| Boundary-biased lengths include empty and maximum-size resources.
fn generation_length(random : @splitmix.RandomState) -> Int {
  let boundaries = [0, 1, 2, 15, 16, 255, 256]
  if random.next_uint(limit=3U) == 0U {
    random.next_uint(limit=257U).reinterpret_as_int()
  } else {
    boundaries[random.next_uint(limit=boundaries.length().reinterpret_as_uint()).reinterpret_as_int()]
  }
}

///| A bounded, mode-independent state walk. Every step is chosen from enabled
/// operations; no fixed defect-triggering suffix is appended. Iteration order
/// comes from arrays, so hash-map ordering cannot affect reproducibility.
pub fn generate_stateful(seed : UInt64, mode~ : String = "correct", steps~ : Int = 32) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let limit = if steps < 0 { 0 } else if steps > 256 { 256 } else { steps }
  let operations : Array[Operation] = []
  let mut live : Array[GenerationHandle] = []
  let mut next_handle = 0
  for _i = 0; _i < limit; _i = _i + 1 {
    let writable = live.filter(handle => handle.resource.length > 0)
    let enabled = if live.is_empty() { [0] } else {
      let choices = [2, 3, 5, 6]
      if live.length() < 8 { choices.push(0); choices.push(1) }
      if !writable.is_empty() { choices.push(4) }
      choices
    }
    let choice = enabled[random.next_uint(limit=enabled.length().reinterpret_as_uint()).reinterpret_as_int()]
    let operation = if choice == 0 {
      let id = "h\{next_handle}"
      next_handle += 1
      let length = generation_length(random)
      let bytes = Bytes::makei(length, _ => {
        let boundaries : Array[Byte] = [b'\x00', b'\x01', b'A', b'\x7f', b'\x80', b'\xff']
        if random.next_uint(limit=3U) == 0U {
          boundaries[random.next_uint(limit=boundaries.length().reinterpret_as_uint()).reinterpret_as_int()]
        } else { random.next_uint(limit=256U).reinterpret_as_int().to_byte() }
      })
      live.push({ id, resource: { length, } })
      New(id, @hex.encode(bytes[:]))
    } else {
      let targets = if choice == 4 { writable } else { live }
      let target = targets[random.next_uint(limit=targets.length().reinterpret_as_uint()).reinterpret_as_int()]
      match choice {
        1 => {
          let id = "h\{next_handle}"
          next_handle += 1
          live.push({ id, resource: target.resource })
          Share(target.id, id)
        }
        2 => {
          live = live.filter(handle => handle.id != target.id)
          Close(target.id)
        }
        3 => Read(target.id)
        4 => {
          let length = target.resource.length
          let index = match random.next_uint(limit=3U) {
            0U => 0
            1U => length - 1
            _ => random.next_uint(limit=length.reinterpret_as_uint()).reinterpret_as_int()
          }
          Write(target.id, index, random.next_uint(limit=256U).reinterpret_as_int())
        }
        5 => {
          let index = match random.next_uint(limit=3U) {
            0U => -1
            1U => target.resource.length
            _ => target.resource.length + 1 + random.next_uint(limit=256U).reinterpret_as_int()
          }
          RejectWrite(target.id, index)
        }
        _ => {
          let before = target.resource.length
          let length = match random.next_uint(limit=5U) {
            0U => 0
            1U => 256
            2U => if before < 256 { before + 1 } else { 255 }
            3U => if before > 0 { before - 1 } else { 1 }
            _ => generation_length(random)
          }
          target.resource.length = length
          Resize(target.id, length)
        }
      }
    }
    operations.push(operation)
  }
  {
    schema: 1, adapter: "buffer", adapter_version: "1", generator_version: "buffer-stateful-1",
    seed: seed.to_string(),
    environment: { "fixture_mode": mode, "profile": if asan_profile_built() || mode == "asan-canary" { "asan" } else { "behavior" } },
    steps: operations.mapi((index, operation) => operation_step("s\{index}", operation)),
  }
}
