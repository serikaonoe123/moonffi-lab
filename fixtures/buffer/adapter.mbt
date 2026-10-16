///|
enum Operation {
  New(String, String)
  Share(String, String)
  Close(String)
  Read(String)
  Write(String, Int, Int)
  RejectWrite(String, Int)
} derive(ToJson, @json.FromJson)

///|
pub struct BufferAdapter {
  handles : Map[String, Handle]
  model : Map[String, Array[Byte]]
  mut mode : Int
}

///|
pub fn BufferAdapter::new() -> BufferAdapter {
  { handles: Map([]), model: Map([]), mode: 0 }
}

///|
pub fn supported_modes() -> Array[String] { ["correct", "nul", "share", "error", "crash", "hang"] }

///|
fn mode_number(name : String) -> Int {
  match name {
    "correct" => 0
    "nul" => 1
    "share" => 2
    "error" => 3
    "crash" => 4
    "hang" => 5
    _ => -1
  }
}

///|
fn operation_step(id : String, operation : Operation) -> @lab.Step {
  let (op, defines, uses, releases) = match operation {
    New(id, _) => ("new", [id], [], [])
    Share(id, other) => ("share", [other], [id], [])
    Close(id) => ("close", [], [], [id])
    Read(id) => ("read", [], [id], [])
    Write(id, _, _) => ("write", [], [id], [])
    RejectWrite(id, _) => ("reject_write", [], [id], [])
  }
  { id, op, defines, uses, releases, args: operation.to_json() }
}

///|
pub impl @lab.Adapter for BufferAdapter with fn identity(_) { "buffer" }

///|
pub impl @lab.Adapter for BufferAdapter with fn version(_) { "1" }

///| A fresh pure model validates all arguments and dependency declarations.
/// This never calls the native fixture and never mutates worker state.
pub impl @lab.Adapter for BufferAdapter with fn validate(_, trace) {
  let mode = trace.environment.get("fixture_mode").unwrap_or("correct")
  if mode_number(mode) < 0 { return Some("unknown fixture mode") }
  if trace.environment.get("profile").unwrap_or("behavior") != "behavior" {
    return Some("unsupported detector profile: this build provides behavior checks only")
  }
  let model : Map[String, Int] = Map([])
  for step in trace.steps {
    let operation : Operation = try { @json.from_json(step.args) } catch {
      _ => return Some("\{step.id}: invalid operation payload")
    }
    let expected = operation_step(step.id, operation)
    if expected.op != step.op || expected.defines != step.defines ||
      expected.uses != step.uses || expected.releases != step.releases {
      return Some("\{step.id}: dependency declarations do not match operation")
    }
    match operation {
      New(id, hex) => {
        let bytes = try { @hex.decode(hex) } catch { _ => return Some("invalid byte encoding") }
        if bytes.length() > 256 { return Some("buffer exceeds 256 bytes") }
        model[id] = bytes.length()
      }
      Share(id, other) => {
        guard model.get(id) is Some(length) else { return Some("share source unavailable") }
        model[other] = length
      }
      Close(id) => model.remove(id)
      Read(id) => if !model.contains(id) { return Some("read source unavailable") }
      Write(id, index, value) => {
        guard model.get(id) is Some(length) else { return Some("write source unavailable") }
        if index < 0 || index >= length || value < 0 || value > 255 {
          return Some("write precondition violated")
        }
      }
      RejectWrite(id, index) => {
        guard model.get(id) is Some(length) else { return Some("write source unavailable") }
        if index >= 0 && index < length { return Some("reject_write requires invalid index") }
      }
    }
  }
  None
}

///|
fn mismatch(step : @lab.Step, property : String, message : String) -> @lab.Failure? {
  Some({ step_id: step.id, property, message })
}

