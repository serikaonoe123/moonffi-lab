///|
pub(all) struct Reduction {
  original_steps : Int
  reduced_steps : Int
  executions : Int
  reason : String
  confirmed : Bool
  stop_reason : String
  baseline_checks : Int
  final_checks : Int
  accepted_candidates : Int
  rejected_candidates : Int
  invalid_candidates : Int
  elapsed_ms : Int64
  baseline : @lab.Report
  strategy : String
  neighborhood_checked : Int
  neighborhood_complete : Bool
  inconclusive_neighbors : Int
  deletion_minimal : Bool
  trace : @lab.Trace
} derive(ToJson, @json.FromJson)

///| A parameter shrink may not change the operation or its dependency contract.
fn same_operation(original : @lab.Step, candidate : @lab.Step) -> Bool {
  original.id == candidate.id && original.op == candidate.op &&
    original.defines == candidate.defines && original.uses == candidate.uses &&
    original.releases == candidate.releases
}

///| Executed candidates have case-N directories with complete input and logs.
/// Non-executed invalid candidates keep their concrete input in this ledger.
async fn Controller::record_reduction(self : Controller, phase : String, decision : String, trace : @lab.Trace, report : @lab.Report?, message : String, removed~ : Array[@lab.Removal] = []) -> Unit {
  let record : Json = {
    "phase": phase, "decision": decision, "execution": self.count,
    "candidate": trace.to_json(), "report": Json(report), "message": message,
    "repair_removals": Json(removed),
  }
  @fs.write_file(self.output + "/reduction-events.jsonl", record.stringify() + "\n", append=true, create_mode=OpenExisting, sync=Data)
}

