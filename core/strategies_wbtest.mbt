///| Exercise all public domains with independent bounds/encoding checks and
/// pairwise reverse-edge rejection, rather than comparing to another generator.
test "FFI strategies generate bounded deterministic values with strictly descending candidates" {
  let strategies : Array[ArgumentStrategy] = [Boolean, Signed32(-17, 29), Signed64(-9223372036854775808L, 9223372036854775807L),
    Unsigned32(0U, 4294967295U), Unsigned64(0UL, 18446744073709551615UL), Float64(false, false), Float64(true, true),
    Text(0, 12), Text(3, 3), ByteBuffer(0, 12), ByteBuffer(4, 4), Sequence(Boolean, 0, 8),
    Sequence(Optional(Signed64(-99L, 99L)), 2, 8), Optional(Float64(true, true)), Optional(Text(1, 6))]
  for strategy in strategies {
    for seed = 0UL; seed < 96UL; seed = seed + 1UL {
      let value = strategy.generate(seed).unwrap()
      assert_true(strategy.accepts(value))
      assert_true(value.stringify() == strategy.generate(seed).unwrap().stringify())
      let decoded = @json.parse(value.stringify())
      assert_true(decoded.stringify() == value.stringify() && strategy.accepts(decoded))
      let seen : Map[String, Bool] = Map([])
      let candidates = strategy.shrink(value).unwrap()
      assert_true(candidates.length() <= 128)
      for candidate in candidates {
        assert_true(strategy.accepts(candidate) && ffi_arguments_simpler(candidate, value))
        assert_true(!ffi_arguments_simpler(value, candidate) && !ffi_arguments_simpler(candidate, candidate))
        assert_true(!seen.contains(candidate.stringify()))
        seen[candidate.stringify()] = true
      }
    }
  }
}

///| Small finite domains permit an exhaustive graph check: a cycle would need
/// at least one nondecreasing independently computed rank.
test "boolean optional and fixed-length text shrink orders cannot reverse through JSON size" {
  let boolean = ArgumentStrategy::Boolean
  assert_true(boolean.shrink(Json(true)).unwrap().map(value => value.stringify()) == ["false"])
  assert_true(boolean.shrink(Json(false)).unwrap().is_empty())
  assert_true(ffi_arguments_simpler(Json(false), Json(true)))
  assert_true(!ffi_arguments_simpler(Json(true), Json(false)))
  for value in [Json(true), Json(false), encode_float64(-0.0), encode_text("😀")] {
    assert_true(ffi_arguments_simpler(Json::null(), value))
    assert_true(!ffi_arguments_simpler(value, Json::null()))
  }
  for text in ["a", "中", "😀", "\n", "\u0000"] {
    let strategy = ArgumentStrategy::Text(1, 1)
    let original = encode_text(text)
    let candidates = strategy.shrink(original).unwrap()
    for candidate in candidates {
      let small = decode_text(candidate).unwrap()
      assert_true(small.iter().count() == 1 && small < text)
    }
    if text != "\u0000" { assert_true(candidates.length() == 1 && decode_text(candidates[0]) == Some("\u0000")) }
  }
  assert_true(!ffi_arguments_simpler({ "a": false, "b": 9 }, { "a": true, "b": 0 }))
  assert_true(!ffi_arguments_simpler({ "a": true, "b": 0 }, { "a": false, "b": 9 }))
}

