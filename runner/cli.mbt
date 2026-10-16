///|
fn option(options : Map[String, String], name : String, default : String) -> String {
  options.get(name).unwrap_or(default)
}

///|
fn bounded_int(options : Map[String, String], name : String, default : String, min : Int, max : Int) -> Int raise {
  let value = @string.parse_int(option(options, name, default))
  if value < min || value > max { fail("\{name} must be between \{min} and \{max}") }
  value
}

///| Shared command implementation. Factories must remain pure until execute().
pub async fn[A : @lab.Adapter] cli(
  arguments : Array[String],
  make_adapter : (@lab.Trace) -> A,
  generate : (UInt64, String, Int) -> @lab.Trace,
) -> Int {
  if arguments.length() < 2 || arguments[1] == "--help" {
    println("MoonFFI Lab\n  run [--seed N] [--cases N] [--steps N] [--mode MODE] [--out DIR]\n  generate [same options except --cases]\n  replay CASE.json [--mode MODE] [--out DIR]\n  shrink CASE.json [--budget N] [--wall-ms N] [--out DIR]\n  all execution commands accept --timeout-ms N\nAn output directory must be new; it contains complete evidence.")
    return 0
  }
  if arguments[1] == "--worker" {
    if arguments.length() != 4 { fail("invalid worker invocation") }
    let trace = read_trace(arguments[2])
    worker(make_adapter(trace), trace, arguments[3])
    return 0
  }
  let command = arguments[1]
  if command != "run" && command != "generate" && command != "replay" && command != "shrink" { fail("unknown command: \{command}") }
  let has_input = command == "replay" || command == "shrink"
  if has_input && arguments.length() < 3 { fail("missing case.json") }
  let options : Map[String, String] = Map([])
  let mut index = if has_input { 3 } else { 2 }
  while index < arguments.length() {
    let key = arguments[index]
    if !["--out", "--seed", "--cases", "--steps", "--mode", "--timeout-ms", "--budget", "--wall-ms"].contains(key) || index + 1 >= arguments.length() {
      fail("unknown option or missing value: \{key}")
    }
    if options.contains(key) { fail("repeated option: \{key}") }
    options[key] = arguments[index + 1]
    index += 2
  }
  let output = option(options, "--out", "results/run-" + @env.now().to_string())
  if @fs.exists(output) { fail("output already exists; choose a new directory: \{output}") }
  let timeout_ms = bounded_int(options, "--timeout-ms", "3000", 10, 60000)
  let controller = Controller::new(arguments[0], output, timeout_ms~)
  if has_input {
    let original = read_trace(arguments[2])
    let trace = if options.get("--mode") is Some(mode) {
      let environment = original.environment.copy()
      environment["fixture_mode"] = mode
      { ..original, environment }
    } else { original }
    let adapter = make_adapter(trace)
    if command == "shrink" {
      let budget = bounded_int(options, "--budget", "200", 6, 10000)
      let wall_ms = bounded_int(options, "--wall-ms", "60000", 100, 600000)
      let reduction = controller.shrink(adapter, trace, budget~, wall_ms~)
      println(reduction.to_json().stringify(indent=2))
      return if reduction.confirmed { 1 } else { 3 }
    }
    let report = controller.run(adapter, trace)
    println(report.to_json().stringify(indent=2))
    return report.exit_code()
  }
  let seed = @string.parse_uint64(option(options, "--seed", "20261016"))
  let cases = bounded_int(options, "--cases", "1", 1, 1000)
  let steps = bounded_int(options, "--steps", "32", 8, 256)
  let mode = option(options, "--mode", "correct")
  if command == "generate" {
    let trace = generate(seed, mode, steps)
    if validate(make_adapter(trace), trace) is Some(message) { fail(message) }
    @fs.mkdir(output, recursive=true, allow_exist=false)
    @fs.write_file(output + "/case.json", trace.encode())
    println(output + "/case.json")
    return 0
  }
  let reports : Array[@lab.Report] = []
  let mut exit_code = 0
  for i = 0; i < cases; i = i + 1 {
    let trace = generate(seed + i.to_uint64(), mode, steps)
    let report = controller.run(make_adapter(trace), trace)
    reports.push(report)
    println("case \{i + 1}: " + report.outcome.to_json().stringify())
    let code = report.exit_code()
    if code > exit_code { exit_code = code }
  }
  @fs.write_file(output + "/summary.json", Json(reports).stringify(indent=2))
  println("evidence: \{output}")
  exit_code
}
