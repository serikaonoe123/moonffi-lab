///|
fn run_native(input : @lab.Trace) -> Unit raise {
  let adapter = SqliteAdapter::new(input)
  defer {
    let _ = adapter.teardown()
  }
  assert_true(adapter.validate(input) is None)
  for step in input.steps {
    if adapter.execute(step) is Some(observed) {
      fail("\{observed.property} at \{observed.step_id}: \{observed.message}")
    }
  }
  assert_true(adapter.teardown() is None)
  assert_true(adapter.connections.is_empty() && adapter.statements.is_empty())
}

///|
test "rejected transitions preserve ready, row and exhausted model state" {
  let model = Model::new()
  assert_true(model.apply(operation_step("open", Open("db"))) is None)
  assert_true(
    model.apply(operation_step("prepare", Prepare("q", "db"))) is None,
  )
  assert_true(
    model.apply(operation_step("bind", BindText("q", "月\u{0000}🌙")))
    is None,
  )
  assert_true(model.apply(operation_step("close", Close("db"))) is Some(_))
  assert_true(model.connections.contains("db"))
  assert_true(model.apply(operation_step("step1", Step("q"))) is None)
  assert_true(
    model.apply(operation_step("rebind", BindInt("q", 27))) is Some(_),
  )
  assert_true(model.statements.get("q").unwrap().phase == Row)
  assert_true(
    model.statements.get("q").unwrap().bound == Text("月\u{0000}🌙"),
  )
  assert_true(model.apply(operation_step("step2", Step("q"))) is None)
  assert_true(model.apply(operation_step("step3", Step("q"))) is Some(_))
  assert_true(model.statements.get("q").unwrap().phase == Done)
  assert_true(model.apply(operation_step("reset", Reset("q", false))) is None)
  assert_true(
    model.statements.get("q").unwrap().bound == Text("月\u{0000}🌙"),
  )
  assert_true(model.apply(operation_step("clear", Reset("q", true))) is None)
  assert_true(model.statements.get("q").unwrap().bound == Unset)
}

///|
/// An index-based oracle uses no Model/repair/dependency implementation.
test "deletion repair matches an independent oracle for all 1024 subsets" {
  let input = trace(17UL, "correct", "sqlite-subsets-1", [
    Open("db"),
    Prepare("q", "db"),
    BindText("q", "月"),
    Step("q"),
    Read("q"),
    Reset("q", true),
    Step("q"),
    Read("q"),
    Finalize("q"),
    Close("db"),
  ])
  let adapter = SqliteAdapter::new(input)
  assert_true(adapter.validate(input) is None)
  for mask = 0; mask < 1024; mask = mask + 1 {
    let selected : Array[@lab.Step] = []
    let expected : Array[String] = []
    let mut connection = false
    let mut statement = false
    let mut phase = 0
    for index = 0; index < 10; index = index + 1 {
      if (mask & (1 << index)) == 0 {
        continue
      }
      selected.push(input.steps[index])
      let keep = match index {
        0 => {
          connection = true
          true
        }
        1 =>
          if connection {
            statement = true
            phase = 0
            true
          } else {
            false
          }
        2 => statement && phase == 0
        3 | 6 =>
          if statement && phase < 2 {
            phase += 1
            true
          } else {
            false
          }
        4 | 7 => statement && phase == 1
        5 =>
          if statement {
            phase = 0
            true
          } else {
            false
          }
        8 =>
          if statement {
            statement = false
            true
          } else {
            false
          }
        _ =>
          if connection && !statement {
            connection = false
            true
          } else {
            false
          }
      }
      if keep {
        expected.push(input.steps[index].id)
      }
    }
    let candidate = input.with_steps(selected)
    let repaired = adapter.repair(candidate)
    assert_true(repaired.trace.steps.map(step => step.id) == expected)
    assert_true(@lab.check_repair(candidate, repaired) is None)
    assert_true(adapter.validate(repaired.trace) is None)
  }
  // Removing reset changes the second step into end-of-results, so the later
  // read must be deleted even though every declared handle still exists.
  let deleted_reset = input.with_steps(
    input.steps.filter(step => step.id != "s5"),
  )
  let repaired = adapter.repair(deleted_reset)
  assert_true(
    repaired.removed.length() == 1 && repaired.removed[0].step_id == "s7",
  )
}

