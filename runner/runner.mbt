///|
pub(all) struct Event {
  kind : String
  step_id : String
  index : Int
} derive(ToJson, @json.FromJson)

///|
pub struct Controller {
  executable : String
  output : String
  timeout_ms : Int
  mut count : Int
}

///|
pub fn Controller::new(executable : String, output : String, timeout_ms~ : Int = 3000) -> Controller {
  { executable, output, timeout_ms, count: 0 }
}

///|
pub fn Controller::executions(self : Controller) -> Int { self.count }

///|
pub async fn read_trace(path : String) -> @lab.Trace {
  if @fs.file_size(path) > 1048576L { fail("trace exceeds 1 MiB") }
  @lab.decode_trace(@fs.read_file(path).text())
}

///|
pub fn[A : @lab.Adapter] validate(adapter : A, trace : @lab.Trace) -> String? {
  if trace.adapter != adapter.identity() || trace.adapter_version != adapter.version() {
    return Some("adapter identity/version mismatch")
  }
  if @lab.validate_dependencies(trace) is Some(message) { return Some(message) }
  adapter.validate(trace)
}

///|
async fn append_event(path : String, kind : String, step : String, index : Int) -> Unit {
  let event : Event = { kind, step_id: step, index }
  @fs.write_file(path, event.to_json().stringify() + "\n", append=true, create_mode=OpenExisting, sync=Data)
}

///| The complete trace executes in one worker. All target calls, including
/// teardown, happen here, after durable step_begin evidence has been written.
pub async fn[A : @lab.Adapter] worker(adapter : A, trace : @lab.Trace, output : String) -> Unit {
  if validate(adapter, trace) is Some(message) { fail("invalid worker trace: \{message}") }
  let events = output + "/events.jsonl"
  @fs.write_file(events, "", create_mode=CreateNew)
  let mut failure : @lab.Failure? = None
  let mut executed = 0
  for i, step in trace.steps {
    append_event(events, "step_begin", step.id, i)
    let found = adapter.execute(step)
    executed += 1
    append_event(events, "step_end", step.id, i)
    if found is Some(_) { failure = found; break }
  }
  append_event(events, "teardown_begin", "", executed)
  let final_failure = adapter.teardown()
  if failure is None { failure = final_failure }
  append_event(events, "teardown_end", "", executed)
  let completion : @lab.Completion = { protocol: 1, completed: true, executed, failure }
  @fs.write_file(output + "/result.json", completion.to_json().stringify(indent=2), create_mode=CreateNew, sync=Data)
}

///| Only complete JSONL records are accepted. A torn trailing record is ignored.
pub fn complete_events(text : String) -> Array[Event] raise {
  let lines = text.split("\n").to_array()
  let events : Array[Event] = []
  for i = 0; i + 1 < lines.length(); i = i + 1 {
    if lines[i] != "" { events.push(@json.from_json(@json.parse(lines[i]))) }
  }
  events
}

///| Check the protocol against the concrete input, not just a completion flag.
pub fn check_protocol(trace : @lab.Trace, events : Array[Event], result : @lab.Completion) -> String? {
  if result.protocol != 1 || !result.completed { return Some("unsupported/incomplete worker result") }
  if result.executed < 0 || result.executed > trace.steps.length() { return Some("invalid execution count") }
  if result.failure is None && result.executed != trace.steps.length() { return Some("worker skipped required steps") }
  if events.length() != result.executed * 2 + 2 { return Some("incomplete event sequence") }
  for i = 0; i < result.executed; i = i + 1 {
    let before = events[i * 2]
    let after = events[i * 2 + 1]
    if before.kind != "step_begin" || after.kind != "step_end" ||
      before.step_id != trace.steps[i].id || after.step_id != before.step_id ||
      before.index != i || after.index != i {
      return Some("event/trace mismatch")
    }
  }
  let before = events[result.executed * 2]
  let after = events[result.executed * 2 + 1]
  if before.kind != "teardown_begin" || after.kind != "teardown_end" ||
    before.index != result.executed || after.index != result.executed ||
    before.step_id != "" || after.step_id != "" {
    return Some("teardown was not confirmed")
  }
  if result.failure is Some(failure) {
    if failure.property == "" { return Some("empty failure property") }
    if failure.step_id != "teardown" &&
      (result.executed == 0 || trace.steps[result.executed - 1].id != failure.step_id) {
      return Some("failure does not identify last executed step")
    }
  }
  None
}