///| Budget includes stability checks and final confirmation. No candidate
/// outside the budget is executed, and every execution gets a fresh process.
pub async fn[A : @lab.Adapter] Controller::shrink(self : Controller, adapter : A, trace : @lab.Trace, budget~ : Int = 200, wall_ms~ : Int = 60000, strategy~ : String = "state") -> Reduction {
  if budget < 6 || wall_ms <= 0 { fail("shrink requires budget >= 6 and positive wall time") }
  if !["plain", "dependency", "state"].contains(strategy) { fail("unknown reduction strategy") }
  let initial_count = self.executions()
  let started = @async.now()
  let deadline = started + wall_ms.to_int64()
  @fs.mkdir(self.output, recursive=true, allow_exist=true)
  @fs.write_file(self.output + "/reduction-events.jsonl", "", create_mode=CreateNew)
  let mut best = trace
  let baseline = self.run(adapter, trace, timeout_ms=self.remaining_timeout(deadline))
  self.record_reduction("baseline", "observed", trace, Some(baseline), "")
  let mut confirmed = false
  let mut baseline_checks = 1
  let mut final_checks = 0
  let mut accepted_candidates = 0
  let mut rejected_candidates = 0
  let mut invalid_candidates = 0
  let mut neighborhood_checked = 0
  let mut neighborhood_complete = false
  let mut inconclusive_neighbors = 0
  let mut stop_reason = "unsupported_outcome"
  let reason = if baseline.outcome != PropertyFailure || baseline.fingerprint is None {
    if @async.now() >= deadline { stop_reason = "wall_budget" }
    "unsupported: reliable property fingerprint required"
  } else {
    let fingerprint = baseline.fingerprint
    let mut stable = true
    for _i = 0; _i < 2; _i = _i + 1 {
      if self.executions() - initial_count >= budget || @async.now() - started >= wall_ms.to_int64() {
        stable = false
        break
      }
      let check = self.run(adapter, best, timeout_ms=self.remaining_timeout(deadline))
      baseline_checks += 1
      self.record_reduction("baseline", "observed", best, Some(check), "")
      if check.outcome != PropertyFailure || check.fingerprint != fingerprint { stable = false; break }
    }
    if !stable {
      stop_reason = if @async.now() >= deadline { "wall_budget" } else { "unstable_baseline" }
      "baseline unconfirmed or unstable"
    } else {
      let mut width = best.steps.length() / 2
      if width < 1 { width = 1 }
      while width >= 1 {
        let mut index = 0
        while index < best.steps.length() {
          if self.executions() - initial_count >= budget - 3 || @async.now() - started >= wall_ms.to_int64() { break }
          let prepared = prepare_candidate(adapter, delete_candidate(best, index, width, strategy), strategy)
          let candidate = prepared.candidate
          if candidate.steps.length() < best.steps.length() && prepared.error is None {
            let check = self.run(adapter, candidate, timeout_ms=self.remaining_timeout(deadline))
            if check.outcome == PropertyFailure && check.fingerprint == fingerprint {
              accepted_candidates += 1
              self.record_reduction("delete_block", "accepted", candidate, Some(check), "same failure fingerprint", removed=prepared.removed)
              best = candidate
              continue
            } else {
              rejected_candidates += 1
              self.record_reduction("delete_block", "rejected", candidate, Some(check), "failure fingerprint not preserved", removed=prepared.removed)
            }
          } else {
            invalid_candidates += 1
            self.record_reduction("delete_block", "invalid", candidate, None, prepared.error.unwrap_or("candidate did not remove any step"), removed=prepared.removed)
          }
          index += width
        }
        if width == 1 { break }
        width = (width + 1) / 2
      }
      // Adapter candidates must be strictly simpler, finite, and preserve IDs.
      for index = 0; index < best.steps.length(); index = index + 1 {
        let step = best.steps[index]
        for candidate_step in adapter.shrink_arguments(step) {
          if self.executions() - initial_count >= budget - 3 || @async.now() - started >= wall_ms.to_int64() { break }
          if !same_operation(step, candidate_step) {
            invalid_candidates += 1
            let steps = best.steps.copy()
            steps[index] = candidate_step
            self.record_reduction("arguments", "invalid", best.with_steps(steps), None, "parameter candidate changed operation identity or dependencies")
            continue
          }
          // A repair may delete earlier unrelated steps. Locate the stable ID
          // again rather than indexing into a possibly shorter accepted trace.
          let mut argument_index = 0
          while argument_index < best.steps.length() && best.steps[argument_index].id != step.id { argument_index += 1 }
          if argument_index == best.steps.length() { break }
          if !@lab.arguments_simpler(candidate_step.args, best.steps[argument_index].args) { continue }
          let steps = best.steps.copy()
          steps[argument_index] = candidate_step
          let prepared = prepare_candidate(adapter, best.with_steps(steps), strategy)
          let candidate = prepared.candidate
          if prepared.error is None && candidate.steps.contains(candidate_step) {
            let check = self.run(adapter, candidate, timeout_ms=self.remaining_timeout(deadline))
            if check.outcome == PropertyFailure && check.fingerprint == fingerprint {
              accepted_candidates += 1
              self.record_reduction("arguments", "accepted", candidate, Some(check), "same failure fingerprint", removed=prepared.removed)
              best = candidate
            } else {
              rejected_candidates += 1
              self.record_reduction("arguments", "rejected", candidate, Some(check), "failure fingerprint not preserved", removed=prepared.removed)
            }
          } else {
            invalid_candidates += 1
            self.record_reduction("arguments", "invalid", candidate, None, prepared.error.unwrap_or("parameter repair removed the changed operation"), removed=prepared.removed)
          }
        }
      }
      // Parameter changes can make previously indispensable steps removable.
      let mut cursor = 0
      while cursor < best.steps.length() && self.executions() - initial_count < budget - 3 && @async.now() - started < wall_ms.to_int64() {
        let prepared = prepare_candidate(adapter, delete_candidate(best, cursor, 1, strategy), strategy)
        let candidate = prepared.candidate
        neighborhood_checked += 1
        if prepared.error is None {
          let check = self.run(adapter, candidate, timeout_ms=self.remaining_timeout(deadline))
          if check.outcome == PropertyFailure && check.fingerprint == fingerprint {
            accepted_candidates += 1
            self.record_reduction("delete_single", "accepted", candidate, Some(check), "same failure fingerprint", removed=prepared.removed)
            best = candidate
            cursor = 0
            neighborhood_checked = 0
            inconclusive_neighbors = 0
            continue
          } else {
            rejected_candidates += 1
            if check.outcome != Pass && check.outcome != PropertyFailure { inconclusive_neighbors += 1 }
            self.record_reduction("delete_single", "rejected", candidate, Some(check), "failure fingerprint not preserved", removed=prepared.removed)
          }
        } else {
          invalid_candidates += 1
          if !prepared.conclusive { inconclusive_neighbors += 1 }
          self.record_reduction("delete_single", "invalid", candidate, None, prepared.error.unwrap_or("invalid candidate"), removed=prepared.removed)
        }
        cursor += 1
      }
      neighborhood_complete = cursor == best.steps.length()
      let search_stop = if neighborhood_complete { "search_complete" }
        else if @async.now() >= deadline { "wall_budget" }
        else if self.executions() - initial_count >= budget - 3 { "execution_budget" }
        else { "search_complete" }
      while final_checks < 3 && self.executions() - initial_count < budget && @async.now() - started < wall_ms.to_int64() {
        let check = self.run(adapter, best, timeout_ms=self.remaining_timeout(deadline))
        self.record_reduction("confirmation", "observed", best, Some(check), "")
        if check.outcome != PropertyFailure || check.fingerprint != fingerprint { break }
        final_checks += 1
      }
      confirmed = final_checks == 3
      stop_reason = if confirmed { search_stop }
        else if @async.now() >= deadline { "wall_budget" }
        else if self.executions() - initial_count >= budget { "execution_budget" }
        else { "unstable_final" }
      if confirmed { "failure replayed three times; see stop_reason for search completion; no global minimality claim" }
      else { "budget exhausted or final replay unstable; result unconfirmed" }
    }
  }
  let reduction : Reduction = {
    original_steps: trace.steps.length(), reduced_steps: best.steps.length(),
    executions: self.executions() - initial_count, reason, confirmed, trace: best,
    stop_reason, baseline_checks, final_checks, accepted_candidates,
    rejected_candidates, invalid_candidates, elapsed_ms: @async.now() - started, baseline,
    strategy, neighborhood_checked, neighborhood_complete, inconclusive_neighbors,
    deletion_minimal: confirmed && neighborhood_complete && inconclusive_neighbors == 0,
  }
  @fs.mkdir(self.output, recursive=true, allow_exist=true)
  @fs.write_file(self.output + "/reduced.json", best.encode())
  @fs.write_file(self.output + "/reduction.json", reduction.to_json().stringify(indent=2))
  reduction
}

