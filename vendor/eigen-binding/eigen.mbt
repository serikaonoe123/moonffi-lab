// src/eigen.mbt —— MoonBit 公开 API 层（本项目的主要实现语言所在）
//
// 上层用户只与这一层打交道：没有句柄、没有 FixedArray、没有错误码。
//
// 设计取向：
//   · 错误用 Result[T, String] 表达，不抛异常 —— 语法稳定、强制处理。
//   · 维度检查、错误信息取用、格式化输出都在 MoonBit 里做，
//     C++ 侧只保留"把模板实例化掉"这一件无法在 MoonBit 完成的事。
//
// ⚠️ 未编译验证：MoonBit 工具链安装中，本文件尚未通过 moon check。
//    需要用本机编译器校对的 API（详见 docs/PITFALLS.md 第 8 节）：
//    FixedArray::from_array、Array::from_fixed_array、FixedArray::make、
//    @utf8.decode_lossy、字符串插值语法。
//    （曾用到的 Double::round / to_int / to_double 与 StringBuilder
//      已在 to_string 重构中移除，见 docs/DECISIONS.md D8。）

///|
/// 动态尺寸的双精度矩阵。
pub struct Matrix {
  handle : EigenMatrix
}

// ---------------------------------------------------------------------------
// 内部工具
// ---------------------------------------------------------------------------

///|
/// 取出 C 侧记录的上一次错误信息。
///
/// 注意 `[:]`：官方 `encoding/utf8` 的接口是
/// `pub fn decode_lossy(BytesView, ignore_bom? : Bool) -> String`
/// —— 收的是 **BytesView** 而不是 Bytes，所以要显式取视图。
/// （依据：moonbitlang/core 的 encoding/utf8/pkg.generated.mbti 原文）
fn last_error() -> String {
  @utf8.decode_lossy(mb_eigen_last_error()[:])
}

///|
/// 统一的有效性检查：rows() < 0 表示 C 侧返回了错误哨兵。
fn ensure_valid(handle : EigenMatrix) -> Result[Unit, String] {
  if mb_eigen_matrix_rows(handle) < 0 {
    Err(last_error())
  } else {
    Ok(())
  }
}

///|
/// 把 C 侧返回的句柄包成 Matrix，失败则转成 Err。
fn wrap(handle : EigenMatrix) -> Result[Matrix, String] {
  match ensure_valid(handle) {
    Ok(_) => Ok({ handle, })
    Err(msg) => Err(msg)
  }
}

///|
/// 调用二元运算的公共路径：op 0=加 1=减 2=乘。
fn Matrix::binary(
  self : Matrix,
  other : Matrix,
  op : Int32,
) -> Result[Matrix, String] {
  wrap(mb_eigen_matrix_binary(self.handle, other.handle, op))
}

// ---------------------------------------------------------------------------
// 构造
// ---------------------------------------------------------------------------

///|
/// 全零矩阵。
pub fn Matrix::zeros(rows : Int32, cols : Int32) -> Result[Matrix, String] {
  wrap(mb_eigen_matrix_new(rows, cols))
}

///|
/// 从行主序的一维数组构造矩阵，要求 data.length() == rows * cols。
pub fn Matrix::from_array(
  rows : Int32,
  cols : Int32,
  data : Array[Double],
) -> Result[Matrix, String] {
  if rows < 0 || cols < 0 {
    return Err("矩阵尺寸不能为负")
  }
  if data.length() != rows * cols {
    return Err(
      "数据长度 \{data.length()} 与 rows*cols = \{rows * cols} 不匹配",
    )
  }
  // 手工搬运，而不是用 FixedArray::from_array：
  // 后者的名称与签名未经确认，而下面的写法只用 FixedArray::make + 下标赋值
  // （前者出自官方 C-FFI 黑板报文章，后者是语言基础）。同类取舍见 DECISIONS D8。
  let fixed = FixedArray::make(data.length(), 0.0)
  for i = 0; i < data.length(); i = i + 1 {
    fixed[i] = data[i]
  }
  wrap(mb_eigen_matrix_from_array(rows, cols, fixed, fixed.length()))
}

// ---------------------------------------------------------------------------
// 元信息与元素访问
// ---------------------------------------------------------------------------

///|
pub fn Matrix::rows(self : Matrix) -> Int32 {
  mb_eigen_matrix_rows(self.handle)
}

///|
pub fn Matrix::cols(self : Matrix) -> Int32 {
  mb_eigen_matrix_cols(self.handle)
}

///|
pub fn Matrix::get(
  self : Matrix,
  i : Int32,
  j : Int32,
) -> Result[Double, String] {
  if i < 0 || j < 0 || i >= self.rows() || j >= self.cols() {
    return Err(
      "下标 (\{i}, \{j}) 越界：矩阵尺寸为 \{self.rows()}x\{self.cols()}",
    )
  }
  Ok(mb_eigen_matrix_get(self.handle, i, j))
}

///|
pub fn Matrix::set(
  self : Matrix,
  i : Int32,
  j : Int32,
  value : Double,
) -> Result[Unit, String] {
  if i < 0 || j < 0 || i >= self.rows() || j >= self.cols() {
    return Err(
      "下标 (\{i}, \{j}) 越界：矩阵尺寸为 \{self.rows()}x\{self.cols()}",
    )
  }
  if mb_eigen_matrix_set(self.handle, i, j, value) != 0 {
    return Err(last_error())
  }
  Ok(())
}

