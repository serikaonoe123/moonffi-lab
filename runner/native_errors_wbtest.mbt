///|
test "crash evidence rejects weak, mixed and duplicate markers" {
  let marker = "MOONFFI_CRASH_V1\twindows\t-1073741819\t1\t0x14f0\n"
  assert_true(crash_fingerprint(marker, -1073741819) is Some(_))
  assert_true(crash_fingerprint(marker, 1) is None)
  assert_true(crash_fingerprint(marker + marker, -1073741819) is None)
  assert_true(crash_fingerprint("exit 11, last step read", -11) is None)
  assert_true(crash_fingerprint("MOONFFI_CRASH_V1\tsignal\t11\t1\t0x45a0\n", -11) is Some(_))
  assert_true(crash_fingerprint("MOONFFI_CRASH_V1\tsignal\t11\t0\t0x45a0\n", -11) is None)
  assert_true(crash_fingerprint("MOONFFI_CRASH_V1\twindows\t-1073741819\t1\t0xZZ\n", -1073741819) is None)
  let other = "MOONFFI_CRASH_V1\twindows\t-1073741819\t1\t0x1510\n"
  assert_true(crash_fingerprint(marker, -1073741819) != crash_fingerprint(other, -1073741819))
}

///|
test "ASan frames ignore ASLR but preserve site and category" {
  let report = "ERROR: AddressSanitizer: heap-buffer-overflow on address 0x123\n    #0 0x123 in fault_a test.c:12\n    #1 0x234 (worker.exe+0x420)\nSUMMARY: AddressSanitizer: heap-buffer-overflow test.c:12\n"
  let moved = "ERROR: AddressSanitizer: heap-buffer-overflow on address 0x999\n    #0 0xabc in fault_a test.c:12\n    #1 0xdef (worker.exe+0x420)\nSUMMARY: AddressSanitizer: heap-buffer-overflow test.c:12\n"
  assert_true(asan_fingerprint(report) is Some(_))
  assert_true(asan_fingerprint(report) == asan_fingerprint(moved))
  assert_true(asan_fingerprint(report + report) is None)
  assert_true(asan_fingerprint("ERROR: AddressSanitizer: heap-buffer-overflow\nSUMMARY: AddressSanitizer: heap-buffer-overflow\n") is None)
  let other = "ERROR: AddressSanitizer: heap-buffer-overflow\n    #0 0x123 in fault_b test.c:16\n    #1 0x234 (worker.exe+0x420)\nSUMMARY: AddressSanitizer: heap-buffer-overflow test.c:16\n"
  assert_true(asan_fingerprint(report) != asan_fingerprint(other))
}

///|
test "native matching requires both a supported outcome and a signature" {
  let baseline = make_report(Crash, "example", Some(-11), None, 0, 0L, Some("site:a"))
  assert_true(same_failure(baseline, baseline))
  assert_true(!same_failure(baseline, { ..baseline, outcome: MemoryError }))
  assert_true(!same_failure(baseline, { ..baseline, fingerprint: Some("site:b") }))
  assert_true(!reducible({ ..baseline, outcome: Timeout }))
  assert_true(!reducible({ ..baseline, fingerprint: None }))
}
