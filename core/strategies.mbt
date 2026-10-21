///| Concrete, bounded FFI value domains. Floating values are represented by
/// their exact IEEE bits; text and bytes are tagged to retain typed shrink order.
pub(all) enum ArgumentStrategy {
  Boolean
  Signed32(Int, Int)
  Signed64(Int64, Int64)
  Unsigned32(UInt, UInt)
  Unsigned64(UInt64, UInt64)
  Float64(Bool, Bool) // allow NaN, allow infinity
  Text(Int, Int) // Unicode scalar count, not UTF-16 code units
  ByteBuffer(Int, Int)
  Sequence(ArgumentStrategy, Int, Int)
  Optional(ArgumentStrategy)
}

///| Reject invalid and excessively large recursive domains before allocating.
fn ArgumentStrategy::cost(self : ArgumentStrategy, depth : Int) -> Result[Int, String] {
  if depth > 4 { return Err("strategy nesting exceeds four") }
  match self {
    Signed32(lo, hi) => if lo > hi { Err("inverted Int bounds") } else { Ok(1) }
    Signed64(lo, hi) => if lo > hi { Err("inverted Int64 bounds") } else { Ok(1) }
    Unsigned32(lo, hi) => if lo > hi { Err("inverted UInt bounds") } else { Ok(1) }
    Unsigned64(lo, hi) => if lo > hi { Err("inverted UInt64 bounds") } else { Ok(1) }
    Text(lo, hi) | ByteBuffer(lo, hi) => {
      if lo < 0 || lo > hi || hi > 256 { Err("length bounds must lie in 0..256") } else { Ok(hi + 1) }
    }
    Sequence(element, lo, hi) => {
      if lo < 0 || lo > hi || hi > 256 { return Err("length bounds must lie in 0..256") }
      match element.cost(depth + 1) {
        Err(message) => Err(message)
        Ok(cost) => if cost > 4095 / (if hi == 0 { 1 } else { hi }) { Err("strategy exceeds 4096 value budget") } else { Ok(cost * hi + 1) }
      }
    }
    Optional(element) => match element.cost(depth + 1) {
      Err(message) => Err(message)
      Ok(value) => if value >= 4096 { Err("strategy exceeds 4096 value budget") } else { Ok(value + 1) }
    }
    _ => Ok(1)
  }
}

///| Decimal number tokens retain UInt64/Int64 precision through trace JSON.
fn exact_integer(value : String) -> Json { try! @json.parse(value) }
///|
fn signed_value(value : Json) -> Int64? {
  guard value is Number(_, ..) else { return None }
  try { Some(@json.from_json(Json(value.stringify()))) } catch { _ => None }
}
///|
fn unsigned_value(value : Json) -> UInt64? {
  guard value is Number(_, ..) else { return None }
  try { Some(@json.from_json(Json(value.stringify()))) } catch { _ => None }
}
///|
pub fn encode_float64(value : Double) -> Json {
  { "$ffi_f64": value.reinterpret_as_uint64().to_string() }
}
///|
pub fn decode_float64(value : Json) -> Double? {
  guard value is Object(fields) && fields.length() == 1 && fields.get("$ffi_f64") is Some(bits) else { return None }
  let bits : UInt64 = try { @json.from_json(bits) } catch { _ => return None }
  Some(bits.reinterpret_as_double())
}
///|
pub fn encode_text(value : String) -> Json { { "$ffi_text": value } }
///|
pub fn decode_text(value : Json) -> String? {
  guard value is Object(fields) && fields.length() == 1 && fields.get("$ffi_text") is Some(String(text)) else { return None }
  for char in text.iter() {
    let scalar = char.to_int()
    if scalar >= 0xd800 && scalar <= 0xdfff { return None }
  }
  Some(text)
}
///|
pub fn encode_bytes(value : Bytes) -> Json {
  { "$ffi_bytes": value.to_array().map(byte => byte.to_int()) }
}
///|
pub fn decode_bytes(value : Json) -> Bytes? {
  guard value is Object(fields) && fields.length() == 1 && fields.get("$ffi_bytes") is Some(Array(items)) else { return None }
  let bytes : Array[Byte] = []
  for item in items {
    guard signed_value(item) is Some(number) && number >= 0L && number <= 255L else { return None }
    bytes.push(number.to_int().to_byte())
  }
  Some(Bytes::from_array(bytes))
}

