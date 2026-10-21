///| A model whose commands deliberately include a disabled action. This tests
/// selection/repair semantics independently from the production counter adapter.
priv struct ContractSpec {}
///|
impl ContractModel for ContractSpec with fn initial_state(_) { Json(0) }
///|
fn contract_step(id : String, op : String, value : Int) -> Step {
  { id, op, args: Json(value), defines: [], uses: [], releases: [] }
}
///|
fn contract_value(value : Json) -> Int { try! @json.from_json(value) }
///|
impl ContractModel for ContractSpec with fn commands(_, _, index, _) {
  [contract_step("ignored", "take", 1), contract_step("ignored", "add", index % 3 + 1)]
}
///|
impl ContractModel for ContractSpec with fn precondition(_, state, step) {
  if step.op != "add" && step.op != "take" { return Some("unknown command") }
  let amount : Int = try { @json.from_json(step.args) } catch { _ => return Some("invalid amount") }
  if amount < 1 || amount > 3 { return Some("amount outside range") }
  if step.op == "take" && contract_value(state) < amount { Some("insufficient model balance") } else { None }
}
///|
impl ContractModel for ContractSpec with fn next_state(_, state, step) {
  Json(contract_value(state) + (if step.op == "add" { contract_value(step.args) } else { -contract_value(step.args) }))
}
///|
impl ContractModel for ContractSpec with fn postcondition(self, state, step, result) {
  if result == ContractModel::next_state(self, state, step) { None } else { Some("incorrect returned balance") }
}
///|
impl ContractModel for ContractSpec with fn invariant(_, state, observed) {
  if state == observed { None } else { Some("observed balance differs from model") }
}
///|
priv struct ContractFake {
  mut value : Int
  mut calls : Int
  mut closed : Bool
  bad_result : Bool
  drift : Bool
}
///|
impl ContractTarget for ContractFake with fn identity(_) { "contract-test" }
///|
impl ContractTarget for ContractFake with fn version(_) { "1" }
///|
impl ContractTarget for ContractFake with fn validate(_, _) { None }
///|
impl ContractTarget for ContractFake with fn invoke(self, step) {
  self.calls += 1
  self.value += if step.op == "add" { contract_value(step.args) } else { -contract_value(step.args) }
  let result = self.value
  if self.drift { self.value += 1 }
  Json(result + (if self.bad_result { 1 } else { 0 }))
}
///|
impl ContractTarget for ContractFake with fn observe(self) { Json(self.value) }
///|
impl ContractTarget for ContractFake with fn close(self) { self.closed = true; None }
///|
impl ContractTarget for ContractFake with fn shrink_arguments(_, _) { [] }
///|
fn contract_template() -> Trace {
  { schema: 1, adapter: "contract-test", adapter_version: "1", generator_version: "contract-test-1", seed: "0", environment: Map([]), steps: [] }
}
///|
fn fake_contract(bad_result~ : Bool = false, drift~ : Bool = false) -> ContractFake {
  { value: 0, calls: 0, closed: false, bad_result, drift }
}

///|
test "contract generator respects prefix legality and deterministic saved inputs" {
  let model = ContractSpec::{}
  for seed = 0U; seed < 50U; seed = seed + 1U {
    let trace = generate_contract_trace(model, contract_template(), 100, seed~).unwrap()
    assert_true(trace == generate_contract_trace(model, contract_template(), 100, seed~).unwrap())
    assert_true(validate_contract(model, trace) is None && decode_trace(trace.encode()) == trace)
    let mut balance = 0
    for index, step in trace.steps {
      assert_true(step.id == "s\{index}")
      balance += if step.op == "add" { contract_value(step.args) } else { -contract_value(step.args) }
      assert_true(balance >= 0)
    }
  }
  assert_true(generate_contract_trace(model, contract_template(), -1) is Err(_))
  assert_true(generate_contract_trace(model, contract_template(), 4097) is Err(_))
}

///|
test "contract repair deletes newly invalid commands without rewriting input" {
  let trace = { ..contract_template(), steps: [contract_step("a", "add", 2), contract_step("b", "take", 2), contract_step("c", "take", 1)] }
  assert_true(validate_contract(ContractSpec::{}, trace) is Some(_))
  let repair = repair_contract(ContractSpec::{}, trace)
  assert_true(repair.trace.steps.map(step => step.id) == ["a", "b"])
  assert_true(repair.removed.length() == 1 && repair.removed[0].step_id == "c")
  assert_true(check_repair(trace, repair) is None)
  let reduced = trace.with_steps([trace.steps[1], trace.steps[2]])
  assert_true(repair_contract(ContractSpec::{}, reduced).trace.steps.is_empty())
}

///|
test "contract adapter validates without target calls and invokes pre post transition invariant" {
  let target = fake_contract()
  let adapter = ContractAdapter::new(ContractSpec::{}, target)
  let trace = { ..contract_template(), steps: [contract_step("a", "add", 3), contract_step("b", "take", 2)] }
  assert_true(adapter.validate(trace) is None && target.calls == 0 && target.value == 0)
  for step in trace.steps { assert_true(adapter.execute(step) is None) }
  assert_true(target.calls == 2 && target.value == 1)
  assert_true(adapter.teardown() is None && target.closed)
}

///|
test "contract rejects before invoking and distinguishes postcondition and invariant failures" {
  let target = fake_contract()
  let adapter = ContractAdapter::new(ContractSpec::{}, target)
  let rejection = adapter.execute(contract_step("take", "take", 1)).unwrap()
  assert_true(rejection.property == "contract-precondition:take" && target.calls == 0)
  let bad = fake_contract(bad_result=true)
  let adapter = ContractAdapter::new(ContractSpec::{}, bad)
  let failure = adapter.execute(contract_step("add", "add", 2)).unwrap()
  assert_true(failure.property == "contract-postcondition:add" && contract_value(adapter.state) == 0)
  assert_true(adapter.teardown() is Some(_) && bad.closed)
  let drift = fake_contract(drift=true)
  let adapter = ContractAdapter::new(ContractSpec::{}, drift)
  let failure = adapter.execute(contract_step("add", "add", 2)).unwrap()
  assert_true(failure.property == "contract-invariant-after:add" && contract_value(adapter.state) == 2)
  let initial = fake_contract()
  initial.value = 1
  let adapter = ContractAdapter::new(ContractSpec::{}, initial)
  assert_true(adapter.execute(contract_step("add", "add", 1)).unwrap().property == "contract-invariant-before:add" && initial.calls == 0)
  assert_true(adapter.teardown().unwrap().step_id == "teardown" && initial.closed)
}
