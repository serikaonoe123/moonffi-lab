///|
test "Eigen arithmetic walks satisfy an independent grid oracle" {
  let coverage : Map[String, Bool] = Map([])
  let adapter = EigenAdapter::new()
  for seed = 0; seed < 128; seed = seed + 1 {
    for length in [0, 1, 8, 32, 64, 256] {
      let trace = generate_arithmetic(seed.to_uint64(), steps=length)
      assert_true(trace.steps.length() == length)
      check_eigen_generation(trace, coverage)
      assert_true(adapter.validate(trace) is None)
      assert_true(@lab.decode_trace(trace.encode()) == trace)
      assert_true(adapter.repair(trace).trace == trace)
    }
  }
  for feature in ["op:add", "op:mul", "self-add", "self-mul", "rectangular-mul",
    "arithmetic-chain", "set-arithmetic-result", "set-operand-with-result-live", "check-result-after-operand-drop"] {
    assert_true(coverage.contains(feature))
  }
  let trace = generate_arithmetic(42UL, steps=64)
  assert_true(trace == generate_arithmetic(42UL, steps=64))
  assert_true(trace.steps != generate_arithmetic(43UL, steps=64).steps)
  assert_true(trace.steps == generate_arithmetic(42UL, mode="unsupported", steps=64).steps)
  assert_true(adapter.validate(generate_arithmetic(42UL, mode="unsupported")) is Some(_))
  assert_true(trace.generator_version == "eigen-arithmetic-1")
  assert_true(trace.environment == generate(42UL).environment)
  assert_true(generate_arithmetic(42UL, steps=-1).steps.is_empty())
  assert_true(generate_arithmetic(42UL, steps=300).steps.length() == 256)
}

///|
test "Eigen native arithmetic walks agree with independent grid values" {
  let coverage : Map[String, Bool] = Map([])
  for seed = 0; seed < 32; seed = seed + 1 {
    check_eigen_generation(generate_arithmetic(seed.to_uint64(), steps=64), coverage, native=true)
  }
  for feature in ["op:add", "op:mul", "self-add", "self-mul", "rectangular-mul"] {
    assert_true(coverage.contains(feature))
  }
}

///| Rectangular, signed operands make operand order and row/column layout
/// observable. Expected products are literal, independently worked values.
test "Eigen rectangular products and sums own independent storage" {
  let adapter = EigenAdapter::new()
  let prefix = [
    New("a", 2, 3, [1, -2, 3, 4, 5, -6]),
    New("b", 3, 2, [7, 8, -9, 10, 11, -12]),
    Mul("a", "b", "ab"), Mul("b", "a", "ba"),
    Add("ab", "ab", "sum"),
  ]
  for i, op in prefix { assert_true(adapter.execute(operation_step("p\{i}", op)) is None) }
  assert_true(adapter.handles.get("ab").unwrap().to_array() == Ok([58.0, -48.0, -83.0, 154.0]))
  assert_true(adapter.handles.get("ba").unwrap().to_array() == Ok([39.0, 26.0, -27.0, 31.0, 68.0, -87.0, -37.0, -82.0, 105.0]))
  assert_true(adapter.handles.get("sum").unwrap().to_array() == Ok([116.0, -96.0, -166.0, 308.0]))
  let suffix = [
    Set("ab", 0, 0, 99), Set("sum", 1, 1, -99),
    Set("a", 1, 2, 100), Set("b", 2, 1, -100),
    Drop("a"), Drop("b"), Check("ab"), Check("ba"), Check("sum"),
  ]
  for i, op in suffix { assert_true(adapter.execute(operation_step("s\{i}", op)) is None) }
  let trace = generate_arithmetic(0UL).with_steps((prefix + suffix).mapi((i, op) => operation_step("s\{i}", op)))
  assert_true(EigenAdapter::new().validate(trace) is None)
  check_eigen_generation(trace, Map([]), native=true)
  assert_true(adapter.teardown() is None)
}

