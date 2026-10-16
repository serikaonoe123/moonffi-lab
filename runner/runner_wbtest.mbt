///|
fn test_trace() -> @lab.Trace {
  { schema: 1, adapter: "test", adapter_version: "1", generator_version: "1", seed: "1",
    environment: Map([]), steps: [{ id: "stable-id", op: "read", args: Json::null(), defines: [], uses: [], releases: [] }] }
}

///|
fn test_events() -> Array[Event] {
  [{ kind: "step_begin", step_id: "stable-id", index: 0 },
   { kind: "step_end", step_id: "stable-id", index: 0 },
   { kind: "teardown_begin", step_id: "", index: 1 },
   { kind: "teardown_end", step_id: "", index: 1 }]
}

///|
test "JSONL accepts complete records and ignores a torn final record" {
  let event = test_events()[0]
  let text = event.to_json().stringify() + "\n{incomplete"
  let events = complete_events(text)
  assert_true(events.length() == 1)
  assert_true(events[0].step_id == "stable-id")
}

///|
test "completion requires every step and confirmed teardown" {
  let result : @lab.Completion = { protocol: 1, completed: true, executed: 1, failure: None }
  assert_true(check_protocol(test_trace(), test_events(), result) is None)
  assert_true(check_protocol(test_trace(), test_events(), { ..result, executed: 0 }) is Some(_))
  let events = test_events()
  let _ = events.pop()
  assert_true(check_protocol(test_trace(), events, result) is Some(_))
}

///|
test "a plausible completion cannot hide forged operation evidence" {
  let result : @lab.Completion = { protocol: 1, completed: true, executed: 1, failure: None }
  let events = test_events()
  events[0] = { ..events[0], step_id: "wrong-id" }
  assert_true(check_protocol(test_trace(), events, result) is Some(_))
  let failure : @lab.Failure = { property: "p", step_id: "wrong-id", message: "bad" }
  assert_true(check_protocol(test_trace(), test_events(), { ..result, failure: Some(failure) }) is Some(_))
}

///|
test "malformed complete JSONL records are errors" {
  let parsed = try { let _ = complete_events("not-json\n"); true } catch { _ => false }
  assert_true(!parsed)
}

///|
test "argument reduction preserves operation identity and dependency semantics" {
  let original = test_trace().steps[0]
  assert_true(same_operation(original, { ..original, args: Json(0) }))
  assert_true(!same_operation(original, { ..original, id: "another-id" }))
  assert_true(!same_operation(original, { ..original, op: "another-operation" }))
  assert_true(!same_operation(original, { ..original, defines: ["new-handle"] }))
  assert_true(!same_operation(original, { ..original, uses: ["another-handle"] }))
  assert_true(!same_operation(original, { ..original, releases: ["old-handle"] }))
}

///|
test "sanitizer classification requires matching header and summary" {
  assert_true(asan_category("clang_rt.asan_dynamic-x86_64.dll") is None)
  assert_true(asan_category("ERROR: AddressSanitizer: heap-buffer-overflow") is None)
  assert_true(asan_category("ERROR: AddressSanitizer: heap-buffer-overflow\nSUMMARY: AddressSanitizer: heap-use-after-free") is None)
  assert_true(asan_category("==123==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x123\nSUMMARY: AddressSanitizer: heap-buffer-overflow file.c:1") == Some("heap-buffer-overflow"))
  let report = make_report(MemoryError, "canary", Some(1), None, 0, 1L, None)
  assert_true(report.exit_code() == 1)
}
