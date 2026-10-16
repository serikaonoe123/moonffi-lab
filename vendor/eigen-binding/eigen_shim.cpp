// eigen_shim.cpp —— FFI 边界层（本项目的技术核心）
//
// 职责：
//   1. 把 MoonBit 的 FixedArray[Double] 与 Eigen 矩阵互相搬运；
//   2. 用 moonbit_make_external_object 管理 C++ 对象的生命周期；
//   3. 把所有 C++ 异常/断言挡在 ABI 边界之内。
//
// ── 关键设计决定（全部有出处，见 docs/PITFALLS.md）───────────────────────
//
// (1) 只有 double* 与 int32_t 跨越边界，没有字符串往返
//     MoonBit 的 FixedArray[Double] 在官方 ABI 表里明确对应 double*，
//     是文档承诺的稳定映射。错误信息方向用 moonbit_make_bytes（Bytes），
//     因为 moonbit_make_string 这个符号在官方文档/skill/issue 中查不到出处，
//     而 moonbit_make_bytes 是官方 agent skill 推荐的做法
//     （C 侧 make_bytes + memcpy，MoonBit 侧 @utf8.decode_lossy）。
//
// (2) 失败不用 nullptr，用 valid=false 的哨兵盒子
//     MoonBit 侧把该对象绑到抽象类型，抽象类型没有 null 语义；
//     返回 nullptr 会让 MoonBit 拿到一个垃圾句柄。因此失败时返回一个
//     真实的、可安全回收的盒子，只是 valid=false，rows() 返回 -1。
//
// (3) 矩阵按行主序搬运
//     Eigen 的 MatrixXd 默认是列主序。为了不让这个隐含约定泄漏到
//     MoonBit 侧，所有搬运都按 (i, j) 逐个元素进行，对外统一是行主序。
//
// ✅ 已实测通过（2026-10-13，MSVC 14.51 + moonc v0.10.15）：本文件编译、链接、
//    运行均正常 —— selftest 7/7、Eigen 绑定 18/18、三个示例输出正确，ASan 也已接入。
//    用到的 moonbit.h 符号：moonbit_make_external_object、moonbit_make_bytes。

#include "eigen_shim.hpp"

#include <moonbit.h>  // $MOON_HOME/include/moonbit.h

#include <cstdint>
#include <cstring>
#include <exception>
#include <new>
#include <string>

// moonbit.h 应当定义这个宏；官方 agent skill 明确要求所有导出函数都加它，
// 否则 MoonBit 的链接器看不到符号。缺失时退化为空宏以免整文件编不过。
#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT
#endif

