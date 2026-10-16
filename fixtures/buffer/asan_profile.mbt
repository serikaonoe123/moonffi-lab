///| The ASan build script sets this pure build marker in its isolated source
/// copy. The positive canary must still demonstrate real instrumentation.
fn asan_profile_built() -> Bool {
  false
}