///| Rejected steps must not mutate model state. Near-limit cancellation also
/// checks that only stored results, not the sum of absolute terms, are capped.
test "Eigen arithmetic bounds reject before mutation and permit cancellation" {
  let state = EigenState::new()
  for i, op in [New("a", 1, 1, [100]), Mul("a", "a", "p"), Mul("p", "a", "q")] {
    assert_true(state.apply(operation_step("s\{i}", op)) is None)
  }
  assert_true(state.models.get("q").unwrap().data == [1000000L])
  assert_true(state.apply(operation_step("too-large", Mul("q", "a", "r"))) is Some(_))
  assert_true(state.models.length() == 3 && !state.models.contains("r"))
  assert_true(state.models.get("q").unwrap().data == [1000000L])
  assert_true(state.apply(operation_step("set", Set("q", 0, 0, 1))) is None)
  assert_true(state.apply(operation_step("retry", Mul("q", "a", "r"))) is None)
  assert_true(state.models.get("r").unwrap().data == [100L])
  assert_true(state.apply(operation_step("new", New("wide", 1, 2, [1, 2]))) is None)
  for i, op in [Add("wide", "a", "bad-add"), Mul("wide", "a", "bad-mul")] {
    assert_true(state.apply(operation_step("bad\{i}", op)) is Some(_))
  }
  assert_true(state.models.length() == 5)
  let cancel = generate_arithmetic(0UL).with_steps([
    operation_step("a", New("a", 1, 2, [100, -100])),
    operation_step("b", New("b", 2, 1, [100, 100])),
    operation_step("zero", Mul("a", "b", "zero")),
    operation_step("p", Mul("b", "a", "p")),
    operation_step("q", Mul("a", "p", "q")),
    operation_step("neg", New("neg", 1, 1, [-100])),
    operation_step("sq", Mul("neg", "neg", "sq")),
    operation_step("limit", Mul("sq", "neg", "limit")),
    operation_step("double", Add("limit", "limit", "too-small")),
  ])
  let adapter = EigenAdapter::new()
  assert_true(adapter.validate(cancel) is Some(_))
  let allowed = cancel.with_steps(Array::makei(8, i => cancel.steps[i]))
  assert_true(adapter.validate(allowed) is None)
  check_eigen_generation(allowed, Map([]), native=true)
  let large_cancel = cancel.with_steps([
    operation_step("row", New("row", 1, 4, [100, 100, -100, -100])),
    operation_step("col", New("col", 4, 1, [100, 100, 100, 100])),
    operation_step("scalar", New("scalar", 1, 1, [100])),
    operation_step("square", Mul("scalar", "scalar", "square")),
    operation_step("left", Mul("square", "row", "left")),
    operation_step("right", Mul("col", "square", "right")),
    operation_step("zero", Mul("left", "right", "zero")),
  ])
  assert_true(adapter.validate(large_cancel) is None)
  // Terms reach +/-10^12 and sequential partial sums reach 2*10^12.
  check_eigen_generation(large_cancel, Map([]), native=true)
}

///| Exhaust all 128 subsets using a separate scalar interpreter. Deleting
/// the Set can make a later Mul exceed the bound despite intact dependencies.
test "Eigen repair agrees with exhaustive scalar subsets after arithmetic" {
  let base = generate_arithmetic(0UL).with_steps([
    operation_step("0", New("a", 1, 1, [100])),
    operation_step("1", Mul("a", "a", "p")),
    operation_step("2", Mul("p", "a", "q")),
    operation_step("3", Set("q", 0, 0, 1)),
    operation_step("4", Mul("q", "a", "r")),
    operation_step("5", Check("r")), operation_step("6", Drop("r")),
  ])
  let adapter = EigenAdapter::new()
  for mask = 0; mask < 128; mask = mask + 1 {
    let values : Map[String, Int64] = Map([])
    let selected : Array[@lab.Step] = []
    let expected : Array[String] = []
    for i = 0; i < 7; i = i + 1 {
      if (mask & (1 << i)) == 0 { continue }
      selected.push(base.steps[i])
      let keep = match i {
        0 => { values["a"] = 100L; true }
        1 | 2 | 4 => {
          let (left, right, out) = match i { 1 => ("a", "a", "p"); 2 => ("p", "a", "q"); _ => ("q", "a", "r") }
          if values.get(left) is Some(x) && values.get(right) is Some(y) && (x * y).abs() <= 1000000L {
            values[out] = x * y
            true
          } else { false }
        }
        3 => if values.contains("q") { values["q"] = 1L; true } else { false }
        5 => values.contains("r")
        _ => if values.contains("r") { values.remove("r"); true } else { false }
      }
      if keep { expected.push(i.to_string()) }
    }
    let proposal = base.with_steps(selected)
    let repaired = adapter.repair(proposal)
    assert_true(repaired.trace.steps.map(s => s.id) == expected)
    assert_true(@lab.check_repair(proposal, repaired) is None)
    assert_true(adapter.validate(repaired.trace) is None)
    if mask == 119 {
      assert_true(repaired.trace.steps.map(s => s.id) == ["0", "1", "2"])
      assert_true(repaired.removed.any(item => item.step_id == "4" && item.reason.contains("exact-integer bound")))
    }
  }
}

///| A labelled oracle probe changes only the test's handle table. Both
/// directions of unintended sharing must be seen in the same mutating step.
test "Eigen arithmetic mutation oracle detects aliased results and operands" {
  for multiply in [false, true] {
    for mutate_result in [false, true] {
      let adapter = EigenAdapter::new()
      let right = if multiply { [1, 0, 0, 1] } else { [0, 0, 0, 0] }
      let op = if multiply { Mul("a", "b", "out") } else { Add("a", "b", "out") }
      for i, operation in [New("a", 2, 2, [1, 1, 1, 1]), New("b", 2, 2, right), op] {
        assert_true(adapter.execute(operation_step("s\{i}", operation)) is None)
      }
      adapter.handles["out"] = adapter.handles.get("a").unwrap()
      let target = if mutate_result { "out" } else { "a" }
      guard adapter.execute(operation_step("write", Set(target, 0, 0, 99))) is Some(found) else {
        fail("arithmetic sharing was not observed")
      }
      assert_true(found.property == "matrix-values" && found.step_id == "write")
      assert_true(adapter.teardown() is None)
    }
  }
}
