///| Audit query is a test-only FFI; it does not increment target-call counts.
extern "C" fn native_calls() -> Int = "starter_counter_calls"

///| Empty/short trajectories and model generation must remain pure, even when
/// adapter construction and validation are repeated across many fresh states.
test "explicit contracts generate exact short traces and valid walks without native calls" {
  let before = native_calls()
  for count = 0; count <= 3; count = count + 1 {
    let input = generate_contract(17UL, "correct", count)
    let adapter = @lab.ContractAdapter::new(CounterContract::new(), ContractCounterTarget::new(input))
    assert_true(input.steps.length() == count && adapter.validate(input) is None)
  }
  for seed = 0UL; seed < 32UL; seed = seed + 1UL {
    let input = generate_contract_walk(seed, "correct", 128)
    let adapter = @lab.ContractAdapter::new(CounterContract::new(), ContractCounterTarget::new(input))
    assert_true(input.steps.length() == 128 && adapter.validate(input) is None)
    assert_true(input == generate_contract_walk(seed, "correct", 128))
    let forged = { ..input, environment: { "fixture_mode": "unknown" } }
    assert_true(adapter.validate(forged) is Some(_))
  }
  assert_true(native_calls() == before)
}

///| Exercise the public helper from a separate module, keeping operation and
/// dependency declarations intact. Domain-invalid proposals are still generated
/// and left to validation; candidate generation must never call the C target.
test "public integer candidates preserve metadata and expose both error boundaries" {
  let before = native_calls()
  for sign in [-1, 1] {
    let input = trace(17UL, "error", "integer-candidates-1", [New("a", sign), RejectAdd("a", sign * 200)])
    let adapter = CounterAdapter::new(input)
    assert_true(adapter.validate(input) is None)
    for operation in [New("a", sign * 90), Add("a", sign * 80), RejectAdd("a", sign * 200)] {
      let original = operation_step("candidate", operation)
      let candidates = adapter.shrink_arguments(original)
      assert_true(!candidates.is_empty())
      for candidate in candidates {
        assert_true({ ..candidate, args: original.args } == original)
        assert_true(@lab.arguments_simpler(candidate.args, original.args))
      }
    }
    let proposals = adapter.shrink_arguments(input.steps[1])
    let boundary = operation_step(input.steps[1].id, RejectAdd("a", sign * 100))
    assert_true(proposals.contains(boundary))
    assert_true(adapter.validate(input.with_steps([input.steps[0], boundary])) is None)
    let below = operation_step(input.steps[1].id, RejectAdd("a", sign * 99))
    assert_true(adapter.validate(input.with_steps([input.steps[0], below])) is Some(_))
    assert_true(adapter.shrink_arguments(operation_step("zero", Add("a", 0))).is_empty())
  }
  assert_true(native_calls() == before)
}

///| Independent scalar oracle for the one-live-counter walk. Only the native
/// branch touches the target; expected values do not use Model or repair.
fn check_walk(input : @lab.Trace, coverage : Map[String, Bool], native~ : Bool = false) -> Unit raise {
  let defined : Map[String, Bool] = Map([])
  let mut live : (String, Int)? = None
  let adapter = CounterAdapter::new(input)
  for step in input.steps {
    coverage[step.op] = true
    let operation : Operation = @json.from_json(step.args)
    match operation {
      New(id, value) => {
        assert_true(live is None && !defined.contains(id) && value >= -100 && value <= 100)
        defined[id] = true
        live = Some((id, value))
      }
      Add(id, delta) => {
        guard live is Some((current, value)) else { fail("add without counter") }
        assert_true(current == id && delta >= -200 && delta <= 200 && value + delta >= -100 && value + delta <= 100)
        live = Some((id, value + delta))
      }
      RejectAdd(id, delta) => {
        guard live is Some((current, value)) else { fail("reject without counter") }
        assert_true(current == id && delta >= -200 && delta <= 200 && (value + delta < -100 || value + delta > 100))
      }
      Check(id) => { guard live is Some((current, _)) else { fail("check without counter") }; assert_true(id == current) }
      Close(id) => { guard live is Some((current, _)) else { fail("close without counter") }; assert_true(id == current); live = None }
    }
    if native {
      assert_true(adapter.execute(step) is None)
      if live is Some((id, value)) {
        assert_true(native_value(adapter.handles.get(id).unwrap()) == value && native_live() == 1)
      } else { assert_true(native_live() == 0) }
    }
  }
  if native { assert_true(adapter.teardown() is None && native_live() == 0) }
}