///| Only worker code invokes this method. A new instance is created in every worker.
pub impl @lab.Adapter for BufferAdapter with fn execute(self, step) {
  let operation : Operation = try! @json.from_json(step.args)
  match operation {
    New(id, hex) => {
      let bytes = try! @hex.decode(hex)
      self.handles[id] = native_new(bytes, bytes.length(), self.mode)
      self.model[id] = bytes.to_array()
    }
    Share(id, other) => {
      self.handles[other] = native_share(self.handles.get(id).unwrap())
      self.model[other] = self.model.get(id).unwrap()
    }
    Close(id) => {
      native_close(self.handles.get(id).unwrap(), self.mode)
      self.handles.remove(id)
      self.model.remove(id)
    }
    Read(id) => {
      native_probe(self.mode)
      let handle = self.handles.get(id).unwrap()
      if native_alive(handle) != 1 { return mismatch(step, "shared-reference-alive", "a valid open alias lost its native resource") }
      let actual = native_read(handle).to_array()
      let expected = self.model.get(id).unwrap()
      if actual != expected {
        return mismatch(step, "bytes-roundtrip", "native bytes differ from the model (including embedded NUL)")
      }
    }
    Write(id, index, value) => {
      let handle = self.handles.get(id).unwrap()
      if native_alive(handle) != 1 { return mismatch(step, "shared-reference-alive", "write alias lost its native resource") }
      if native_write(handle, index, value, self.mode) != 0 { return mismatch(step, "valid-write", "valid byte write rejected") }
      self.model.get(id).unwrap()[index] = value.to_byte()
    }
    RejectWrite(id, index) => {
      let handle = self.handles.get(id).unwrap()
      if native_write(handle, index, 0, self.mode) != -1 { return mismatch(step, "invalid-index-rejected", "invalid write did not return an error") }
    }
  }
  None
}

///|
pub impl @lab.Adapter for BufferAdapter with fn teardown(self) {
  for handle in self.handles.values() { native_close(handle, 0) }
  self.handles.clear()
  self.model.clear()
  if native_live() != 0 {
    Some({ property: "resource-balance", step_id: "teardown", message: "native resources remain after explicit close" })
  } else { None }
}

///|
pub impl @lab.Adapter for BufferAdapter with fn shrink_arguments(_, step) {
  let operation : Operation = try! @json.from_json(step.args)
  match operation {
    New(id, hex) => {
      let bytes = try! @hex.decode(hex)
      let candidates : Array[@lab.Step] = []
      if bytes.length() > 1 {
        candidates.push(operation_step(step.id, New(id, "00")))
        candidates.push(operation_step(step.id, New(id, @hex.encode(bytes[:bytes.length() / 2]))))
      }
      candidates
    }
    Write(id, index, value) => if value > 0 { [operation_step(step.id, Write(id, index, 0))] } else { [] }
    RejectWrite(id, index) => if index != -1 { [operation_step(step.id, RejectWrite(id, -1))] } else { [] }
    _ => []
  }
}

///| Configuring this field is pure; native code is invoked only by execute.
pub fn BufferAdapter::configure(self : BufferAdapter, trace : @lab.Trace) -> Unit {
  self.mode = mode_number(trace.environment.get("fixture_mode").unwrap_or("correct"))
}

///| A deterministic model-valid scenario contains noise plus three independent
/// contracts. Random bytes and writes vary by seed; the saved trace is replayed.
pub fn generate(seed : UInt64, mode~ : String = "correct", noise~ : Int = 6) -> @lab.Trace {
  let random = @splitmix.RandomState(seed~)
  let operations : Array[Operation] = []
  for i = 0; i < noise; i = i + 1 {
    let id = "noise-\{i}"
    let value = random.next_uint(limit=256U).reinterpret_as_int()
    let length = random.next_uint(limit=8U).reinterpret_as_int() + 1
    let bytes = Bytes::makei(length, _ => random.next_uint(limit=256U).reinterpret_as_int().to_byte())
    operations.push(New(id, @hex.encode(bytes[:])))
    match random.next_uint(limit=3U) {
      0U => {
        operations.push(Write(id, 0, value))
        operations.push(Read(id))
        operations.push(Close(id))
      }
      1U => {
        let shared_id = id + "-alias"
        operations.push(Share(id, shared_id))
        operations.push(Close(id))
        operations.push(Read(shared_id))
      }
      _ => {
        operations.push(RejectWrite(id, length))
        operations.push(Read(id))
        operations.push(Close(id))
      }
    }
  }
  operations.push(New("a", "410042e4b8ad"))
  operations.push(Read("a"))
  operations.push(Share("a", "b"))
  operations.push(Close("a"))
  operations.push(Read("b"))
  operations.push(RejectWrite("b", 999))
  operations.push(Read("b"))
  operations.push(Close("b"))
  {
    schema: 1, adapter: "buffer", adapter_version: "1", generator_version: "buffer-1",
    seed: seed.to_string(), environment: { "fixture_mode": mode, "profile": "behavior" },
    steps: operations.mapi((index, operation) => operation_step("s\{index}", operation)),
  }
}

///|
pub extend Operation with ToJson::{to_json}

///|
#deprecated
pub extend Operation with @json.FromJson::{from_json}

///|
pub extend BufferAdapter with @lab.Adapter::{identity, version, validate, execute, teardown, shrink_arguments}