///|
fn make_report(outcome : @lab.Outcome, message : String, code : Int?, last : String?, executed : Int, elapsed : Int64, fingerprint : String?) -> @lab.Report {
  { outcome, message, raw_exit_code: code, last_step: last, executed, elapsed_ms: elapsed, fingerprint }
}

///|
pub async fn[A : @lab.Adapter] Controller::run(self : Controller, adapter : A, trace : @lab.Trace, timeout_ms? : Int) -> @lab.Report {
  let timeout_ms = timeout_ms.unwrap_or(self.timeout_ms)
  if timeout_ms <= 0 { fail("positive execution timeout required") }
  self.count += 1
  let directory = self.output + "/case-" + self.count.to_string()
  // Refuse existing directories: stale evidence must never turn a run green.
  @fs.mkdir(directory, recursive=true, allow_exist=false)
  let directory = @fs.realpath(directory)
  @fs.write_file(directory + "/case.json", trace.encode(), create_mode=CreateNew)
  let started = @async.now()
  let report = if validate(adapter, trace) is Some(message) {
    make_report(InvalidCase, message, None, None, 0, 0L, None)
  } else {
    self.launch(trace, directory, started, timeout_ms)
  }
  @fs.write_file(directory + "/report.json", report.to_json().stringify(indent=2))
  @fs.write_file(directory + "/report.md", render_report(report))
  report
}

///|
async fn Controller::launch(self : Controller, trace : @lab.Trace, directory : String, started : Int64, timeout_ms : Int) -> @lab.Report {
  let stdout = @process.redirect_to_file(directory + "/stdout.log", create_mode=CreateNew)
  defer stdout.close()
  let stderr = @process.redirect_to_file(directory + "/stderr.log", create_mode=CreateNew)
  defer stderr.close()
  let status = try {
    @async.with_timeout_opt(timeout_ms, () => @process.run(
      self.executable,
      ["--worker", directory + "/case.json", directory],
      stdout~, stderr~, no_console_window=true,
      cancel_handler=@process.hard_cancel(),
    ))
  } catch {
    error => return make_report(SetupError, error.to_string(), None, None, 0, @async.now() - started, None)
  }
  let elapsed = @async.now() - started
  let event_text = if @fs.exists(directory + "/events.jsonl") {
    @fs.read_file(directory + "/events.jsonl").text()
  } else { "" }
  let events = try { complete_events(event_text) } catch {
    _ => return make_report(HarnessError, "malformed event log", status, None, 0, elapsed, None)
  }
  let mut last : String? = None
  let mut executed = 0
  for event in events {
    if event.kind == "step_begin" { last = Some(event.step_id) }
    if event.kind == "step_end" { executed += 1 }
  }
  guard status is Some(code) else {
    return make_report(Timeout, "worker terminated after timeout", None, last, executed, elapsed, None)
  }
  if code != 0 {
    let outcome : @lab.Outcome = if code == 2 { HarnessError } else { Crash }
    return make_report(outcome, "worker exited abnormally; raw exit is not a root-cause fingerprint", Some(code), last, executed, elapsed, None)
  }
  guard @fs.exists(directory + "/result.json") else {
    return make_report(HarnessError, "exit 0 without completion evidence", Some(code), last, executed, elapsed, None)
  }
  let result : @lab.Completion = try {
    @json.from_json(@json.parse(@fs.read_file(directory + "/result.json").text()))
  } catch {
    _ => return make_report(HarnessError, "malformed worker result", Some(code), last, executed, elapsed, None)
  }
  if check_protocol(trace, events, result) is Some(message) {
    return make_report(HarnessError, message, Some(code), last, executed, elapsed, None)
  }
  match result.failure {
    Some(failure) => make_report(PropertyFailure, failure.message, Some(code), last, executed, elapsed, Some("property:\{failure.property}:\{failure.step_id}"))
    None => make_report(Pass, "all required steps and teardown passed", Some(code), last, executed, elapsed, None)
  }
}

///|
pub fn render_report(report : @lab.Report) -> String {
  let outcome = report.outcome.to_json().stringify()
  let code = Json(report.raw_exit_code).stringify()
  let step = Json(report.last_step).stringify()
  "# MoonFFI Lab result\n\n- Outcome: \{outcome}\n- Raw worker exit: \{code}\n- Last observed step: \{step}\n- Completed operations: \{report.executed}\n- Elapsed: \{report.elapsed_ms} ms\n\n\{report.message}\n\nThe last observed operation is evidence, not proof of the root cause.\n"
}
