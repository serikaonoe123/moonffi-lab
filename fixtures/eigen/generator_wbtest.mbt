///| Independent oracle uses nested row arrays, unlike the adapter's flat
/// Model and transpose helper. It never calls repair or generation state.
fn check_eigen_generation(trace : @lab.Trace, coverage : Map[String, Bool], native~ : Bool = false) -> Unit raise {
  let grids : Map[String, Array[Array[Int]]] = Map([])
  let defined : Map[String, Bool] = Map([])
  let parents : Map[String, String] = Map([])
  let adapter = EigenAdapter::new()
  for step in trace.steps {
    coverage["op:\{step.op}"] = true
    let operation : Operation = @json.from_json(step.args)
    match operation {
      New(id, rows, cols, data) => {
        assert_true(!defined.contains(id) && rows >= 1 && rows <= 4 && cols >= 1 && cols <= 4)
        assert_true(data.length() == rows * cols && data.all(v => v >= -100 && v <= 100))
        assert_true(step.op == "new" && step.defines == [id] && step.uses == [] && step.releases == [])
        if grids.is_empty() && !defined.is_empty() { coverage["restart-after-drop"] = true }
        coverage["shape:\{rows}:\{cols}"] = true
        if data.contains(-100) { coverage["minimum-value"] = true }
        if data.contains(100) { coverage["maximum-value"] = true }
        grids[id] = Array::makei(rows, r => Array::makei(cols, c => data[r * cols + c]))
        defined[id] = true
      }
      Set(id, row, col, value) => {
        assert_true(grids.contains(id))
        let grid = grids.get(id).unwrap()
        assert_true(row >= 0 && row < grid.length() && col >= 0 && col < grid[0].length() && value >= -100 && value <= 100)
        assert_true(step.op == "set" && step.defines == [] && step.uses == [id] && step.releases == [])
        let copy = grid.map(line => line.copy())
        copy[row][col] = value
        grids[id] = copy
        if row == grid.length() - 1 && col == grid[0].length() - 1 { coverage["set-last-index"] = true }
        if parents.contains(id) { coverage["set-transpose"] = true }
        if parents.keys().any(child => grids.contains(child) && parents.get(child) == Some(id)) {
          coverage["set-source-after-transpose"] = true
        }
      }
      Check(id) => {
        assert_true(grids.contains(id))
        assert_true(step.op == "check" && step.defines == [] && step.uses == [id] && step.releases == [])
        if parents.get(id) is Some(parent) && !grids.contains(parent) { coverage["check-after-source-drop"] = true }
      }
      Transpose(id, other) => {
        assert_true(grids.contains(id) && !defined.contains(other))
        assert_true(step.op == "transpose" && step.defines == [other] && step.uses == [id] && step.releases == [])
        let grid = grids.get(id).unwrap()
        let rows = grid.length()
        let cols = grid[0].length()
        grids[other] = Array::makei(cols, c => Array::makei(rows, r => grid[r][c]))
        defined[other] = true
        parents[other] = id
        if rows != cols { coverage["rectangular-transpose"] = true }
        if parents.contains(id) { coverage["transpose-chain"] = true }
      }
      RejectAdd(a, b) => {
        assert_true(grids.contains(a) && grids.contains(b))
        let left = grids.get(a).unwrap()
        let right = grids.get(b).unwrap()
        assert_true(left.length() != right.length() || left[0].length() != right[0].length())
        assert_true(step.op == "reject_add" && step.defines == [] && step.uses == [a, b] && step.releases == [])
        if left.length() == right.length() { coverage["reject-same-rows"] = true }
        if left[0].length() == right[0].length() { coverage["reject-same-cols"] = true }
      }
      Drop(id) => {
        assert_true(grids.contains(id))
        assert_true(step.op == "drop" && step.defines == [] && step.uses == [] && step.releases == [id])
        grids.remove(id)
      }
    }
    assert_true(grids.length() <= 8)
    if native {
      assert_true(adapter.execute(step) is None)
      assert_true(adapter.handles.length() == grids.length())
      for id in grids.keys() {
        let expected = grids.get(id).unwrap()
        let matrix = adapter.handles.get(id).unwrap()
        assert_true(matrix.rows() == expected.length() && matrix.cols() == expected[0].length())
        guard matrix.to_array() is Ok(values) else { fail("native array export failed") }
        assert_true(values.length() == expected.length() * expected[0].length())
        for r, line in expected {
          for c, value in line { assert_true(values[r * line.length() + c] == value.to_double()) }
        }
      }
    }
  }
  if native {
    assert_true(adapter.teardown() is None)
    assert_true(adapter.handles.is_empty() && adapter.models.is_empty())
  }
}