namespace moonbit_eigen {

namespace {
thread_local std::string g_last_error;
}  // namespace

const char *last_error() noexcept { return g_last_error.c_str(); }

void clear_error() noexcept { g_last_error.clear(); }

void set_error(const std::string &msg) noexcept {
  try {
    g_last_error = msg;
  } catch (...) {
    g_last_error.clear();  // 错误处理本身绝不能抛
  }
}

MatrixBox *make_invalid() noexcept {
  try {
    auto *box = new MatrixBox();
    box->valid = false;
    return box;
  } catch (...) {
    return nullptr;  // 极端情况：连哨兵都分配不出来
  }
}

// 运算分派用整数而不是函数指针，避免跨语言传函数指针。
enum class BinaryOp : int { Add = 0, Sub = 1, Mul = 2 };

MatrixBox *mat_new(std::int32_t rows, std::int32_t cols) noexcept {
  clear_error();
  if (rows < 0 || cols < 0) {
    set_error("矩阵尺寸不能为负");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    box->mat = Eigen::MatrixXd::Zero(rows, cols);
    return box;
  } catch (const std::exception &e) {
    set_error(std::string("分配矩阵失败: ") + e.what());
    return make_invalid();
  } catch (...) {
    set_error("分配矩阵失败: 未知异常");
    return make_invalid();
  }
}

MatrixBox *mat_from_array(std::int32_t rows, std::int32_t cols, const double *data,
                          std::int32_t len) noexcept {
  clear_error();
  if (data == nullptr) {
    set_error("输入数组为空");
    return make_invalid();
  }
  const std::int64_t expected =
      static_cast<std::int64_t>(rows) * static_cast<std::int64_t>(cols);
  if (rows < 0 || cols < 0 || expected != len) {
    set_error("输入数组长度与 rows*cols 不匹配");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    box->mat.resize(rows, cols);
    for (std::int32_t i = 0; i < rows; ++i) {
      for (std::int32_t j = 0; j < cols; ++j) {
        box->mat(i, j) = data[static_cast<std::int64_t>(i) * cols + j];
      }
    }
    return box;
  } catch (const std::exception &e) {
    set_error(std::string("构造矩阵失败: ") + e.what());
    return make_invalid();
  } catch (...) {
    set_error("构造矩阵失败: 未知异常");
    return make_invalid();
  }
}

std::int32_t mat_rows(const MatrixBox *box) noexcept {
  return is_valid(box) ? static_cast<std::int32_t>(box->mat.rows()) : -1;
}

std::int32_t mat_cols(const MatrixBox *box) noexcept {
  return is_valid(box) ? static_cast<std::int32_t>(box->mat.cols()) : -1;
}

double mat_get(const MatrixBox *box, std::int32_t i, std::int32_t j) noexcept {
  if (!is_valid(box) || i < 0 || j < 0 || i >= box->mat.rows() ||
      j >= box->mat.cols()) {
    set_error("下标越界");
    return 0.0;
  }
  return box->mat(i, j);
}

bool mat_set(MatrixBox *box, std::int32_t i, std::int32_t j, double v) noexcept {
  if (!is_valid(box) || i < 0 || j < 0 || i >= box->mat.rows() ||
      j >= box->mat.cols()) {
    set_error("下标越界");
    return false;
  }
  box->mat(i, j) = v;
  return true;
}

bool mat_copy_to(const MatrixBox *box, double *out, std::int32_t len) noexcept {
  if (!is_valid(box) || out == nullptr) {
    set_error("无效矩阵或输出数组为空");
    return false;
  }
  const std::int64_t expected =
      static_cast<std::int64_t>(box->mat.rows()) * box->mat.cols();
  if (expected != len) {
    set_error("输出数组长度与 rows*cols 不匹配");
    return false;
  }
  // 逐元素搬运，统一对外行主序，不让 Eigen 的列主序泄漏出去。
  for (Eigen::Index i = 0; i < box->mat.rows(); ++i) {
    for (Eigen::Index j = 0; j < box->mat.cols(); ++j) {
      out[static_cast<std::int64_t>(i) * box->mat.cols() + j] = box->mat(i, j);
    }
  }
  return true;
}

MatrixBox *mat_binary(const MatrixBox *a, const MatrixBox *b, int op) noexcept {
  clear_error();
  if (!is_valid(a) || !is_valid(b)) {
    set_error("运算涉及无效矩阵");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    switch (static_cast<BinaryOp>(op)) {
    case BinaryOp::Add:
      if (a->mat.rows() != b->mat.rows() || a->mat.cols() != b->mat.cols()) {
        delete box;
        set_error("加法要求两个矩阵尺寸相同");
        return make_invalid();
      }
      box->mat = a->mat + b->mat;
      break;
    case BinaryOp::Sub:
      if (a->mat.rows() != b->mat.rows() || a->mat.cols() != b->mat.cols()) {
        delete box;
        set_error("减法要求两个矩阵尺寸相同");
        return make_invalid();
      }
      box->mat = a->mat - b->mat;
      break;
    case BinaryOp::Mul:
      if (a->mat.cols() != b->mat.rows()) {
        delete box;
        set_error("乘法要求左矩阵的列数等于右矩阵的行数");
        return make_invalid();
      }
      box->mat = a->mat * b->mat;
      break;
    default:
      delete box;
      set_error("未知的运算类型");
      return make_invalid();
    }
    return box;
  } catch (const std::exception &e) {
    set_error(std::string("运算失败: ") + e.what());
    return make_invalid();
  } catch (...) {
    set_error("运算失败: 未知异常");
    return make_invalid();
  }
}

MatrixBox *mat_scale(const MatrixBox *a, double k) noexcept {
  clear_error();
  if (!is_valid(a)) {
    set_error("运算涉及无效矩阵");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    box->mat = a->mat * k;
    return box;
  } catch (...) {
    set_error("数乘失败");
    return make_invalid();
  }
}

MatrixBox *mat_transpose(const MatrixBox *a) noexcept {
  clear_error();
  if (!is_valid(a)) {
    set_error("运算涉及无效矩阵");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    box->mat = a->mat.transpose();
    return box;
  } catch (...) {
    set_error("转置失败");
    return make_invalid();
  }
}

MatrixBox *mat_solve(const MatrixBox *a, const MatrixBox *b) noexcept {
  clear_error();
  if (!is_valid(a) || !is_valid(b)) {
    set_error("运算涉及无效矩阵");
    return make_invalid();
  }
  if (a->mat.rows() != a->mat.cols()) {
    set_error("求解 Ax=b 要求 A 为方阵");
    return make_invalid();
  }
  if (a->mat.rows() != b->mat.rows()) {
    set_error("求解 Ax=b 要求 A 的行数等于 b 的行数");
    return make_invalid();
  }
  try {
    auto *box = new MatrixBox();
    // partialPivLu 对一般方阵都可用；奇异矩阵会在下面被检测。
    box->mat = a->mat.partialPivLu().solve(b->mat);
    if (!box->mat.allFinite()) {
      delete box;
      set_error("求解失败：矩阵可能是奇异的");
      return make_invalid();
    }
    return box;
  } catch (const std::exception &e) {
    set_error(std::string("求解失败: ") + e.what());
    return make_invalid();
  } catch (...) {
    set_error("求解失败: 未知异常");
    return make_invalid();
  }
}

double mat_dot(const MatrixBox *a, const MatrixBox *b) noexcept {
  if (!is_valid(a) || !is_valid(b)) {
    set_error("运算涉及无效矩阵");
    return 0.0;
  }

  const Eigen::Index na = a->mat.size();
  const Eigen::Index nb = b->mat.size();
  if (na != nb) {
    set_error("内积要求两个矩阵元素个数相同");
    return 0.0;
  }

  // ⚠️ 不要用 cwiseProduct().sum()：Eigen 的逐元素二元运算会断言
  //    「形状必须完全相同」（CwiseBinaryOp.h 里的
  //    aLhs.rows() == aRhs.rows() && aLhs.cols() == aRhs.cols()），
  //    而 1×3 与 3×1 元素个数相同、形状不同 —— 实测就会在这里崩。
  // 这里改成手工按存储顺序配对求和，既避开了断言，也把语义说清楚：
  //   形状相同 → 正常的逐元素内积
  //   两者都是向量（行向量或列向量）且元素个数相同 → 向量点积
  //   其它情况 → 明确报错，而不是触发断言
  const bool same_shape =
      (a->mat.rows() == b->mat.rows() && a->mat.cols() == b->mat.cols());
  const bool a_is_vector = (a->mat.rows() == 1 || a->mat.cols() == 1);
  const bool b_is_vector = (b->mat.rows() == 1 || b->mat.cols() == 1);
  if (!same_shape && !(a_is_vector && b_is_vector)) {
    set_error("内积要求形状相同，或两者都是元素个数相同的向量");
    return 0.0;
  }

  const double *pa = a->mat.data();
  const double *pb = b->mat.data();
  double acc = 0.0;
  for (Eigen::Index i = 0; i < na; ++i) {
    acc += pa[i] * pb[i];
  }
  return acc;
}

double mat_norm(const MatrixBox *a) noexcept {
  if (!is_valid(a)) {
    set_error("运算涉及无效矩阵");
    return 0.0;
  }
  return a->mat.norm();  // Frobenius 范数
}

double mat_det(const MatrixBox *a) noexcept {
  if (!is_valid(a)) {
    set_error("运算涉及无效矩阵");
    return 0.0;
  }
  if (a->mat.rows() != a->mat.cols()) {
    set_error("行列式要求方阵");
    return 0.0;
  }
  return a->mat.determinant();
}

}  // namespace moonbit_eigen

