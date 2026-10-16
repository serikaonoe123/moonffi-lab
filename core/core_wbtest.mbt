///|
fn sample_step(id : String, defines~ : Array[String] = [], uses~ : Array[String] = [], releases~ : Array[String] = []) -> Step {
  { id, op: "test", args: Json::null(), defines, uses, releases }
}

///|
fn sample_trace(steps : Array[Step]) -> Trace {
  { schema: 1, adapter: "test", adapter_version: "1", generator_version: "test-1",
    seed: "18446744073709551615", environment: Map([]), steps }
}

///|
test "concrete trace roundtrip preserves seed beyond JSON numeric precision" {
  let trace = sample_trace([sample_step("1", defines=["h"]), sample_step("2", uses=["h"])])
  assert_true(decode_trace(trace.encode()) == trace)
}

///|
test "reject unsupported schema, duplicate IDs and use after close" {
  let empty = sample_trace([])
  assert_true(validate_dependencies({ ..empty, schema: 2 }) is Some(_))
  assert_true(validate_dependencies(sample_trace([sample_step("x"), sample_step("x")])) is Some(_))
  assert_true(validate_dependencies(sample_trace([
    sample_step("a", defines=["h"]), sample_step("b", releases=["h"]), sample_step("c", uses=["h"]),
  ])) is Some(_))
}

///|
test "a stable handle ID cannot be reused after release" {
  assert_true(validate_dependencies(sample_trace([
    sample_step("a", defines=["h"]), sample_step("b", releases=["h"]), sample_step("c", defines=["h"]),
  ])) is Some(_))
}

///|
test "removing an object constructor also removes transitive users" {
  let trace = sample_trace([
    sample_step("create-a", defines=["a"]),
    sample_step("share-b", defines=["b"], uses=["a"]),
    sample_step("independent", defines=["other"]),
    sample_step("read-b", uses=["b"]),
    sample_step("close-a", releases=["a"]),
  ])
  let reduced = delete_block(trace, 0, 1)
  assert_true(reduced.steps.map(s => s.id) == ["independent"])
  assert_true(validate_dependencies(reduced) is None)
}

///|
test "removing a writer does not erase unrelated consumers" {
  let trace = sample_trace([
    sample_step("new", defines=["h"]), sample_step("write", uses=["h"]), sample_step("read", uses=["h"]),
  ])
  assert_true(delete_block(trace, 1, 1).steps.map(s => s.id) == ["new", "read"])
}

///| Independent exhaustive subset oracle for a small object dependency chain.
test "block deletion agrees with subset oracle on a five step trace" {
  let steps = [
    sample_step("a", defines=["a"]), sample_step("b", uses=["a"], defines=["b"]),
    sample_step("x", defines=["x"]), sample_step("read-b", uses=["b"]), sample_step("read-x", uses=["x"]),
  ]
  for start = 0; start < 5; start = start + 1 {
    for count = 1; count <= 5 - start; count = count + 1 {
      let expected : Array[String] = []
      // A step survives iff it is outside the removed block and its constructor
      // chain survives. This oracle uses the known graph, not delete_block.
      let survives = (i : Int) => i < start || i >= start + count
      if survives(0) { expected.push("a") }
      if survives(0) && survives(1) { expected.push("b") }
      if survives(2) { expected.push("x") }
      if survives(0) && survives(1) && survives(3) { expected.push("read-b") }
      if survives(2) && survives(4) { expected.push("read-x") }
      let reduced = delete_block(sample_trace(steps), start, count)
      assert_true(reduced.steps.map(s => s.id) == expected)
      assert_true(validate_dependencies(reduced) is None)
    }
  }
}
