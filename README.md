# MoonFFI Lab

用 MoonBit 为原生 C/C++ 绑定生成有状态调用序列，在独立进程执行，保存失败证据，并缩减成可重放的案例。

目前提供 Windows/MSVC 的 **behavior** 模式及单独构建的 ASan stub profile。Buffer fixture 的三种行为缺陷为人工注入；专用崩溃和超时探针用于验证控制器。Eigen 使用有来源和哈希记录的真实绑定快照。

## 准备和验证

已验证工具链：moon 0.1.20261012、moonc 0.10.15；依赖锁定 `moonbitlang/async@0.22.5`。需要 Windows x64、PowerShell 7 和带 C++ 工作负载及 Windows SDK 的 MSVC Build Tools。

```powershell
Set-Location D:\moonbit\moonffi-lab
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn -j 1
moon build --target native
& .\scripts\verify.ps1
```

`verify.ps1` 创建新的 `results/verify-<随机ID>`，检查源码快照完整性，运行单测、两个适配器的正常场景、三类缺陷的缩减和修复后重放、独立子集校验、崩溃/超时及缩减器边界测试。失败时保留已有日志，不自动删除任何输出。若执行被权限或安全策略拦截，停止对应操作并检查原始报错。

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

Eigen 场景检查读写、转置结果与源矩阵的独立性，以及不兼容加法返回错误后两个操作数仍保持原值。数值检查先拒绝 NaN/Infinity。当前未测试求解器的完整数值稳定性。

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

`confirmed=true` 只表示最终候选连续三次保持失败指纹。必须再看 `stop_reason`：`search_complete` 表示完成本轮策略；`execution_budget`/`wall_budget` 表示预算终止；`unstable_baseline`/`unstable_final` 表示重放不稳定；`unsupported_outcome` 表示没有可缩减的性质失败。**确认失败不代表已经缩短，也不代表全局最短。**

## 接入和边界

见 [适配器指南](docs/ADAPTERS.md) 和 [缩减器验证记录](docs/VALIDATION.md)。`core` 和 `runner` 不包含矩阵专用规则。适配器通过编译期接入；每条完整轨迹在同一个新工作进程中保留状态，每个缩减候选使用另一个新进程。

执行 `& .\scripts\verify-asan.ps1` 会在新的结果目录创建源码副本，仅在副本中启用 MSVC ASan：先要求三次明确标注的越界 canary 产生真实检测报告，再运行 Buffer/Eigen 各十个正常场景。主源码和普通构建配置保持原样，脚本保留构建日志、运行时和二进制哈希、源码清单及插桩范围。匹配的 ASan 诊断头与摘要被分类为 `MemoryError`；没有足够根因指纹时不自动缩减。普通构建拒绝 ASan profile/canary。

当前限制：只有 Windows native 完整验证；ASan 仅插桩 Buffer C fixture 和 Eigen C++ shim（含其模板实例），MoonBit 生成的 C、运行时、async stubs 和其他预编译库未插桩。参数简化使用 JSON 编码长度下降作为保守度量，尚不覆盖等长数值简化。Eigen 的释放步骤只删除 MoonBit 引用，不验证 finalizer 的精确时刻或原生分配平衡。进程隔离是故障隔离机制。

旧 Eigen 绑定属于既有成果，新增引擎、适配器和验收脚本属于本项目工作。来源和许可见 [快照记录](vendor/eigen-binding/SNAPSHOT.md)。本项目 MIT；导入源码保留原有许可。
