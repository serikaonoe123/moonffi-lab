///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"
///|
async fn main {
  let code = try {
    @runner.cli(@env.args(), trace => @lab.ContractAdapter::new(@counter.ParameterContract::new(), @counter.ParameterTarget::new(trace)),
      @counter.generate_parameters, generators={ "walk": @counter.generate_parameters_walk })
  } catch {
    error => { println("FFI parameters: " + error.to_string()); 2 }
  }
  exit_process(code)
}