///|
/// 导出为行主序的一维数组。
pub fn Matrix::to_array(self : Matrix) -> Result[Array[Double], String] {
  let n = self.rows() * self.cols()
  let out = FixedArray::make(n, 0.0)
  if mb_eigen_matrix_copy_to(self.handle, out, n) != 0 {
    return Err(last_error())
  }
  // 手工搬运，避免依赖 Array::from_fixed_array。
  // 注意不加 mut：Array::push 接收 self，通过方法改内容不需要绑定可变
  // （moonc 会报 error 15 unused_mut）。
  let result : Array[Double] = []
  for i = 0; i < n; i = i + 1 {
    result.push(out[i])
  }
  Ok(result)
}

// ---------------------------------------------------------------------------
// 运算
// ---------------------------------------------------------------------------

///|
pub fn Matrix::add(self : Matrix, other : Matrix) -> Result[Matrix, String] {
  self.binary(other, 0)
}

///|
pub fn Matrix::sub(self : Matrix, other : Matrix) -> Result[Matrix, String] {
  self.binary(other, 1)
}

///|
pub fn Matrix::mul(self : Matrix, other : Matrix) -> Result[Matrix, String] {
  self.binary(other, 2)
}

///|
pub fn Matrix::scale(self : Matrix, k : Double) -> Result[Matrix, String] {
  wrap(mb_eigen_matrix_scale(self.handle, k))
}

///|
pub fn Matrix::transpose(self : Matrix) -> Result[Matrix, String] {
  wrap(mb_eigen_matrix_transpose(self.handle))
}

///|
/// 解线性方程组 Ax = b。
pub fn Matrix::solve(self : Matrix, b : Matrix) -> Result[Matrix, String] {
  wrap(mb_eigen_matrix_solve(self.handle, b.handle))
}

///|
/// 内积（逐元素乘积之和）。
///
/// 契约（与 src/eigen_shim.cpp 的 mat_dot 保持一致）：
///   · 形状完全相同（行、列都相同）→ 逐元素内积
///   · 两者都是向量（行向量或列向量）且元素个数相同 → 向量点积
///     （因此 1×3 与 3×1 可以相乘，这是最自然的用法）
///   · 其它情况 → 返回 Err
///
/// 注意：早期版本只检查"元素个数相同"，结果 1×3 与 3×1 会穿透到
/// Eigen 的 cwiseProduct，触发形状断言而崩溃。现在两侧都按上面的规则检查。
pub fn Matrix::dot(self : Matrix, other : Matrix) -> Result[Double, String] {
  let same_shape = self.rows() == other.rows() && self.cols() == other.cols()
  let self_is_vector = self.rows() == 1 || self.cols() == 1
  let other_is_vector = other.rows() == 1 || other.cols() == 1
  if self.rows() * self.cols() != other.rows() * other.cols() {
    return Err("内积要求两个矩阵元素个数相同")
  }
  if !same_shape && !(self_is_vector && other_is_vector) {
    return Err("内积要求形状相同，或两者都是元素个数相同的向量")
  }
  Ok(mb_eigen_matrix_dot(self.handle, other.handle))
}

///|
/// Frobenius 范数。
pub fn Matrix::norm(self : Matrix) -> Double {
  mb_eigen_matrix_norm(self.handle)
}

///|
/// 行列式，要求方阵。
pub fn Matrix::det(self : Matrix) -> Result[Double, String] {
  if self.rows() != self.cols() {
    return Err(
      "行列式要求方阵，当前为 \{self.rows()}x\{self.cols()}",
    )
  }
  Ok(mb_eigen_matrix_det(self.handle))
}

// ---------------------------------------------------------------------------
// 纯 MoonBit 的价值点：格式化输出
//
// 这一部分完全不碰 FFI —— 它说明本项目不只是"把 C++ 抄一遍"，
// MoonBit 侧确实在提供自己的东西。
// ---------------------------------------------------------------------------

///|
/// 把矩阵渲染成可读的多行字符串。
///
/// 刻意只用最基础的字符串拼接与 Show 插值：**不依赖** StringBuilder、
/// Double::round / to_int / to_double 这类尚未在本机确认的标准库 API。
/// 在工具链就绪前，把"未验证 API"的面积压到最小是一种工程纪律 ——
/// 少一个猜错的符号，就少一次编译失败后的返工。
/// 列对齐的漂亮输出留到 v2（见 docs/ROADMAP.md 第 6 节）。
pub fn Matrix::to_string(self : Matrix) -> String {
  if self.rows() < 0 {
    return "<无效矩阵: \{last_error()}>"
  }
  let mut s = "Matrix(\{self.rows()}x\{self.cols()})"
  for i = 0; i < self.rows(); i = i + 1 {
    s = s + "\n  ["
    for j = 0; j < self.cols(); j = j + 1 {
      if j > 0 {
        s = s + ", "
      }
      s = s + "\{trim_float_noise(mb_eigen_matrix_get(self.handle, i, j))}"
    }
    s = s + "]"
  }
  s
}

///|
/// 抹掉浮点显示的噪声。
///
/// 直接用 Show 插值一个 Double 会打印出 `0.7999999999999999` 这种结果
/// （0.8 在二进制浮点里不可精确表示）。这里先按 1e6 取整再缩回，
/// 让常见的数值显示成人眼期待的样子：0.8、1.4、50、0.333333。
///
/// 说明：这不是定点格式化（不做列对齐），只是把噪声抹掉。
/// 用它而不是手写定点格式化的理由见 docs/DECISIONS.md D8 ——
/// 当初因为 API 未经确认而回避了格式化，现在 `Double::round` 已在本机
/// builtin 的接口清单中确认存在，于是用最简单可靠的方式补回来。
fn trim_float_noise(v : Double) -> Double {
  (v * 1000000.0).round() / 1000000.0
}
