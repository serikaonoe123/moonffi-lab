// src/ffi.mbt —— 私有 FFI 声明层
//
// 官方 agent skill 的建议：extern 声明保持私有，只通过下一层的
// 安全公开 API 暴露给用户（见 src/eigen.mbt）。
//
// 每个函数的 C 侧实现见 src/eigen_shim.cpp，命名一一对应。
//
// ── 关于 `#borrow`（重要，编译器强制要求）────────────────────────────────
//
// moonc 会把"未标注调用约定的指针类型参数"报为错误（error 55 unannotated_ffi）：
//   FFI parameter of pointer type should be annotated with either #borrow or
//   #owned, the default calling convention is currently #owned and it will be
//   changed in the future.
//
// 本项目**全部使用 `#borrow`**，依据是胶水层的实际行为：shim 对句柄与数组
// 只做"调用期间读取/写入"，从不保存指针。这一点是可验证的 —— 见
// src/eigen_shim.cpp，没有任何一处把参数存进长生命周期的结构。
//
// 反过来说：如果哪天要让 C++ 侧长期持有 MoonBit 对象（例如注册回调、
// 把数组存进 C++ 容器），**必须**把对应参数改成 `#owned` 并处理引用计数，
// 否则 GC 回收后 C++ 会拿到悬垂引用。这类 bug 不会炸在出错点。
//
// 若改为 `#owned`，shim 侧还必须对每个参数调用 moonbit_decref ——
// 当前 shim 没有这样做，所以这里绝不能标成 `#owned`。

///|
/// C++ 侧 MatrixBox 的 MoonBit 句柄。
///
/// 抽象类型（type T）：官方 ABI 表规定它对应一个指针，且必须是
/// 合法的 MoonBit 对象 —— 这正是 moonbit_make_external_object 的返回值。
/// 注意：不能用 #external —— 那样内存管理系统会忽略它，finalizer 不会跑。
type EigenMatrix

///|
/// 构建期自检：验证 C++17 与 Eigen 版本真的被编进来了。
extern "C" fn mb_eigen_shim_probe() -> Int32 = "mb_eigen_shim_probe"

///|
extern "C" fn mb_eigen_matrix_new(rows : Int32, cols : Int32) -> EigenMatrix = "mb_eigen_matrix_new"

///|
/// data 是 FixedArray[Double]（C ABI: double*）。
#borrow(data)
extern "C" fn mb_eigen_matrix_from_array(
  rows : Int32,
  cols : Int32,
  data : FixedArray[Double],
  len : Int32,
) -> EigenMatrix = "mb_eigen_matrix_from_array"

///|
/// 返回 -1 表示"无效矩阵 / 上一次操作失败"。
#borrow(handle)
extern "C" fn mb_eigen_matrix_rows(handle : EigenMatrix) -> Int32 = "mb_eigen_matrix_rows"

///|
#borrow(handle)
extern "C" fn mb_eigen_matrix_cols(handle : EigenMatrix) -> Int32 = "mb_eigen_matrix_cols"

///|
#borrow(handle)
extern "C" fn mb_eigen_matrix_get(
  handle : EigenMatrix,
  i : Int32,
  j : Int32,
) -> Double = "mb_eigen_matrix_get"

///|
#borrow(handle)
extern "C" fn mb_eigen_matrix_set(
  handle : EigenMatrix,
  i : Int32,
  j : Int32,
  v : Double,
) -> Int32 = "mb_eigen_matrix_set"

///|
/// out 由调用方分配，长度必须等于 rows*cols。
#borrow(handle, out)
extern "C" fn mb_eigen_matrix_copy_to(
  handle : EigenMatrix,
  out : FixedArray[Double],
  len : Int32,
) -> Int32 = "mb_eigen_matrix_copy_to"

///|
/// op: 0=加 1=减 2=乘
#borrow(a, b)
extern "C" fn mb_eigen_matrix_binary(
  a : EigenMatrix,
  b : EigenMatrix,
  op : Int32,
) -> EigenMatrix = "mb_eigen_matrix_binary"

///|
#borrow(a)
extern "C" fn mb_eigen_matrix_scale(a : EigenMatrix, k : Double) -> EigenMatrix = "mb_eigen_matrix_scale"

///|
#borrow(a)
extern "C" fn mb_eigen_matrix_transpose(a : EigenMatrix) -> EigenMatrix = "mb_eigen_matrix_transpose"

///|
#borrow(a, b)
extern "C" fn mb_eigen_matrix_solve(
  a : EigenMatrix,
  b : EigenMatrix,
) -> EigenMatrix = "mb_eigen_matrix_solve"

///|
#borrow(a, b)
extern "C" fn mb_eigen_matrix_dot(a : EigenMatrix, b : EigenMatrix) -> Double = "mb_eigen_matrix_dot"

///|
#borrow(a)
extern "C" fn mb_eigen_matrix_norm(a : EigenMatrix) -> Double = "mb_eigen_matrix_norm"

///|
#borrow(a)
extern "C" fn mb_eigen_matrix_det(a : EigenMatrix) -> Double = "mb_eigen_matrix_det"

///|
/// 上一次操作的错误信息（UTF-8 字节）。成功时为空。
/// 用 Bytes 而不是 String：C 侧用 moonbit_make_bytes 构造，
/// 在 MoonBit 侧再解码，这是官方 agent skill 推荐的做法。
extern "C" fn mb_eigen_last_error() -> Bytes = "mb_eigen_last_error"
