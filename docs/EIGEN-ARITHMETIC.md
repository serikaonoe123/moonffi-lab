# Eigen 合法加法与乘法

2026-10-17 新增 `--generator arithmetic`（`eigen-arithmetic-1`），在已有六种操作之外生成合法矩阵加法和乘法。调用已有 vendored `Matrix::add` / `Matrix::mul`，绑定、Eigen 头文件、core 和 runner 均未修改。原 default / stateful 仍可使用；本轮核对其 seed 17–80、64 步的 128 份具体输入，SHA-256 与上一轮记录全部一致。

## 数值域和纯模型

`Add(a,b,out)` 要求形状相同；`Mul(a,b,out)` 要求左列数等于右行数。二者可使用同一个矩阵作为两个操作数，但输出必须是全新 ID。结果拥有独立存储；构造、写入、转置、合法算术和不兼容加法错误之后，适配器按 ID 排序核对所有存活矩阵，观察对其他对象的意外修改。

行列仍为 1–4，构造和 Set 的输入为 -100–100。参考模型使用扁平 `Int64` 数组，所有存储元素限制在 ±1,000,000。单个乘积绝对值最多 10^12，每个点积最多四项，因此任何累加中间量绝对值不超过 4×10^12，小于 Int64 范围和 binary64 精确整数范围 2^53。观察值先排除 NaN/Infinity，再与模型作精确相等比较；这里不使用浮点容差，也不据此验证任意浮点计算的稳定性。

validate 从新的 `EigenState` 检查完整轨迹，不执行 FFI。repair 同样从新模型开始，只删除非法步骤并记录原因。删除 Set 可能使后续乘法超过数值上限，即使对象依赖仍完整；因此 Eigen 已从仅依赖修整改为语义状态修整。拒绝形状或数值非法操作时，不修改模型。

## 生成规则

生成器仅保存形状和元素绝对值的保守上界，不使用适配器数值模型。加法要求两个上界之和不超过 10^6；乘法要求“左上界 × 右上界 × 内维数”不超过 10^6。Set 只提高该上界，Transpose 复制上界。它可能排除实际上因抵消而合法的计算，但生成的每步均满足数值域；手写输入仍按实际计算结果验证，允许抵消。

操作数候选有确定的数组顺序，包含自加和方阵自乘；从当前可执行操作中随机选择，不附加固定算术后缀。最多八个存活矩阵、256 步。原 stateful 路径不增加随机数调用；生成验收对旧输入字节作回归检查，范围限于已保存的 seed 和长度。

## 本地实测

完整生成验收使用 seed 17–80、64 步：Buffer 512 场景、Eigen 三种生成器各 64 场景，合计 704 场景均按预期完成；Eigen 全部 Pass。

| Eigen 观测 | default | stateful | arithmetic |
|---|---:|---:|---:|
| 通过场景 | 64/64 | 64/64 | 64/64 |
| 不同操作顺序 | 64 | 64 | 64 |
| 相邻操作组合（含 start） | 14 | 37 | 65 |
| 矩阵形状 | 10 | 16 | 16 |
| 合法 Add | 0 | 0 | 325 |
| Mul | 0 | 0 | 241 |
| 最大存活矩阵数 | 3 | 8 | 8 |

arithmetic 观察到全部八种操作的 64 种有序相邻组合，另含 start→new。记录的 22 个特征包括非方阵乘法、自加、自乘、算术链、修改结果、结果存活时修改操作数，以及释放操作数后检查结果。这些是输入和状态特征，不是原生代码覆盖率或缺陷发现率。

新增六项单测使根模块达到 43/43：

- 128 seed × 六种长度，共 768 条算术轨迹，用独立二维 Double 数组逐步计算，检查依赖、寿命、值域、序列化与修整不变性。它不调用生产模型的扁平索引或算术帮助函数。
- 32 条 64 步 native 算术轨迹，每步导出并比对全部存活矩阵；另有固定有符号非方阵手算产品、结果/操作数变更及释放后的检查。
- 数值上下限、形状拒绝且状态不变，以及乘积达 ±10^12、部分和达 2×10^12 后抵消为零的精确计算。
- 七步轨迹全部 128 个子集，与独立标量解释器比较修整结果，覆盖删除 Set 后算术越界及后续依赖级联删除。
- 明确标注的 oracle 探针仅替换单测中的句柄表，确认 Add/Mul 的结果和操作数发生意外共享时，两种写入方向均在同一步报告 `matrix-values`；没有改动真实绑定，也不是发现真实缺陷。

完整 behavior 验收通过。ASan 保留三次越界 canary、原有正确对照及 Buffer/Eigen stateful 各 16 条，新增 16 条算术轨迹与固定算术案例，全部符合预期。ASan 范围仍限 Buffer C fixture 与 Eigen C++ shim/实例化模板，未覆盖 MoonBit 生成的 C、运行时、async 或 SDK 计数器 C。

原始证据为 `results/verify-eigen-arithmetic-20261017`、`results/generation-eigen-arithmetic-20261017`、`results/asan-eigen-arithmetic-20261017`；摘要见 [本地快照](evidence/eigen-arithmetic-20261017.json)。先前六操作阶段的数据保留在 [原实验](EIGEN-GENERATION.md)。Drop 和 teardown 只移除引用，不证明 finalizer 时刻或原生分配平衡；未覆盖求解器、任意浮点值或完整数值稳定性。

[Actions run 39013008257](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39013008257) 在提交 `262d6ec5914bd62d4eeed7245ebd6fb043a57703` 上通过 behavior、ASan、benchmark、generation、sdk 五项。五份产物均已下载核对：43 根模块单测、5 SDK 单测、704 场景及算术 ASan 对照通过；192 个 Eigen 输入与覆盖观测和本地一致，旧输入哈希检查 128 次。189 次缩减全部完成、63 组重复一致、214 个真子集及全部正确实现重放通过；189 行结构指标与前一提交一致。源码归档哈希在五项间一致，日志确认重新下载 async 0.22.5。见 [云端快照](evidence/github-ci-39013008257.json)，原始下载为 `results/github-ci-39013008257`。

## 复现

```powershell
moon build --target native --frozen
$eigen = '.\_build\native\debug\build\cmd\eigen-lab\eigen-lab.exe'
& $eigen run --generator arithmetic --seed 17 --cases 64 --steps 64 --out results/eigen-arithmetic-demo
& $eigen replay examples/eigen-arithmetic/case.json --out results/eigen-arithmetic-control
& .\scripts\verify-eigen-generation.ps1
& .\scripts\verify-generation.ps1
& .\scripts\verify-asan.ps1
```

输出目录必须是新目录。生成验收核对两个固定示例的哈希和重放、stateful/arithmetic 的跨进程确定性、旧输入字节，以及非法 CLI 选项。固定算术输入为 [手写正确对照](../examples/eigen-arithmetic/README.md)，不是由其 seed 重新生成的随机案例。