///|
fn sample_unsigned(random : @splitmix.RandomState, lo : UInt64, hi : UInt64) -> UInt64 {
  let selector = random.next_uint(limit=8U)
  if selector == 0U { return lo }
  if selector == 1U { return hi }
  let width = hi - lo + 1UL
  lo + (if width == 0UL { random.next_uint64() } else { random.next_uint64(limit=width) })
}
///|
fn sample_signed(random : @splitmix.RandomState, lo : Int64, hi : Int64) -> Int64 {
  if lo <= 0L && hi >= 0L && random.next_uint(limit=8U) == 0U { return 0L }
  let width = hi.reinterpret_as_uint64() - lo.reinterpret_as_uint64() + 1UL
  let offset = if width == 0UL { random.next_uint64() } else { random.next_uint64(limit=width) }
  let selector = random.next_uint(limit=8U)
  if selector == 0U { lo } else if selector == 1U { hi } else { (lo.reinterpret_as_uint64() + offset).reinterpret_as_int64() }
}

///|
fn ArgumentStrategy::draw(self : ArgumentStrategy, random : @splitmix.RandomState) -> Json {
  match self {
    Boolean => Json(random.next_uint(limit=2U) == 1U)
    Signed32(lo, hi) => exact_integer(sample_signed(random, lo.to_int64(), hi.to_int64()).to_string())
    Signed64(lo, hi) => exact_integer(sample_signed(random, lo, hi).to_string())
    Unsigned32(lo, hi) => exact_integer(sample_unsigned(random, lo.to_uint64(), hi.to_uint64()).to_string())
    Unsigned64(lo, hi) => exact_integer(sample_unsigned(random, lo, hi).to_string())
    Float64(allow_nan, allow_infinity) => {
      let boundaries : Array[UInt64] = [0UL, 0x8000000000000000UL, 1UL, 0x8000000000000001UL,
        0x0010000000000000UL, 0x3ff0000000000000UL, 0xbff0000000000000UL,
        0x7fefffffffffffffUL, 0x7ff0000000000000UL, 0xfff0000000000000UL, 0x7ff8000000000001UL]
      let mut bits = if random.next_uint(limit=2U) == 0U {
        boundaries[random.next_uint(limit=boundaries.length().reinterpret_as_uint()).reinterpret_as_int()]
      } else { random.next_uint64() }
      if (bits & 0x7fffffffffffffffUL) > 0x7ff0000000000000UL && !allow_nan { bits = bits & 0xffefffffffffffffUL }
      if (bits & 0x7fffffffffffffffUL) == 0x7ff0000000000000UL && !allow_infinity { bits = bits & 0xffefffffffffffffUL }
      encode_float64(bits.reinterpret_as_double())
    }
    Text(lo, hi) => {
      let count = sample_unsigned(random, lo.to_uint64(), hi.to_uint64()).to_int()
      let chars : Array[Char] = []
      let boundaries : Array[Char] = ['\u0000', 'a', '\n', '"', '\\', '中', '😀', '\u{0301}']
      for _i = 0; _i < count; _i = _i + 1 {
        let char = if random.next_uint(limit=2U) == 0U {
          boundaries[random.next_uint(limit=boundaries.length().reinterpret_as_uint()).reinterpret_as_int()]
        } else {
          let scalar = random.next_uint(limit=0x10f800U).reinterpret_as_int()
          (if scalar >= 0xd800 { scalar + 0x800 } else { scalar }).unsafe_to_char()
        }
        chars.push(char)
      }
      encode_text(String::from_iter(chars.iter()))
    }
    ByteBuffer(lo, hi) => {
      let count = sample_unsigned(random, lo.to_uint64(), hi.to_uint64()).to_int()
      encode_bytes(Bytes::makei(count, _ => random.next_uint(limit=256U).reinterpret_as_int().to_byte()))
    }
    Sequence(element, lo, hi) => {
      let count = sample_unsigned(random, lo.to_uint64(), hi.to_uint64()).to_int()
      Json(Array::makei(count, _ => element.draw(random)))
    }
    Optional(element) => if random.next_uint(limit=4U) == 0U { Json::null() } else { element.draw(random) }
  }
}

///| Generation is deterministic for this version and seed; save the resulting
/// concrete value rather than depending on future generator implementations.
pub fn ArgumentStrategy::generate(self : ArgumentStrategy, seed : UInt64) -> Result[Json, String] {
  match self.cost(0) {
    Err(message) => Err(message)
    Ok(_) => Ok(self.draw(@splitmix.RandomState(seed~)))
  }
}

