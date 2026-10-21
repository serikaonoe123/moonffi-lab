///|
extern "C" fn echo_i32(value : Int) -> Int = "starter_echo_i32"
///|
extern "C" fn echo_u32(value : UInt) -> UInt = "starter_echo_u32"
///|
extern "C" fn echo_i64(value : Int64) -> Int64 = "starter_echo_i64"
///|
extern "C" fn echo_u64(value : UInt64) -> UInt64 = "starter_echo_u64"
///|
extern "C" fn not_bool(value : Int) -> Int = "starter_not_bool"
///|
extern "C" fn float_bits(value : Double) -> UInt64 = "starter_float_bits"
///|
extern "C" fn float_from_bits(value : UInt64) -> Double = "starter_float_from_bits"
///|
#borrow(value)
extern "C" fn echo_bytes(value : Bytes, length : Int, mode : Int) -> Bytes = "starter_echo_bytes"
///|
#borrow(value)
extern "C" fn array_checksum(value : FixedArray[Int], length : Int) -> Int64 = "starter_array_checksum"
///|
extern "C" fn nullable_value(present : Int, value : Int64) -> Int64 = "starter_nullable_value"
///|
fn parameter_strategy(kind : String) -> @lab.ArgumentStrategy? {
  match kind {
    "bool" => Some(Boolean)
    "i32" => Some(Signed32(-2147483648, 2147483647))
    "i64" => Some(Signed64(-9223372036854775808L, 9223372036854775807L))
    "u32" => Some(Unsigned32(0U, 4294967295U))
    "u64" => Some(Unsigned64(0UL, 18446744073709551615UL))
    "f64" => Some(Float64(true, true))
    "text" => Some(Text(0, 16))
    "bytes" => Some(ByteBuffer(0, 16))
    "array" => Some(Sequence(Signed32(-64, 64), 0, 16))
    "optional" => Some(Optional(Signed64(-9223372036854775808L, 9223372036854775807L)))
    _ => None
  }
}
///|
fn exact_signed(value : Json) -> Int64 { try! @json.from_json(Json(value.stringify())) }
///|
fn exact_unsigned(value : Json) -> UInt64 { try! @json.from_json(Json(value.stringify())) }
///|
fn number_result(value : String) -> Json { try! @json.parse(value, preserve_number_repr=true) }
///|
fn parameter_step(id : String, kind : String, value : Json) -> @lab.Step {
  { id, op: kind, args: value, defines: [], uses: [], releases: [] }
}
///|
pub struct ParameterContract {}
///|
pub fn ParameterContract::new() -> ParameterContract { ParameterContract::{} }
///|
pub impl @lab.ContractModel for ParameterContract with fn initial_state(_) { Json(0) }
///|
pub impl @lab.ContractModel for ParameterContract with fn commands(_, _, _, seed) {
  ["bool", "i32", "i64", "u32", "u64", "f64", "text", "bytes", "array", "optional"].mapi((index, kind) =>
    parameter_step("", kind, parameter_strategy(kind).unwrap().generate(seed.to_uint64() + index.to_uint64()).unwrap()))
}
///|
pub impl @lab.ContractModel for ParameterContract with fn precondition(_, _, step) {
  if !step.defines.is_empty() || !step.uses.is_empty() || !step.releases.is_empty() { return Some("parameter operations have no handles") }
  guard parameter_strategy(step.op) is Some(strategy) else { return Some("unknown parameter operation") }
  if strategy.accepts(step.args) { None } else { Some("parameter outside typed domain") }
}
///|
pub impl @lab.ContractModel for ParameterContract with fn next_state(_, state, _) {
  let count : Int = try! @json.from_json(state)
  Json(count + 1)
}
///|
fn expected_parameter(step : @lab.Step) -> Json {
  match step.op {
    "bool" => Json(step.args is False)
    "array" => {
      guard step.args is Array(items) else { return Json(0) }
      let mut sum = 0L
      for index, item in items { sum += (index + 1).to_int64() * exact_signed(item) }
      number_result(sum.to_string())
    }
    "optional" => if step.args is Null { Json(0) } else { step.args }
    _ => step.args
  }
}
///|
pub impl @lab.ContractModel for ParameterContract with fn postcondition(_, _, step, actual) {
  if expected_parameter(step).stringify() == actual.stringify() { None } else { Some("C parameter result differs from exact model") }
}
///|
pub impl @lab.ContractModel for ParameterContract with fn invariant(_, state, observed) {
  if state == observed { None } else { Some("target operation count differs from model") }
}
///|
pub struct ParameterTarget { mode : Int; mut count : Int }
///|
pub fn ParameterTarget::new(trace : @lab.Trace) -> ParameterTarget {
  { mode: if trace.environment.get("fixture_mode") == Some("error") { 1 } else { 0 }, count: 0 }
}
///|
pub impl @lab.ContractTarget for ParameterTarget with fn identity(_) { "ffi-parameters" }
///|
pub impl @lab.ContractTarget for ParameterTarget with fn version(_) { "1" }
///|
pub impl @lab.ContractTarget for ParameterTarget with fn validate(_, trace) {
  if !["correct", "error"].contains(trace.environment.get("fixture_mode").unwrap_or("correct")) { Some("unknown parameter target mode") } else { None }
}
///|
pub impl @lab.ContractTarget for ParameterTarget with fn observe(self) { Json(self.count) }
///|
pub impl @lab.ContractTarget for ParameterTarget with fn close(_) { None }
///|
pub impl @lab.ContractTarget for ParameterTarget with fn invoke(self, step) {
  self.count += 1
  match step.op {
    "bool" => Json(not_bool(if step.args is True { 1 } else { 0 }) == 1)
    "i32" => number_result(echo_i32(exact_signed(step.args).to_int()).to_string())
    "i64" => number_result(echo_i64(exact_signed(step.args)).to_string())
    "u32" => number_result(echo_u32(exact_unsigned(step.args).to_uint()).to_string())
    "u64" => number_result(echo_u64(exact_unsigned(step.args)).to_string())
    "f64" => {
      let value = @lab.decode_float64(step.args).unwrap()
      let bits = float_bits(value)
      let returned = float_from_bits(bits)
      @lab.encode_float64(returned)
    }
    "text" => {
      let text = @lab.decode_text(step.args).unwrap()
      let bytes = @utf8.encode(text)
      @lab.encode_text(try! @utf8.decode(echo_bytes(bytes, bytes.length(), self.mode)))
    }
    "bytes" => {
      let bytes = @lab.decode_bytes(step.args).unwrap()
      @lab.encode_bytes(echo_bytes(bytes, bytes.length(), self.mode))
    }
    "array" => {
      guard step.args is Array(items) else { return Json(0) }
      let data = FixedArray::makei(items.length(), index => exact_signed(items[index]).to_int())
      number_result(array_checksum(data, data.length()).to_string())
    }
    "optional" => number_result(nullable_value(if step.args is Null { 0 } else { 1 }, if step.args is Null { 0L } else { exact_signed(step.args) }).to_string())
    _ => Json::null()
  }
}
///|
pub impl @lab.ContractTarget for ParameterTarget with fn shrink_arguments(_, step) {
  match parameter_strategy(step.op) {
    None => []
    Some(strategy) => match strategy.shrink(step.args) {
      Err(_) => []
      Ok(values) => values.map(args => { ..step, args })
    }
  }
}
///|
fn parameter_template(seed : UInt64, mode : String, generator : String) -> @lab.Trace {
  { schema: 1, adapter: "ffi-parameters", adapter_version: "1", generator_version: generator, seed: seed.to_string(), environment: { "fixture_mode": mode }, steps: [] }
}
///|
pub fn generate_parameters(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  let count = if steps < 1 { 1 } else if steps > 256 { 256 } else { steps }
  let input = parameter_template(seed, mode, "ffi-parameters-fixed-1")
  { ..input, steps: Array::makei(count, index =>
    if index + 1 == count { parameter_step("s\{index}", "text", @lab.encode_text("prefix\u0000中文😀suffix")) }
    else { parameter_step("s\{index}", "i64", number_result(index.to_string())) }) }
}
///|
pub fn generate_parameters_walk(seed : UInt64, mode : String, steps : Int) -> @lab.Trace {
  @lab.generate_contract_trace(ParameterContract::new(), parameter_template(seed, mode, "ffi-parameters-walk-1"), steps, seed=seed.to_uint()).unwrap()
}
///|
pub extend ParameterContract with @lab.ContractModel::{initial_state, commands, precondition, next_state, postcondition, invariant}
///|
pub extend ParameterTarget with @lab.ContractTarget::{identity, version, validate, invoke, observe, close, shrink_arguments}
