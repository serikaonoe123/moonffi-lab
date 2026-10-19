# MoonFFI Lab

用 MoonBit 为原生 C/C++ 绑定生成有状态调用序列，在独立进程执行，保存失败证据，并缩减成可重放的案例。

目前提供 Windows/MSVC 的 **behavior** 模式及单独构建的 ASan stub profile。Buffer fixture 的三种行为缺陷为人工注入；专用崩溃和超时探针用于验证控制器。Eigen 使用有来源和哈希记录的真实绑定快照。

## 准备和验证

已验证工具链：moon 0.1.20261012、moonc 0.10.15；依赖锁定 `moonbitlang/async@0.22.5`。需要 Windows x64、PowerShell 7 和带 C++ 工作负载及 Windows SDK 的 MSVC Build Tools。

需要安装这份已验证工具链时，可运行 `scripts/install-toolchain.ps1`，按固定 SHA-256 在新目录安装工具包和标准库，支持保留归档后的离线重装。使用方法及滚动下载地址的可用性限制见 [工具链内容锁定](docs/TOOLCHAIN-LOCK.md)。

```powershell
Set-Location D:\moonbit\moonffi-lab
$PSVersionTable.PSVersion # Major 应为 7；从开始菜单打开 PowerShell 7
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn -j 1
moon build --target native
& .\scripts\verify.ps1
```

`verify.ps1` 创建新的 `results/verify-<随机ID>`，检查源码快照完整性，运行单测、两个适配器的正常场景、三类缺陷的缩减和修复后重放、独立子集校验、崩溃/超时及缩减器边界测试。失败时保留已有日志，不自动删除任何输出。若执行被权限或安全策略拦截，停止对应操作并检查原始报错。

Windows CI 和指定提交的源码复现见 [复现指南](docs/REPRODUCIBILITY.md)。`scripts/verify-clean.ps1` 从 Git 导出新源码目录，记录工具链与文件哈希，再执行所选验收；离线依赖源码复用会明确标记。[最近一次通过的 MoonBit 云端验收](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39210490957)的 behavior、ASan、benchmark、generation、sdk 五项已通过，测试提交为 `0869321`。缩减器会跳过同一步骤同一扫描内已有明确结果的重复参数候选，超时和协议错误仍独立执行。64 主模块/6 SDK 单测、九组新探针及 189 次固定语料缩减通过，63/63 组重复一致；原始失败与后续授权验证均保留，见 [验证记录](docs/VALIDATION.md)和[该轮云端证据](docs/evidence/github-ci-39210490957.json)。

当前 Int64 候选实现 `e7dd774` 已通过本地 68 主模块/6 SDK 单测、21 组阈值探针及固定语料检查。[本轮 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39216392303)五项均在工具链归档身份校验阶段失败，尚未执行云端业务测试。官方滚动地址的当前校验值已与锁定值不同；按用户决定保留原工具链锁，记录阻塞，不升级或放宽校验，见 [失败证据](docs/evidence/github-ci-39216392303.json)。

Buffer 新增 `--generator stateful`，按当前句柄、共享引用和长度选择合法的随机操作，覆盖扩缩容与边界数据；原默认生成器保留固定契约回归。运行 `scripts/verify-generation.ps1` 可复现两种生成器的操作覆盖与人工缺陷观测，方法、结果及限制见 [生成实验](docs/GENERATION-STUDY.md)。

## 一次完整演示

以下目录必须尚不存在；重复演示请更换目录名。

```powershell
$buffer = '.\_build\native\debug\build\cmd\buffer-lab\buffer-lab.exe'
& $buffer run --mode correct --cases 10 --out results/demo-correct
& $buffer run --mode error --out results/demo-defect
& $buffer shrink results/demo-defect/case-1/case.json --budget 100 --out results/demo-shrink
& $buffer replay results/demo-shrink/reduced.json --out results/demo-replay
& $buffer replay results/demo-shrink/reduced.json --mode correct --out results/demo-fixed
```

缺陷运行、确认失败的缩减和缺陷重放预期退出码均为 **1**；正常/修复版本为 **0**。`--mode correct` 是明确切换人工 fixture 实现，不会修改保存的原始输入文件。三个缺陷模式分别为 `nul`（嵌入零字节截断）、`share`（提前关闭共享资源）和 `error`（返回错误却破坏状态）。避免把 Windows 保留设备名 `nul` 用作输出目录。

```powershell
& .\_build\native\debug\build\cmd\eigen-lab\eigen-lab.exe run --cases 10 --out results/demo-eigen
```

Eigen 场景检查读写、合法加法和乘法、结果与源矩阵的独立性，以及不兼容加法返回错误后两个操作数仍保持原值。参考模型为 Int64，矩阵元素限制在 ±1,000,000，数值检查先拒绝 NaN/Infinity，再按精确整数核对。当前未测试求解器或任意浮点计算的完整数值稳定性。

Eigen 支持 `--generator stateful` 的六操作探索，以及 `--generator arithmetic` 的八操作探索；变更和加法错误后核对全部存活矩阵。运行 `scripts/verify-eigen-generation.ps1` 可复现 192 个场景，完整 `verify-generation.ps1` 合计验收两种绑定的 704 个场景。方法、独立数值 oracle 及限制见 [算术实验](docs/EIGEN-ARITHMETIC.md) 和[早期探索实验](docs/EIGEN-GENERATION.md)，可直接重放[算术对照](examples/eigen-arithmetic/README.md)及[随机示例](examples/eigen-stateful/README.md)。

## 结果和诊断