///|
pub fn ArgumentStrategy::accepts(self : ArgumentStrategy, value : Json) -> Bool {
  if self.cost(0) is Err(_) { return false }
  match self {
    Boolean => value is True || value is False
    Signed32(lo, hi) => signed_value(value) is Some(number) && number >= lo.to_int64() && number <= hi.to_int64()
    Signed64(lo, hi) => signed_value(value) is Some(number) && number >= lo && number <= hi
    Unsigned32(lo, hi) => unsigned_value(value) is Some(number) && number >= lo.to_uint64() && number <= hi.to_uint64()
    Unsigned64(lo, hi) => unsigned_value(value) is Some(number) && number >= lo && number <= hi
    Float64(allow_nan, allow_infinity) => {
      guard decode_float64(value) is Some(number) else { return false }
      let magnitude = number.reinterpret_as_uint64() & 0x7fffffffffffffffUL
      if magnitude > 0x7ff0000000000000UL { allow_nan } else if magnitude == 0x7ff0000000000000UL { allow_infinity } else { true }
    }
    Text(lo, hi) => decode_text(value) is Some(text) && text.iter().count() >= lo && text.iter().count() <= hi
    ByteBuffer(lo, hi) => decode_bytes(value) is Some(bytes) && bytes.length() >= lo && bytes.length() <= hi
    Sequence(element, lo, hi) => value is Array(items) && items.length() >= lo && items.length() <= hi && items.all(item => element.accepts(item))
    Optional(element) => value is Null || element.accepts(value)
  }
}

///|
fn shrink_unsigned(value : UInt64) -> Array[UInt64] {
  if value == 0UL { return [] }
  let values = [0UL]
  let mut distance = value / 2UL
  while distance != 0UL { values.push(value - distance); distance = distance / 2UL }
  values
}

///| Each proposal is domain checked, unique and strictly smaller in the typed
/// order. At most 128 are returned, so recursive strategies remain bounded.
pub fn ArgumentStrategy::shrink(self : ArgumentStrategy, value : Json) -> Result[Array[Json], String] {
  if !self.accepts(value) { return Err("value is outside strategy domain") }
  let proposed : Array[Json] = []
  match self {
    Boolean => if value is True { proposed.push(Json(false)) }
    Signed32(_, _) | Signed64(_, _) => for number in shrink_int64(signed_value(value).unwrap()) { proposed.push(exact_integer(number.to_string())) }
    Unsigned32(lo, _) => {
      proposed.push(exact_integer(lo.to_string()))
      for number in shrink_unsigned(unsigned_value(value).unwrap()) { proposed.push(exact_integer(number.to_string())) }
    }
    Unsigned64(lo, _) => {
      proposed.push(exact_integer(lo.to_string()))
      for number in shrink_unsigned(unsigned_value(value).unwrap()) { proposed.push(exact_integer(number.to_string())) }
    }
    Float64(_, _) => {
      let bits = decode_float64(value).unwrap().reinterpret_as_uint64()
      proposed.push(encode_float64(0.0))
      let sign = bits & 0x8000000000000000UL
      for magnitude in shrink_unsigned(bits & 0x7fffffffffffffffUL) { proposed.push(encode_float64((sign | magnitude).reinterpret_as_double())) }
    }
    Text(lo, _) => {
      let chars = decode_text(value).unwrap().iter().to_array()
      for items in shrink_sequence(chars, lo, char => if char == '\u0000' { [] } else { ['\u0000'] }) {
        proposed.push(encode_text(String::from_iter(items.iter())))
      }
    }
    ByteBuffer(lo, _) => {
      let bytes = decode_bytes(value).unwrap().to_array()
      for items in shrink_sequence(bytes, lo, byte => shrink_unsigned(byte.to_uint64()).map(number => number.to_int().to_byte())) {
        proposed.push(encode_bytes(Bytes::from_array(items)))
      }
    }
    Sequence(element, lo, _) => {
      guard value is Array(values) else { return Err("expected array") }
      for items in shrink_sequence(values, lo, item => element.shrink(item).unwrap()) { proposed.push(Json(items)) }
    }
    Optional(element) => if !(value is Null) {
      proposed.push(Json::null())
      for item in element.shrink(value).unwrap() { proposed.push(item) }
    }
  }
  let seen : Map[String, Bool] = Map([])
  let kept : Array[Json] = []
  for candidate in proposed {
    let key = candidate.stringify()
    if self.accepts(candidate) && ffi_arguments_simpler(candidate, value) && !seen.contains(key) {
      kept.push(candidate)
      seen[key] = true
      if kept.length() == 128 { break }
    }
  }
  Ok(kept)
}

///|
fn[T] shrink_sequence(values : Array[T], minimum : Int, shrink : (T) -> Array[T]) -> Array[Array[T]] {
  let result : Array[Array[T]] = []
  if values.length() > minimum { result.push(values[:minimum].to_owned()) }
  let mut width = values.length() / 2
  if width < 1 { width = 1 }
  while width > 0 {
    let mut index = 0
    while index + width <= values.length() && values.length() - width >= minimum {
      result.push(values[:index].to_owned() + values[index + width:].to_owned())
      if result.length() == 128 { return result }
      index += width
    }
    if width == 1 { break }
    width = (width + 1) / 2
  }
  for index, value in values {
    for simpler in shrink(value) {
      let candidate = values.copy()
      candidate[index] = simpler
      result.push(candidate)
      if result.length() == 128 { return result }
    }
  }
  result
}