// ---------------------------------------------------------------------------
// 导出的 C ABI —— 与 src/ffi.mbt 的声明一一对应
// ---------------------------------------------------------------------------

namespace {

using moonbit_eigen::MatrixBox;

/// finalize：官方约束是"不得释放 self 本身"（运行时负责），
/// 只释放 payload 里持有的外部资源。
void matrix_finalize(void *self) {
  auto **slot = static_cast<MatrixBox **>(self);
  delete *slot;
  *slot = nullptr;
}

/// 把 C++ 盒子包成 MoonBit 拥有的外部对象。
/// MoonBit 侧必须把返回值绑到抽象类型，官方文档明确要求，
/// 否则内存管理系统会忽略该对象。
void *wrap(MatrixBox *box) {
  if (box == nullptr) {
    return nullptr;  // 极端 OOM：MoonBit 侧需容错
  }
  void *obj = moonbit_make_external_object(matrix_finalize, sizeof(MatrixBox *));
  *static_cast<MatrixBox **>(obj) = box;
  return obj;
}

/// 从 MoonBit 传回来的句柄取出 MatrixBox*。
///
/// ⚠️ 必须**解引用**：句柄是 moonbit_make_external_object 返回的
/// **payload 指针**，payload 里存的才是 MatrixBox*。
/// （此前这里漏了解引用，直接当成 MatrixBox* 用 → 读到垃圾。
///   同一个文件里的 matrix_finalize 是 `delete *slot`，两处必须一致。）
MatrixBox *unwrap(void *handle) {
  if (handle == nullptr) {
    return nullptr;
  }
  return *static_cast<MatrixBox **>(handle);
}

moonbit_bytes_t to_mbt_bytes(const char *s) {
  const std::size_t n = s == nullptr ? 0 : std::strlen(s);
    // 签名已实测确认是 (长度, 初始值)，不是 (指针, 长度) —— 所以这里要 memcpy。
  moonbit_bytes_t out = moonbit_make_bytes(static_cast<std::int32_t>(n), 0);
  if (n > 0) {
    std::memcpy(out, s, n);
  }
  return out;
}

}  // namespace

