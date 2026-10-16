///| New integration smoke check; the binding source remains unmodified.
test "fixed Eigen snapshot links and reports an Eigen version" {
  assert_true(mb_eigen_shim_probe() > 0)
}
