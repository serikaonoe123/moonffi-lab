///|
test "integer descent accepts same width and nested numeric simplification" {
  assert_true(arguments_simpler(Json(0), Json(9)))
  assert_true(arguments_simpler(Json(-1), Json(-9)))
  assert_true(arguments_simpler(Json(10), Json(99)))
  assert_true(arguments_simpler(
    @json.parse("{\"tag\":\"write\",\"values\":[1,-2],\"live\":true,\"extra\":null}"),
    @json.parse("{\"extra\":null,\"live\":true,\"values\":[9,-9],\"tag\":\"write\"}"),
  ))
}

///|
test "integer ordering preserves exact digits beyond Double and Int64" {
  for pair in [
    ("9007199254740992", "9007199254740993"),
    ("18446744073709551614", "18446744073709551615"),
    ("-9223372036854775807", "-9223372036854775808"),
    ("999999999999999999999999999998", "999999999999999999999999999999"),
  ] {
    let (small, large) = pair
    let a = @json.parse(small)
    let b = @json.parse(large)
    assert_true(arguments_simpler(a, b))
    assert_true(!arguments_simpler(b, a))
    assert_true(!arguments_simpler(a, a))
    assert_true(arguments_simpler({ "values": [a], "tag": "exact" }, { "values": [b], "tag": "exact" }))
  }
  // Both large values round to the same Double. The increase must still veto
  // a decrease in the other component, rather than masquerading as equality.
  assert_true(!arguments_simpler(
    @json.parse("[0,9007199254740993]"), @json.parse("[9,9007199254740992]"),
  ))
}

///|
test "equal width descent rejects compensation and unrelated changes" {
  for pair in [
    ("[0,9]", "[9,0]"),
    ("{\"a\":0,\"b\":\"y\"}", "{\"a\":9,\"b\":\"x\"}"),
    ("{\"b\":0}", "{\"a\":9}"),
    ("[0,0]", "[9,9,9]"),
    ("-9", "-1"),
    ("-1", "1"),
    ("0.1", "0.9"),
  ] {
    let (candidate, original) = pair
    // The changed array shape is tested directly: shorter encodings remain
    // allowed by the original rule, but cannot enter the equal-length order.
    assert_true(integer_descent(@json.parse(candidate), @json.parse(original)) is None)
  }
  assert_true(!arguments_simpler(@json.parse("[0,9]"), @json.parse("[9,0]")))
  assert_true(!arguments_simpler(
    Json::number(1.0, repr="1e0"), Json::number(9.0, repr="9e0"),
  ))
}

///|
test "shorter encodings retain existing adapter behavior" {
  assert_true(arguments_simpler(Json(""), Json("long payload")))
  assert_true(arguments_simpler(Json(0), Json(-1)))
  assert_true(arguments_simpler(@json.parse("[0]"), @json.parse("[1,2]")))
  assert_true(!arguments_simpler(Json(99), Json(1)))
  assert_true(!arguments_simpler(Json("y"), Json("x")))
}

///| An independent bounded integer oracle checks the public gate, including
/// the intentional priority of shorter encodings over numeric magnitude.
test "integer gate agrees with exhaustive signed decimal oracle" {
  for original = -40; original <= 40; original = original + 1 {
    for candidate = -40; candidate <= 40; candidate = candidate + 1 {
      let a = candidate.to_string().length()
      let b = original.to_string().length()
      let small = if candidate < 0 { -candidate } else { candidate }
      let large = if original < 0 { -original } else { original }
      let expected = a < b || (a == b && small < large)
      assert_true(arguments_simpler(Json(candidate), Json(original)) == expected)
    }
  }
}

///|
test "step equality distinguishes rounded large integers in nested inputs" {
  let a = @json.parse("[0,9007199254740992]")
  let b = @json.parse("[0,9007199254740993]")
  // Demonstrate the underlying representation hazard independently of Step.
  assert_true(a == b)
  let original = { ..sample_step("number"), args: a }
  let rewritten = { ..original, args: b }
  assert_true(original != rewritten)
  assert_true(rewritten != original)
  assert_true(original == original)
  assert_true(sample_trace([original]) != sample_trace([rewritten]))
}

///|
test "deletion-only repair rejects numerically rounded concrete rewrites" {
  let step = { ..sample_step("number"), args: @json.parse("{\"values\":[9007199254740992]}") }
  let trace = sample_trace([sample_step("noise"), step])
  let changed = { ..step, args: @json.parse("{\"values\":[9007199254740993]}") }
  let repaired = trace.with_steps([changed])
  assert_true(!deletion_only(trace, repaired))
  assert_true(check_repair(trace, {
    trace: repaired, removed: [{ step_id: "noise", reason: "irrelevant" }],
  }) is Some(_))
}

///|
test "exact step equality ignores object key order and survives trace replay" {
  let original = { ..sample_step("exact"), args: @json.parse("{\"large\":18446744073709551615,\"tag\":\"x\"}") }
  let reordered = { ..original, args: @json.parse("{\"tag\":\"x\",\"large\":18446744073709551615}") }
  assert_true(original == reordered)
  let trace = sample_trace([sample_step("noise"), original])
  let repair : Repair = {
    trace: trace.with_steps([reordered]), removed: [{ step_id: "noise", reason: "irrelevant" }],
  }
  assert_true(check_repair(trace, repair) is None)
  assert_true(decode_trace(trace.encode()) == trace)
}
