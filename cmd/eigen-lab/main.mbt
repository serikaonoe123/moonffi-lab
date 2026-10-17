///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"

///|
async fn main {
  let code = try {
    @runner.cli(@env.args(), _ => @eigen.EigenAdapter::new(),
      (seed, mode, steps) => @eigen.generate(seed, mode~, steps~),
      generators={ "stateful": (seed, mode, steps) => @eigen.generate_stateful(seed, mode~, steps~),
        "arithmetic": (seed, mode, steps) => @eigen.generate_arithmetic(seed, mode~, steps~) },
    )
  } catch {
    error => { println("MoonFFI Lab error: " + error.to_string()); 2 }
  }
  exit_process(code)
}