///|
test "wide signed and unsigned decimal arguments retain every bit" {
  for text in ["-9223372036854775808", "-9007199254740993", "9007199254740993", "9223372036854775807"] {
    let value = @json.parse(text)
    let strategy = ArgumentStrategy::Signed64(-9223372036854775808L, 9223372036854775807L)
    assert_true(value.stringify() == text && strategy.accepts(value))
    let original = signed_value(value).unwrap()
    for smaller in strategy.shrink(value).unwrap() {
      let candidate = signed_value(smaller).unwrap()
      assert_true(if original < 0L { candidate > original && candidate <= 0L } else { candidate < original && candidate >= 0L })
    }
  }
  let full = ArgumentStrategy::Unsigned64(0UL, 18446744073709551615UL)
  let maximum = @json.parse("18446744073709551615")
  assert_true(full.accepts(maximum) && unsigned_value(maximum) == Some(18446744073709551615UL))
  for candidate in full.shrink(maximum).unwrap() { assert_true(unsigned_value(candidate).unwrap() < 18446744073709551615UL) }
  assert_true(!full.accepts(@json.parse("-1")) && !full.accepts(@json.parse("18446744073709551616")))
  assert_true(!full.accepts(@json.parse("1.0", preserve_number_repr=true)) && !full.accepts(Json("123")))
  assert_true(!full.accepts(@json.parse("9007199254740993.0", preserve_number_repr=true)))
}

///|
test "IEEE roundtrip preserves negative zero subnormal infinities and NaN payloads" {
  let allowed = ArgumentStrategy::Float64(true, true)
  let finite = ArgumentStrategy::Float64(false, false)
  for bits in [0UL, 0x8000000000000000UL, 1UL, 0x8000000000000001UL, 0x7fefffffffffffffUL,
    0x7ff0000000000000UL, 0xfff0000000000000UL, 0x7ff8000000000001UL, 0x7ff8000000000002UL] {
    let encoded = encode_float64(bits.reinterpret_as_double())
    let decoded = decode_float64(@json.parse(encoded.stringify())).unwrap()
    assert_true(decoded.reinterpret_as_uint64() == bits && allowed.accepts(encoded))
    assert_true(finite.accepts(encoded) == ((bits & 0x7fffffffffffffffUL) < 0x7ff0000000000000UL))
    for candidate in allowed.shrink(encoded).unwrap() {
      let smaller = decode_float64(candidate).unwrap().reinterpret_as_uint64()
      assert_true((smaller & 0x7fffffffffffffffUL) < (bits & 0x7fffffffffffffffUL) ||
        ((smaller & 0x7fffffffffffffffUL) == (bits & 0x7fffffffffffffffUL) && smaller < bits))
    }
  }
  assert_true(allowed.shrink(encode_float64(0.0)).unwrap().is_empty())
}

///|
test "strategy configuration and malformed concrete values fail explicitly" {
  let invalid : Array[ArgumentStrategy] = [Signed32(1, -1), Signed64(1L, -1L), Unsigned32(3U, 2U), Unsigned64(3UL, 2UL),
    Text(-1, 5), Text(6, 5), ByteBuffer(0, 257), Sequence(Sequence(ByteBuffer(256, 256), 256, 256), 256, 256),
    Optional(Optional(Optional(Optional(Optional(Boolean)))))]
  for strategy in invalid {
    assert_true(strategy.generate(17UL) is Err(_))
    assert_true(!strategy.accepts(Json::null()) && strategy.shrink(Json::null()) is Err(_))
  }
  assert_true(decode_bytes({ "$ffi_bytes": [-1] }) is None)
  assert_true(decode_bytes({ "$ffi_bytes": [256] }) is None)
  assert_true(decode_bytes({ "$ffi_bytes": [1.5] }) is None)
  assert_true(decode_float64({ "$ffi_f64": "18446744073709551616" }) is None)
  assert_true(decode_text({ "$ffi_text": "a", "extra": 1 }) is None)
  let isolated_surrogate = try { Some(@json.parse("{\"$ffi_text\":\"\\ud800\"}")) } catch { _ => None }
  if isolated_surrogate is Some(value) { assert_true(decode_text(value) is None) }
  let input = contract_template().with_steps([contract_step("number", "add", 1)])
  let text = input.encode().replace(old="\"args\": 1", new="\"args\": 9007199254740993.0")
  let decoded = decode_trace(text)
  assert_true(decoded.steps[0].args.stringify() == "9007199254740993.0")
  assert_true(!ArgumentStrategy::Signed64(-9223372036854775808L, 9223372036854775807L).accepts(decoded.steps[0].args))
}
