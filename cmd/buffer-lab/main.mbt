///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"

///|
async fn main {
  let code = try {
    @runner.cli(
      @env.args(),
      trace => {
        let adapter = @buffer.BufferAdapter::new()
        adapter.configure(trace)
        adapter
      },
      (seed, mode, steps) => @buffer.generate(seed, mode~, noise=(steps - 8) / 4),
      generators={ "stateful": (seed, mode, steps) => @buffer.generate_stateful(seed, mode~, steps~) },
    )
  } catch {
    error => { println("MoonFFI Lab error: " + error.to_string()); 2 }
  }
  exit_process(code)
}
