///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"
///|
async fn main {
  let code = try {
    @runner.cli(@env.args(), trace => @counter.CounterAdapter::new(trace), @counter.generate,
      generators={ "walk": @counter.generate_walk },
    )
  } catch {
    error => { println("Counter example: " + error.to_string()); 2 }
  }
  exit_process(code)
}
