///| Frozen prefix validator from 3b3e108, used only by this synthetic probe.
/// It does not call the new production dependency validator.
fn prefix_dependencies(trace : @lab.Trace) -> String? {
  if trace.schema != 1 { return Some("unsupported trace schema") }
  if trace.steps.length() > 4096 { return Some("trace exceeds 4096 steps") }
  let ids : Map[String, Bool] = Map([])
  let defined : Map[String, Bool] = Map([])
  let live : Map[String, Bool] = Map([])
  for step in trace.steps {
    if step.id == "" || ids.contains(step.id) { return Some("empty or duplicate step ID: \{step.id}") }
    ids[step.id] = true
    for handle in [..step.uses, ..step.releases] {
      if !live.contains(handle) { return Some("\{step.id}: unavailable handle \{handle}") }
    }
    let mentioned : Map[String, Bool] = Map([])
    for handle in step.releases {
      if mentioned.contains(handle) { return Some("\{step.id}: repeated release \{handle}") }
      mentioned[handle] = true
      live.remove(handle)
    }
    for handle in step.defines {
      if handle == "" || defined.contains(handle) { return Some("\{step.id}: duplicate or empty handle \{handle}") }
      defined[handle] = true
      live[handle] = true
    }
  }
  None
}

///| Rejection does not change the modeled accepted count.
struct DependencyProbeModel { mut accepted : Int }
///|
impl @lab.StateModel for DependencyProbeModel with fn apply(self, step) {
  if step.op == "reject" { Some("synthetic rejection") } else { self.accepted += 1; None }
}

///|
fn prefix_repair(model : DependencyProbeModel, trace : @lab.Trace) -> (@lab.Repair, Int64) {
  let kept : Array[@lab.Step] = []
  let removed : Array[@lab.Removal] = []
  let mut visits = 0L
  for step in trace.steps {
    kept.push(step)
    // Both probe profiles have structurally valid prefixes. Account for the
    // work once per call, without adding a counter to every inner map operation.
    visits += kept.length().to_int64()
    let structural = prefix_dependencies(trace.with_steps(kept))
    let error = if structural is Some(_) { structural } else { @lab.StateModel::apply(model, step) }
    if error is Some(reason) {
      let _ = kept.pop()
      removed.push({ step_id: step.id, reason })
    }
  }
  ({ trace: trace.with_steps(kept), removed }, visits)
}

///|
fn dependency_trace(size : Int, profile : String) -> @lab.Trace {
  let steps : Array[@lab.Step] = Array::makei(size, index => {
    let first = index == 0
    let reject = profile == "rejected-releases" && !first && index % 2 == 1
    { id: "s\{index}", op: if reject { "reject" } else { "ok" }, args: Json(0),
      defines: if profile == "live-handles" { ["h\{index}"] } else if first { ["h"] } else { [] },
      uses: if profile == "rejected-releases" && !first && !reject { ["h"] } else { [] },
      releases: if reject { ["h"] } else { [] } }
  })
  { schema: 1, adapter: "dependency-probe", adapter_version: "1", generator_version: "dependency-probe-1",
    seed: "0", environment: { "profile": profile }, steps }
}

///| Pure dependency repair benchmark, not subprocess or end-to-end FFI timing.
/// Alternate measurement order and retain raw milliseconds; never assert speed.
async fn check_dependency_scaling(output : String) -> Unit {
  @fs.mkdir(output, recursive=true, allow_exist=false)
  let measurements : Array[Json] = []
  for profile in ["live-handles", "rejected-releases"] {
    for size in [256, 1024, 4096] {
      let trace = dependency_trace(size, profile)
      @fs.write_file(output + "/" + profile + "-" + size.to_string() + ".json", trace.encode())
      for repetition = 0; repetition < 3; repetition = repetition + 1 {
        let incremental_model : DependencyProbeModel = { accepted: 0 }
        let prefix_model : DependencyProbeModel = { accepted: 0 }
        // Values are assigned in both branches to keep the two timed regions
        // independent of equality checks, serialization, and evidence IO.
        let (actual, expected, visits, incremental_ms, prefix_ms) = if repetition % 2 == 0 {
          let started = @async.now()
          let actual = @lab.repair_with_model(incremental_model, trace)
          let incremental_ms = @async.now() - started
          let started = @async.now()
          let (expected, visits) = prefix_repair(prefix_model, trace)
          (actual, expected, visits, incremental_ms, @async.now() - started)
        } else {
          let started = @async.now()
          let (expected, visits) = prefix_repair(prefix_model, trace)
          let prefix_ms = @async.now() - started
          let started = @async.now()
          let actual = @lab.repair_with_model(incremental_model, trace)
          (actual, expected, visits, @async.now() - started, prefix_ms)
        }
        assert_true(actual.trace == expected.trace && actual.removed == expected.removed)
        assert_true(incremental_model.accepted == prefix_model.accepted)
        assert_true(@lab.validate_dependencies(actual.trace) is None && @lab.check_repair(trace, actual) is None)
        assert_true(prefix_dependencies(actual.trace) is None)
        let expected_kept = if profile == "live-handles" { size } else { size / 2 }
        assert_true(actual.trace.steps.length() == expected_kept)
        measurements.push({
          "profile": Json(profile), "steps": Json(size), "repetition": Json(repetition + 1),
          "order": Json(if repetition % 2 == 0 { "incremental-first" } else { "prefix-first" }),
          "kept": Json(actual.trace.steps.length()), "removed": Json(actual.removed.length()),
          "reference_dependency_visits": Json(visits.to_string()),
          "incremental_ms": Json(incremental_ms.to_string()), "prefix_ms": Json(prefix_ms.to_string()),
          "equivalent": true,
        })
      }
    }
  }
  @fs.write_file(output + "/checks.json", Json(measurements).stringify(indent=2))
  println("MoonBit dependency scaling checks passed: " + output)
}