每次子进程执行保留 `case-N/case.json`、`events.jsonl`、`result.json`（仅正常完成时）、`stdout.log`、`stderr.log`、`report.json` 和 `report.md`。输入保存具体步骤、数据、seed 和版本，不依赖重新运行生成器来重放。

通过要求：退出码 0、完整步骤证据、有效完成记录和成功 teardown。最后观察到的步骤不等于已证明的根因。输出目录不能复用，防止旧结果造成误判。

| CLI 退出码 | 含义 |
|---|---|
| 0 | 场景通过，或成功生成输入 |
| 1 | 行为失败、工作进程异常退出，或缩减后失败已确认 |
| 2 | 参数、无效案例、启动或协议错误 |
| 3 | 超时，或缩减未获得稳定确认 |

单次 Crash 的原始退出码会保存；它不提供同根因指纹，当前不会自动缩减。报告不把崩溃归因为某种内存错误。

缩减额外保存：

- `reduced.json`：当前找到的最简候选，即使未确认也会保存。
- `reduction.json`：原始和最终步数、执行次数、基线报告、停止原因、接受/拒绝/无效候选数、重放确认数。
- `reduction-events.jsonl`：每个执行或无效候选的阶段、具体输入、决定及原因；已执行候选还可对应到 `case-N` 原始日志。

缩减可选 `--strategy plain|dependency|state`（默认 `state`）：普通删除、对象依赖级联删除、纯状态模型修整。三者共享调度、预算和失败指纹。状态修整只删除不再合法的步骤，不重写输入；每个额外删除都必须记录原因。Buffer 模型现在支持共享引用及通过别名扩缩容后的索引约束。

`confirmed=true` 只表示最终候选连续三次保持失败指纹。必须再看 `stop_reason`：`search_complete` 表示完成本轮策略；`execution_budget`/`wall_budget` 表示预算终止；`unstable_baseline`/`unstable_final` 表示重放不稳定；`unsupported_outcome` 表示没有可缩减的性质失败。**确认失败不代表已经缩短，也不代表全局最短。**

`deletion_minimal=true` 进一步要求最终轨迹的每个单步删除候选都已在当前策略下检查，没有保留指纹的候选，没有环境/协议错误等未决结果，且最终三次重放一致。这是在声明的模型和观测范围内完成删除邻域检查，不表示参数最小、全局最小或底层根因相同。`neighborhood_checked`、`neighborhood_complete` 和 `inconclusive_neighbors` 保留核查计数。

运行 `& .\scripts\benchmark-reduction.ps1` 可在已构建的 Buffer 运行器上复现三种策略的对照，默认 21 个固定案例、三轮重复并轮换策略顺序。数据、候选日志、独立子集校验与 Markdown 表格写入新结果目录，通过输入及预算耗尽结果均有记录。实验范围和结论见 [缩减对照实验](docs/REDUCTION-STUDY.md)。

## 接入和边界

见 [适配器指南](docs/ADAPTERS.md) 和 [缩减器验证记录](docs/VALIDATION.md)。`core` 和 `runner` 不包含矩阵专用规则。适配器通过编译期接入；每条完整轨迹在同一个新工作进程中保留状态，每个缩减候选使用另一个新进程。

[SDK 接入指南](docs/SDK.md) 和[独立计数器模块](examples/adapter-starter/README.md)提供可运行的接入起点，覆盖纯模型、C FFI、额外生成器、失败保存、缩减及正确实现重放。`scripts/verify-sdk.ps1` 会在新工作区中只用 core/runner 公开包编译消费者并验收；当前使用本地源码工作区，没有发布 registry SDK 包。

执行 `& .\scripts\verify-asan.ps1` 会在新的结果目录创建源码副本，仅在副本中启用 MSVC ASan：先要求三次明确标注的越界 canary 产生真实检测报告，再运行 Buffer/Eigen 各十个正常场景。主源码和普通构建配置保持原样，脚本保留构建日志、运行时和二进制哈希、源码清单及插桩范围。匹配的 ASan 诊断头与摘要被分类为 `MemoryError`；没有足够根因指纹时不自动缩减。普通构建拒绝 ASan profile/canary。

参数简化由 MoonBit `core.arguments_simpler` 控制：保留原有 JSON 编码长度下降规则，并支持等长十进制整数的绝对值下降，包括嵌套数组和对象；大整数按原始数字比较。候选仍须通过纯模型校验及相同失败指纹重放，规则见 [适配器指南](docs/ADAPTERS.md)。

参数候选现在会在每次接受变化后重新生成，并与单步删除交替，直到本轮没有可接受变化或预算终止。`reduction.json` 的 `argument_search` 保存参数扫描轮次、当前候选检查数、完成状态及未决结果；历史报告没有此字段时仍可读取。最终确认仍预留三次独立重放，搜索完成不代表参数最小。

状态修整使用 MoonBit 增量依赖索引，避免反复验证全部前缀；结构和模型都接受一步后才提交依赖变化。拒绝后的状态保持约定及复杂度范围见 [适配器指南](docs/ADAPTERS.md)。

当前限制：只有 Windows native 完整验证；ASan 仅插桩 Buffer C fixture 和 Eigen C++ shim（含其模板实例），MoonBit 生成的 C、运行时、async stubs 和其他预编译库未插桩。等长小数或指数编码尚无专门简化规则，也不保证参数最小。Eigen 的释放步骤只删除 MoonBit 引用，不验证 finalizer 的精确时刻或原生分配平衡。进程隔离是故障隔离机制。

旧 Eigen 绑定属于既有成果，新增引擎、适配器和验收脚本属于本项目工作。来源和许可见 [快照记录](vendor/eigen-binding/SNAPSHOT.md)。本项目 MIT；导入源码保留原有许可。
