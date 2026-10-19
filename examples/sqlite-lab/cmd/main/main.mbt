///|
extern "C" fn exit_process(code : Int32) -> Unit = "exit"

///|
async fn main {
  let code = @runner.cli(
    @env.args(),
    trace => @adapter.SqliteAdapter::new(trace),
    @adapter.generate,
    generators={ "walk": @adapter.generate_walk },
  ) catch {
    error => {
      println("SQLite integration: " + error.to_string())
      2
    }
  }
  exit_process(code)
}
