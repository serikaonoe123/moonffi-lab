///| Independent scalar oracle. It does not use the generator's resource boxes,
/// BufferModel, repair, or native calls. Resource numbers survive alias closes.
fn check_generation(trace : @lab.Trace, coverage : Map[String, Bool]) -> Unit raise {
  let handles : Map[String, Int] = Map([])
  let defined : Map[String, Bool] = Map([])
  let lengths : Array[Int] = []
  let last_resizer : Map[Int, String] = Map([])
  let closed_alias : Map[Int, Bool] = Map([])
  let mut previous = "start"
  for step in trace.steps {
    coverage["op:\{step.op}"] = true
    coverage["edge:\{previous}:\{step.op}"] = true
    previous = step.op
    let operation : Operation = @json.from_json(step.args)
    match operation {
      New(id, hex) => {
        assert_true(!defined.contains(id))
        if handles.is_empty() && !lengths.is_empty() { coverage["restart-after-close"] = true }
        let bytes = @hex.decode(hex)
        assert_true(bytes.length() <= 256)
        if bytes.length() == 0 { coverage["new-empty"] = true }
        if bytes.length() == 256 { coverage["new-maximum"] = true }
        assert_true(step.op == "new" && step.defines == [id] && step.uses == [] && step.releases == [])
        handles[id] = lengths.length()
        lengths.push(bytes.length())
        defined[id] = true
      }
      Share(id, other) => {
        assert_true(handles.contains(id) && !defined.contains(other))
        assert_true(step.op == "share" && step.defines == [other] && step.uses == [id] && step.releases == [])
        handles[other] = handles.get(id).unwrap()
        defined[other] = true
      }
      Close(id) => {
        assert_true(handles.contains(id))
        assert_true(step.op == "close" && step.defines == [] && step.uses == [] && step.releases == [id])
        let resource = handles.get(id).unwrap()
        handles.remove(id)
        if handles.values().any(r => r == resource) { closed_alias[resource] = true }
      }
      Read(id) => {
        assert_true(handles.contains(id))
        assert_true(step.op == "read" && step.defines == [] && step.uses == [id] && step.releases == [])
        if closed_alias.contains(handles.get(id).unwrap()) { coverage["read-after-alias-close"] = true }
      }
      Write(id, index, value) => {
        assert_true(handles.contains(id))
        let resource = handles.get(id).unwrap()
        assert_true(index >= 0 && index < lengths[resource] && value >= 0 && value <= 255)
        assert_true(step.op == "write" && step.defines == [] && step.uses == [id] && step.releases == [])
        if last_resizer.get(resource) is Some(resizer) && resizer != id {
          coverage["write-after-other-alias-resize"] = true
        }
      }
      RejectWrite(id, index) => {
        assert_true(handles.contains(id))
        let length = lengths[handles.get(id).unwrap()]
        assert_true(index < 0 || index >= length)
        assert_true(step.op == "reject_write" && step.defines == [] && step.uses == [id] && step.releases == [])
        if index == length { coverage["reject-at-end"] = true }
        if index < 0 { coverage["reject-negative"] = true }
      }
      Resize(id, length) => {
        assert_true(handles.contains(id) && length >= 0 && length <= 256)
        assert_true(step.op == "resize" && step.defines == [] && step.uses == [id] && step.releases == [])
        let resource = handles.get(id).unwrap()
        if length > lengths[resource] { coverage["grow"] = true }
        if length < lengths[resource] { coverage["shrink"] = true }
        if lengths[resource] == 0 && length > 0 { coverage["regrow-empty"] = true }
        if length == 0 { coverage["resize-empty"] = true }
        lengths[resource] = length
        last_resizer[resource] = id
      }
    }
    assert_true(handles.length() <= 8)
  }
}

///|
test "stateful generation satisfies independent state oracle at varied lengths" {
  let adapter = BufferAdapter::new()
  let coverage : Map[String, Bool] = Map([])
  for seed = 0; seed < 128; seed = seed + 1 {
    for length in [0, 1, 8, 32, 64, 256] {
      let trace = generate_stateful(seed.to_uint64(), steps=length)
      assert_true(trace.steps.length() == length)
      check_generation(trace, coverage)
      assert_true(@lab.validate_dependencies(trace) is None)
      assert_true(adapter.validate(trace) is None)
      assert_true(@lab.decode_trace(trace.encode()) == trace)
    }
  }
  for feature in [
    "op:new", "op:share", "op:close", "op:read", "op:write", "op:reject_write", "op:resize",
    "restart-after-close", "new-empty", "new-maximum", "read-after-alias-close",
    "write-after-other-alias-resize", "reject-at-end", "reject-negative",
    "grow", "shrink", "regrow-empty", "resize-empty",
  ] { assert_true(coverage.contains(feature)) }
}

///|
test "stateful generation is deterministic and independent of injected defect mode" {
  let original = generate_stateful(42UL, steps=64)
  assert_true(original == generate_stateful(42UL, steps=64))
  assert_true(original.steps != generate_stateful(43UL, steps=64).steps)
  for mode in ["nul", "share", "error"] {
    assert_true(original.steps == generate_stateful(42UL, mode~, steps=64).steps)
  }
  assert_true(original.generator_version == "buffer-stateful-1")
  assert_true(generate_stateful(42UL, steps=-1).steps.length() == 0)
  assert_true(generate_stateful(42UL, steps=300).steps.length() == 256)
}

///|
test "stateful operation schedules vary and do not append a contract suffix" {
  let schedules : Map[String, Bool] = Map([])
  let endings : Map[String, Bool] = Map([])
  for seed = 0; seed < 64; seed = seed + 1 {
    let trace = generate_stateful(seed.to_uint64(), steps=64)
    schedules[Json(trace.steps.map(step => step.op)).stringify()] = true
    endings[trace.steps[63].op] = true
  }
  assert_true(schedules.length() >= 32)
  assert_true(endings.length() >= 5)
}

///|
test "correct native binding executes stateful walks with balanced teardown" {
  for seed = 0; seed < 32; seed = seed + 1 {
    let trace = generate_stateful(seed.to_uint64(), steps=64)
    let adapter = BufferAdapter::new()
    adapter.configure(trace)
    for step in trace.steps { assert_true(adapter.execute(step) is None) }
    assert_true(adapter.teardown() is None)
  }
}