///|
priv struct Prepared {
  candidate : @lab.Trace
  removed : Array[@lab.Removal]
  error : String?
  conclusive : Bool
}

///| The three strategies use identical scheduling, budgets and failure oracle.
fn delete_candidate(trace : @lab.Trace, start : Int, count : Int, strategy : String) -> @lab.Trace {
  if strategy == "dependency" { return @lab.delete_block(trace, start, count) }
  let kept : Array[@lab.Step] = []
  for i, step in trace.steps { if i < start || i >= start + count { kept.push(step) } }
  trace.with_steps(kept)
}

///|
fn[A : @lab.Adapter] prepare_candidate(adapter : A, candidate : @lab.Trace, strategy : String) -> Prepared {
  let repair : @lab.Repair = if strategy == "state" { adapter.repair(candidate) }
    else { { trace: candidate, removed: [] } }
  if @lab.check_repair(candidate, repair) is Some(error) {
    return { candidate, removed: repair.removed, error: Some(error), conclusive: false }
  }
  let error = validate(adapter, repair.trace)
  { candidate: repair.trace, removed: repair.removed, error, conclusive: true }
}

///| A slow last candidate must not receive the entire per-case timeout after
/// most of the reduction wall budget has already elapsed. File IO/termination
/// overhead can still extend the observed wall time slightly.
fn Controller::remaining_timeout(self : Controller, deadline : Int64) -> Int {
  let remaining = deadline - @async.now()
  if remaining <= 0L { 1 }
  else if remaining < self.timeout_ms.to_int64() { remaining.to_int() }
  else { self.timeout_ms }
}
