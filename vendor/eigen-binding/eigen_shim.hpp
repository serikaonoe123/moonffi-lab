// eigen_shim.hpp —— 纯 C++ 逻辑层
//
// 这一层不认识 MoonBit：没有 moonbit.h，没有引用计数，没有 GC。
// 它只做一件事：把 Eigen 的模板世界收敛成一组简单的、不抛异常的 C++ 方法。
//
// 为什么要分层？见 docs/PITFALLS.md：
// Eigen 是重度模板库，模板无法直接跨越 C ABI。
// 唯一可行的做法是"在 C++ 侧把模板实例化掉"，把边界收窄成
// 具体的 MatrixXd 运算 —— 这正是本文件存在的理由。

#pragma once

#include <cstdint>
#include <string>
#include <vector>

// Eigen 是 header-only；按 scripts/fetch-eigen.ps1 放到 third_party/ 下。
// 用相对包含（相对于本文件的目录），这样不依赖 cc-flags 的 -I，
// 从而绕开 moon issue #586（cc-flags 按 pwd 而非包根目录解析）。
#include "third_party/eigen/Eigen/Dense"

namespace moonbit_eigen {

/// 包装一个动态尺寸、双精度的矩阵。
///
/// valid == false 表示"错误哨兵"：C ABI 无法向 MoonBit 返回空指针
/// （抽象类型没有 null 语义），因此失败时返回一个 valid=false 的盒子，
/// MoonBit 侧通过 rows() 返回 -1 来识别，错误原因用 last_error() 取。
struct MatrixBox {
  bool valid = true;
  Eigen::MatrixXd mat;
};

/// 线程局部错误信息。每次调用先清空，失败时写入原因。
/// 单线程 CLI 场景下它等价于全局变量；用 thread_local 是为了将来
/// 多线程调用 shim 时不会互相污染。
const char *last_error() noexcept;
void clear_error() noexcept;
void set_error(const std::string &msg) noexcept;

/// 分配一个错误哨兵盒子（valid=false，0x0 矩阵）。
MatrixBox *make_invalid() noexcept;

inline bool is_valid(const MatrixBox *box) noexcept {
  return box != nullptr && box->valid;
}

// 下面这些函数都不抛异常：所有 Eigen 断言与 std::exception 都被转成
// valid=false + 错误信息。

MatrixBox *mat_new(std::int32_t rows, std::int32_t cols) noexcept;
MatrixBox *mat_from_array(std::int32_t rows, std::int32_t cols, const double *data,
                          std::int32_t len) noexcept;

std::int32_t mat_rows(const MatrixBox *box) noexcept;
std::int32_t mat_cols(const MatrixBox *box) noexcept;
double mat_get(const MatrixBox *box, std::int32_t i, std::int32_t j) noexcept;
bool mat_set(MatrixBox *box, std::int32_t i, std::int32_t j, double v) noexcept;
bool mat_copy_to(const MatrixBox *box, double *out, std::int32_t len) noexcept;

MatrixBox *mat_binary(const MatrixBox *a, const MatrixBox *b, int op) noexcept;
MatrixBox *mat_scale(const MatrixBox *a, double k) noexcept;
MatrixBox *mat_transpose(const MatrixBox *a) noexcept;
MatrixBox *mat_solve(const MatrixBox *a, const MatrixBox *b) noexcept;
double mat_dot(const MatrixBox *a, const MatrixBox *b) noexcept;
double mat_norm(const MatrixBox *a) noexcept;
double mat_det(const MatrixBox *a) noexcept;

}  // namespace moonbit_eigen