///|
test "Eigen stateful walks satisfy an independent shape and dependency oracle" {
  let coverage : Map[String, Bool] = Map([])
  let adapter = EigenAdapter::new()
  for seed = 0; seed < 128; seed = seed + 1 {
    for length in [0, 1, 8, 32, 64, 256] {
      let trace = generate_stateful(seed.to_uint64(), steps=length)
      assert_true(trace.steps.length() == length)
      check_eigen_generation(trace, coverage)
      assert_true(@lab.validate_dependencies(trace) is None && adapter.validate(trace) is None)
      assert_true(@lab.decode_trace(trace.encode()) == trace)
    }
  }
  for feature in [
    "op:new", "op:set", "op:check", "op:transpose", "op:reject_add", "op:drop",
    "restart-after-drop", "minimum-value", "maximum-value", "set-last-index",
    "set-transpose", "set-source-after-transpose", "check-after-source-drop",
    "rectangular-transpose", "transpose-chain", "reject-same-rows", "reject-same-cols",
  ] { assert_true(coverage.contains(feature)) }
  for rows = 1; rows <= 4; rows = rows + 1 {
    for cols = 1; cols <= 4; cols = cols + 1 { assert_true(coverage.contains("shape:\{rows}:\{cols}")) }
  }
}

///|
test "Eigen exploration is deterministic, bounded and keeps provenance" {
  let trace = generate_stateful(42UL, steps=64)
  assert_true(trace == generate_stateful(42UL, steps=64))
  assert_true(trace.steps != generate_stateful(43UL, steps=64).steps)
  assert_true(trace.steps == generate_stateful(42UL, mode="unsupported", steps=64).steps)
  assert_true(EigenAdapter::new().validate(generate_stateful(42UL, mode="unsupported")) is Some(_))
  assert_true(trace.generator_version == "eigen-stateful-1")
  assert_true(trace.environment == generate(42UL).environment)
  assert_true(generate_stateful(42UL, steps=-1).steps.is_empty())
  assert_true(generate_stateful(42UL, steps=300).steps.length() == 256)
}

///|
test "Eigen stateful schedules vary without a fixed contract ending" {
  let schedules : Map[String, Bool] = Map([])
  let endings : Map[String, Bool] = Map([])
  for seed = 0; seed < 64; seed = seed + 1 {
    let trace = generate_stateful(seed.to_uint64(), steps=64)
    schedules[Json(trace.steps.map(step => step.op)).stringify()] = true
    endings[trace.steps[63].op] = true
  }
  assert_true(schedules.length() >= 32 && endings.length() >= 5)
}

///|
test "Eigen native random walks agree with an independent full numerical oracle" {
  let coverage : Map[String, Bool] = Map([])
  for seed = 0; seed < 32; seed = seed + 1 {
    check_eigen_generation(generate_stateful(seed.to_uint64(), steps=64), coverage, native=true)
  }
  assert_true(coverage.contains("set-transpose") && coverage.contains("set-source-after-transpose"))
}

///| Deliberately corrupt the adapter's native-handle table, not the vendored
/// binding. A target-only Set check would miss the changed transpose here.
test "Eigen mutation oracle catches accidental aliasing of a different matrix" {
  let adapter = EigenAdapter::new()
  assert_true(adapter.execute(operation_step("new", New("a", 2, 2, [1, 1, 1, 1]))) is None)
  assert_true(adapter.execute(operation_step("transpose", Transpose("a", "b"))) is None)
  adapter.handles["b"] = adapter.handles.get("a").unwrap()
  guard adapter.execute(operation_step("write", Set("a", 0, 0, 99))) is Some(found) else {
    fail("cross-matrix alias was not observed")
  }
  assert_true(found.property == "matrix-values" && found.step_id == "write")
  assert_true(adapter.teardown() is None)
}