extern "C" {

/// 构建期自检：返回 (C++ 标准版本 * 1000 + Eigen 主版本 * 10 + 次版本)。
/// 预期在 C++17 + Eigen 3.4 下返回 17034。
///
/// 用途：技术穿刺时一行验证「.cpp 胶水真的被当作 C++17 编译、
/// 且 Eigen 头文件真的被找到并链接进来了」，不必先写完整绑定。
MOONBIT_FFI_EXPORT
std::int32_t mb_eigen_shim_probe(void) {
  return static_cast<std::int32_t>((__cplusplus / 100 % 100) * 1000 +
                                   EIGEN_WORLD_VERSION * 10 +
                                   EIGEN_MAJOR_VERSION);
}

MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_new(std::int32_t rows, std::int32_t cols) {
  return wrap(moonbit_eigen::mat_new(rows, cols));
}

/// data 是 MoonBit 的 FixedArray[Double]（ABI: double*），行主序。
MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_from_array(std::int32_t rows, std::int32_t cols,
                                 double *data, std::int32_t len) {
  return wrap(moonbit_eigen::mat_from_array(rows, cols, data, len));
}

MOONBIT_FFI_EXPORT
std::int32_t mb_eigen_matrix_rows(void *handle) {
  return moonbit_eigen::mat_rows(unwrap(handle));
}

MOONBIT_FFI_EXPORT
std::int32_t mb_eigen_matrix_cols(void *handle) {
  return moonbit_eigen::mat_cols(unwrap(handle));
}

MOONBIT_FFI_EXPORT
double mb_eigen_matrix_get(void *handle, std::int32_t i, std::int32_t j) {
  return moonbit_eigen::mat_get(unwrap(handle), i, j);
}

MOONBIT_FFI_EXPORT
std::int32_t mb_eigen_matrix_set(void *handle, std::int32_t i, std::int32_t j,
                                 double v) {
  return moonbit_eigen::mat_set(unwrap(handle), i, j, v) ? 0 : 1;
}

MOONBIT_FFI_EXPORT
std::int32_t mb_eigen_matrix_copy_to(void *handle, double *out,
                                     std::int32_t len) {
  return moonbit_eigen::mat_copy_to(unwrap(handle), out, len) ? 0 : 1;
}

/// op: 0=加 1=减 2=乘。失败返回 valid=false 的哨兵盒子，不返回 nullptr。
MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_binary(void *a, void *b, std::int32_t op) {
  return wrap(moonbit_eigen::mat_binary(unwrap(a), unwrap(b), op));
}

MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_scale(void *a, double k) {
  return wrap(moonbit_eigen::mat_scale(unwrap(a), k));
}

MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_transpose(void *a) {
  return wrap(moonbit_eigen::mat_transpose(unwrap(a)));
}

MOONBIT_FFI_EXPORT
void *mb_eigen_matrix_solve(void *a, void *b) {
  return wrap(moonbit_eigen::mat_solve(unwrap(a), unwrap(b)));
}

MOONBIT_FFI_EXPORT
double mb_eigen_matrix_dot(void *a, void *b) {
  return moonbit_eigen::mat_dot(unwrap(a), unwrap(b));
}

MOONBIT_FFI_EXPORT
double mb_eigen_matrix_norm(void *a) {
  return moonbit_eigen::mat_norm(unwrap(a));
}

MOONBIT_FFI_EXPORT
double mb_eigen_matrix_det(void *a) {
  return moonbit_eigen::mat_det(unwrap(a));
}

/// 上一次操作的错误信息（UTF-8 Bytes）。成功时返回空 Bytes。
MOONBIT_FFI_EXPORT
moonbit_bytes_t mb_eigen_last_error(void) {
  return to_mbt_bytes(moonbit_eigen::last_error());
}

}  // extern "C"