///|
test "external SDK factory and candidate operations make no target calls" {
  let before = native_calls()
  let coverage : Map[String, Bool] = Map([])
  for seed = 0; seed < 128; seed = seed + 1 {
    for length in [0, 1, 8, 32, 64, 256] {
      let input = generate_walk(seed.to_uint64(), "correct", length)
      let adapter = CounterAdapter::new(input)
      assert_true(input.steps.length() == length && adapter.validate(input) is None)
      check_walk(input, coverage)
      assert_true(@lab.decode_trace(input.encode()) == input)
      let repaired = adapter.repair(input)
      assert_true(repaired.trace == input && repaired.removed.is_empty())
      for step in input.steps { let _ = adapter.shrink_arguments(step) }
    }
  }
  assert_true(native_calls() == before)
  for operation in ["new", "add", "reject_add", "check", "close"] { assert_true(coverage.contains(operation)) }
}

///|
test "external SDK repair matches a scalar oracle on all 128 subsets" {
  let input = trace(0UL, "correct", "counter-repair-test-1", [
    New("a", 90), Add("a", -80), Add("a", 50), Check("a"), RejectAdd("a", 200), Check("a"), Close("a"),
  ])
  let adapter = CounterAdapter::new(input)
  assert_true(adapter.validate(input) is None)
  for mask = 0; mask < 128; mask = mask + 1 {
    let selected : Array[@lab.Step] = []
    let expected : Array[String] = []
    let mut live = false
    let mut value = 0
    for index = 0; index < 7; index = index + 1 {
      if (mask & (1 << index)) == 0 { continue }
      selected.push(input.steps[index])
      let keep = match index {
        0 => { live = true; value = 90; true }
        1 => if live && value - 80 >= -100 { value -= 80; true } else { false }
        2 => if live && value + 50 <= 100 { value += 50; true } else { false }
        3 | 5 => live
        4 => live && value + 200 > 100
        _ => if live { live = false; true } else { false }
      }
      if keep { expected.push(input.steps[index].id) }
    }
    let candidate = input.with_steps(selected)
    let repaired = adapter.repair(candidate)
    assert_true(repaired.trace.steps.map(step => step.id) == expected)
    assert_true(@lab.check_repair(candidate, repaired) is None && adapter.validate(repaired.trace) is None)
  }
  let repaired = adapter.repair(input.with_steps([input.steps[0], input.steps[2], input.steps[3]]))
  assert_true(repaired.removed.length() == 1 && repaired.removed[0].reason == "add precondition violated")
}

///|
test "rejected transitions preserve pure state and forged declarations are rejected" {
  let model = Model::new()
  assert_true(model.apply(operation_step("n", New("a", 90))) is None)
  assert_true(model.apply(operation_step("bad-add", Add("a", 20))) is Some(_))
  assert_true(model.values.get("a") == Some(90))
  assert_true(model.apply(operation_step("bad-error", RejectAdd("a", 0))) is Some(_))
  assert_true(model.values.get("a") == Some(90))
  let input = generate(0UL, "correct", 8)
  let adapter = CounterAdapter::new(input)
  assert_true(adapter.validate(input.with_steps([{ ..input.steps[0], defines: [] }])) is Some(_))
  assert_true(adapter.validate(generate(0UL, "unknown", 8)) is Some(_))
}

///|
test "correct native walks and labelled error fixture clean up deterministically" {
  let coverage : Map[String, Bool] = Map([])
  for seed = 0; seed < 32; seed = seed + 1 { check_walk(generate_walk(seed.to_uint64(), "correct", 64), coverage, native=true) }
  for mode in ["correct", "error"] {
    let input = generate(17UL, mode, 32)
    let adapter = CounterAdapter::new(input)
    let mut found : @lab.Failure? = None
    for step in input.steps { if adapter.execute(step) is Some(failure) { found = Some(failure); break } }
    if mode == "correct" { assert_true(found is None) } else {
      guard found is Some(failure) else { fail("teaching error fixture did not fail") }
      assert_true(failure.property == "counter-value" && failure.step_id == "s30")
    }
    assert_true(adapter.teardown() is None && native_live() == 0)
  }
}

///|
test "registered walk is reproducible, mode-independent and bounded" {
  let input = generate_walk(42UL, "correct", 64)
  assert_eq(input.generator_version, "counter-walk-2")
  assert_true(input == generate_walk(42UL, "correct", 64))
  assert_true(input.steps == generate_walk(42UL, "error", 64).steps)
  assert_true(input.steps != generate_walk(43UL, "correct", 64).steps)
  assert_true(generate_walk(42UL, "correct", -1).steps.is_empty())
  assert_true(generate_walk(42UL, "correct", 300).steps.length() == 256)
  assert_true(generate(42UL, "correct", 0).steps.is_empty())
}
