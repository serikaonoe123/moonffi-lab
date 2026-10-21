///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"
///|
async fn main {
  let code = try {
    @runner.cli(@env.args(), trace => @lab.ContractAdapter::new(@counter.CounterContract::new(), @counter.ContractCounterTarget::new(trace)),
      @counter.generate_contract, generators={ "walk": @counter.generate_contract_walk })
  } catch {
    error => { println("Contract counter: " + error.to_string()); 2 }
  }
  exit_process(code)
}
