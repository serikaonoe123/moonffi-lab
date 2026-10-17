# Eigen 真实绑定的状态探索

本页记录六操作阶段。后续新增的合法 Add/Mul、数值状态修整、192 场景验收及旧输入字节回归，见 [算术扩展](EIGEN-ARITHMETIC.md)；下文的 128 场景与 37 单测为本阶段历史数据。

2026-10-17 新增 `--generator stateful`，标识为 `eigen-stateful-1`。它通过当前存活矩阵和形状选择合法操作，不附加固定的转置或错误触发后缀。默认 `eigen-1` 保留原有契约回归；保存输入继续按具体步骤重放。

## 生成规则与观察范围

无存活对象时只能构造；有对象时可以写入、检查和释放引用；不足八个存活对象时允许构造或转置到新对象。只有存活集合中存在形状不同的一对矩阵，才允许 `RejectAdd`，并随机选择操作数顺序。对象按数组顺序选择，ID 单调递增且不复用，避免 map 遍历顺序影响 seed 的重现。

矩阵行列分别为 1–4，整数值为 -100–100，边界值 -100/-1/0/1/100 与区间随机值混合选择；写入索引始终在当前形状内。最多八个存活矩阵；公共函数将长度限制在 0–256，CLI 接受 8–256 步。生成只记录形状，不创建原生对象，也不调用适配器数值模型或修整器。

适配器用纯整数数组核对形状和全部元素，先拒绝 NaN/Infinity。本阶段将构造、Set、Transpose 和不兼容 Add 返回错误后的检查扩展到**所有存活矩阵**，按对象 ID 排序检查；因此修改源对象或转置结果时，不需要等待下一次随机 Check 才能观察意外共享存储。`Check` 观察指定对象，`Drop` 移除引用，teardown 清空引用；不保证 finalizer 的精确运行时刻或原生分配平衡。

这是当前六种操作及受限数据域的验证：构造、写入、读取检查、转置、不兼容加法和释放引用。没有测试合法矩阵加法结果、乘法、求解器或完整数值稳定性。Eigen 没有人工缺陷模式；不把正常通过写成发现真实缺陷。

## 实测与独立验证

`scripts/verify-eigen-generation.ps1` 对 default/stateful 分别使用 seed 17–80、64 步，共 128 个独立工作进程；所有场景均为 Pass，且输入步数、生成器版本和 seed 被逐例核对。操作计数每种生成器均为 4096。结果如下：

| 观测指标 | 默认契约生成器 | stateful |
|---|---:|---:|
| 通过场景 | 64/64 | 64/64 |
| 不同操作顺序 | 64 | 64 |
| 相邻操作组合（包含 start→new） | 14 | 37 |
| 已观察矩阵形状 | 10 | 16 |
| 已标记状态特征 | 7 | 15 |
| Transpose 操作数 | 64 | 526 |
| RejectAdd 操作数 | 64 | 666 |
| 最大存活矩阵数 | 3 | 8 |

排除虚拟起点后，相邻操作对为 13 和 36；stateful 在这批输入上观察到全部六种操作的 36 种有序对。特征包括转置链、源矩阵存活时写转置、转置存活时写源矩阵、删除源引用后检查转置、仅行数/仅列数不匹配的加法错误、边界值及对象清空后的重新构造。

这些是输入中的操作和状态特征观测，不是原生代码覆盖率或状态空间穷尽。两种生成器的值域、对象数量及分布不同；适配器的全对象核对次数也随存活数变化。没有测量或声明性能提升、缺陷发现率或原生根因。

本轮验证还包括：

- 独立二维数组 oracle 核验 128 个 seed × 6 种长度（0/1/8/32/64/256），共 768 条轨迹，逐项核对形状、索引、依赖声明、对象寿命及所有 16 种形状；不使用生成器状态、适配器的扁平数值模型或 transpose 帮助函数计算期望。
- 32 条 64 步真实 native 随机序列，在每一步之后将所有存活矩阵的原生值与独立二维数组比较，包括转置链、写入及错误后状态。
- 一个明确标注的 oracle 探针在单测中故意将转置句柄替换成源句柄，确认写源对象会在同一步得到 `matrix-values`；它没有修改 vendored 绑定，也不代表真实库缺陷。
- 37/37 单测及完整 behavior 集成验收通过；ASan 正常对照与 canary 通过，额外 16 条 Eigen stateful 场景通过。ASan 仅插桩已声明的 C/C++ shim，范围见 [验证记录](VALIDATION.md)。
- 同 seed 的独立生成进程得到相同具体输入；保存输入重放通过。未知生成器、Eigen 人工缺陷模式和 replay 的生成器选项均在创建输出前拒绝。

完整生成验收现同时运行 Buffer 的 512 个场景和 Eigen 的 128 个场景。证据目录为 `results/generation-eigen-stateful-20261017`、`results/verify-eigen-stateful-20261017` 和 `results/asan-eigen-stateful-20261017`；初轮 Eigen 单独验收保留在 `results/eigen-generation-stateful-20261017`。结构化摘要见 [Eigen 实验快照](evidence/generation-eigen-20261017.json)。

## 复现

```powershell
moon build --target native --frozen
$eigen = '.\_build\native\debug\build\cmd\eigen-lab\eigen-lab.exe'
& $eigen run --generator stateful --seed 17 --cases 64 --steps 64 --out results/eigen-exploration
& .\scripts\verify-eigen-generation.ps1
# Buffer 与 Eigen 的完整生成验收；CI 的 generation 任务调用它
& .\scripts\verify-generation.ps1
```

输出目录必须尚不存在。[保存的 seed 17 输入](../examples/eigen-stateful/README.md) 提供一个可直接重放的正确示例，验收会核对哈希并重放它。来源、绑定版本和许可见 [快照记录](../vendor/eigen-binding/SNAPSHOT.md)。新增实现没有修改导入的绑定及 Eigen 源码。