///|
test "unchanged upstream preserves text, null and integer values across reset" {
  for text in text_values() {
    run_native(
      trace(0UL, "correct", "sqlite-text-corpus-1", [
        Open("db"),
        Prepare("q", "db"),
        BindText("q", text),
        BusyClose("db"),
        Step("q"),
        Read("q"),
        Reset("q", false),
        Step("q"),
        Read("q"),
        Reset("q", true),
        Step("q"),
        Read("q"),
        Finalize("q"),
        Close("db"),
      ]),
    )
  }
  for value in [-1000000, -73, -1, 0, 1, 73, 1000000] {
    run_native(
      trace(0UL, "correct", "sqlite-integer-corpus-1", [
        Open("db"),
        Prepare("q", "db"),
        BindInt("q", value),
        Step("q"),
        Read("q"),
        Reset("q", false),
        Step("q"),
        Read("q"),
        Finalize("q"),
        Close("db"),
      ]),
    )
  }
}

///|
test "cleanup handles unfinished statements on independent connections" {
  let input = trace(1UL, "correct", "sqlite-cleanup-1", [
    Open("a"),
    Open("b"),
    Prepare("q", "a"),
    Prepare("r", "b"),
    BindText("q", "left"),
    Step("q"),
    BindInt("r", 17),
    Step("r"),
    Read("q"),
    Read("r"),
  ])
  run_native(input)
}

///|
test "generated walks are bounded, deterministic and exercise every operation" {
  let coverage : Map[String, Bool] = Map([])
  let adapter = SqliteAdapter::new(generate(0UL, "correct", 0))
  for seed = 0; seed < 256; seed = seed + 1 {
    let input = generate_walk(seed.to_uint64(), "correct", 64)
    assert_true(input.steps.length() == 64 && adapter.validate(input) is None)
    assert_true(input == generate_walk(seed.to_uint64(), "correct", 64))
    for step in input.steps {
      coverage[step.op] = true
    }
  }
  for
    op in [
      "open", "prepare", "bind_text", "bind_int", "step", "read", "reset", "busy_close",
      "finalize", "close",
    ] {
    assert_true(coverage.contains(op))
  }
  assert_true(generate_walk(0UL, "correct", -1).steps.is_empty())
  assert_true(generate_walk(0UL, "correct", 300).steps.length() == 256)
  assert_true(generate(0UL, "correct", 0).steps.is_empty())
  assert_true(
    generate_walk(0UL, "correct", 64).steps !=
    generate_walk(1UL, "correct", 64).steps,
  )
}

///|
test "native generated walks use the external binding and explicit teardown" {
  for seed = 0; seed < 32; seed = seed + 1 {
    run_native(generate_walk(seed.to_uint64(), "correct", 64))
  }
}

///|
test "invalid declarations and modes are rejected before target execution" {
  let input = generate(0UL, "correct", 32)
  let adapter = SqliteAdapter::new(input)
  assert_true(
    adapter.validate(input.with_steps([{ ..input.steps[0], defines: [], }]))
    is Some(_),
  )
  assert_true(adapter.validate(generate(0UL, "mutant", 32)) is Some(_))
  let too_large = trace(0UL, "correct", "invalid-1", [
    Open("db"),
    Prepare("q", "db"),
    BindInt("q", 1000001),
  ])
  assert_true(adapter.validate(too_large) is Some(_))
  assert_true(adapter.connections.is_empty() && adapter.statements.is_empty())
}

///|
test "argument candidates preserve dependencies and concrete trace metadata" {
  let input = generate(0UL, "correct", 0)
  let adapter = SqliteAdapter::new(input)
  for
    operation in [
      BindInt("q", 73),
      BindInt("q", -73),
      BindText("q", "月\u{0000}🌙"),
    ] {
    let original = operation_step("stable", operation)
    let candidates = adapter.shrink_arguments(original)
    assert_true(!candidates.is_empty())
    for candidate in candidates {
      assert_true({ ..candidate, args: original.args, } == original)
    }
  }
  assert_true(adapter.connections.is_empty() && adapter.statements.is_empty())
}
