# MoonFFI Lab

用 MoonBit 为原生 C/C++ 绑定生成有状态调用序列，在独立进程执行，保存失败证据，并缩减成可重放的案例。

目前已验证 Windows x64/MSVC 的七项 native suite，以及 Linux x86_64 的普通 native、SDK 和原生崩溃/ASan 错误缩减。两平台的验证范围并不完全相同。Buffer fixture 的三种行为缺陷为人工注入；专用崩溃和超时探针用于验证控制器。Eigen 使用有来源和哈希记录的真实绑定快照。

首次使用请从 [独立复现入口](docs/INDEPENDENT-REPRODUCTION.md) 开始。 本轮四项补齐的[复审项目说明](docs/HACKATHON-SUBMISSION.md)、[成熟框架功能对照](docs/FRAMEWORK-COMPARISON.md)及[可复制报名补充材料](docs/RESUBMISSION-TEXT.md)已按固定提交整理。[v0.1.0-rc.2 源码预发布](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.2)已提供固定提交的 563 文件源码包及校验清单；候选自身 Windows 七项、Linux 和源码准备控制均通过，四份发布附件及标签已核对，见 [发布快照](docs/evidence/prerelease-v0.1.0-rc.2-20261026.json)。历史 rc.1 及其证据保持原义。支持范围和未完成项见 [发布记录](docs/RELEASE-PLAN.md)；独立使用者反馈仍待完成，尚未发布稳定版或 registry 包。

首次运行失败、文档卡点和成功复现均可通过 [复现反馈表单](https://github.com/serikaonoe123/moonffi-lab/issues/new?template=independent-reproduction.yml) 记录；参与方式见 [贡献说明](CONTRIBUTING.md)。

## Mooncakes 发布准备

验收要求的 registry 发布正在准备，当前还未上传。账号 `serikaonoe123` 已由用户注册并确认，候选包名为 `serikaonoe123/moonffi-lab@0.1.0`；官方公开接口本轮查询返回该版本不存在。账号确认前的 32 文件包已通过本地/云端归档消费者和 Windows/Linux 完整回归，见 [准备证据](docs/evidence/mooncakes-preparation-20261030.json)。定稿说明后的归档需重新核对，再确认发布；包内容、安装示例和后续验收见 [发布准备](docs/MOONCAKES-PUBLISHING.md)及 [registry README](README.mooncakes.md)。GitHub rc.2 不代替 Mooncakes 发布；这项工作仍列为未完成。

## 准备和验证

**工具链升级（2026-10-24）**：当前开发锁使用官方 `0.10.17+d971670cd` 固定版本地址。候选 `bda5201` 已通过 [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40058468249)及 [Linux 验收](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40058468261)，八份产物的归档、源码、工具链及原始报告已核对，见 [升级记录](docs/evidence/toolchain-upgrade-20261024.json)。旧版固定来源及验收保留在 `fdd8849`，不混用两个版本的证据。

当前开发锁使用 moon/moonrun 0.1.20261023、moonc `v0.10.17+d971670cd (2026-10-23)`，core 为同版本的 1,213 份源码；rc.1 的旧 CI 使用 moon 0.1.20261016。验证状态见 [工具链记录](docs/TOOLCHAIN-LOCK.md)。依赖锁定 `moonbitlang/async@0.22.5`。版本以实际自报和内容锁为准，不等同于文档仓库标签或“最新正式版”。需要 Windows x64、PowerShell 7 和带 C++ 工作负载及 Windows SDK 的 MSVC Build Tools；完整环境控制入口使用 PowerShell 7.5+。本机 native 恢复记录见 [D8050 解决记录](docs/LOCAL-WINDOWS-TEMP.md)。

需要安装当前锁定工具链时，可运行 `scripts/install-toolchain.ps1`，按固定 SHA-256 在新目录安装工具包和标准库，支持保留归档后的离线重装。使用方法及固定版本地址的可用性限制见 [工具链内容锁定](docs/TOOLCHAIN-LOCK.md)。

```powershell
$PSVersionTable.PSVersion # Major 应为 7；从开始菜单打开 PowerShell 7
& .\scripts\assert-toolchain.ps1 # 先按工具链内容锁定指南选择当前安装
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn -j 1
moon build --target native
& .\scripts\verify.ps1
```

`verify.ps1` 创建新的 `results/verify-<随机ID>`，检查源码快照完整性，运行单测、两个适配器的正常场景、三类缺陷的缩减和修复后重放、独立子集校验、崩溃/超时及缩减器边界测试。失败时保留已有日志，不自动删除任何输出。若执行被权限或安全策略拦截，停止对应操作并检查原始报错。

工作区中的工具带低完整性标签、系统临时目录不可写时，可运行 `& .\scripts\verify-clean.ps1 -WorkspaceTemp -Suite behavior,sdk -OfflineDependencySource .\.mooncakes`。它只在本轮输出目录内放置临时文件，结束后恢复进程环境，并用 Git 导出的源码避免扫描 `results` 中的历史快照；没有依赖源码缓存时省略离线参数。详见 [复现与权限边界](docs/LOCAL-WINDOWS-TEMP.md)。

Windows CI 和指定提交的源码复现见 [复现指南](docs/REPRODUCIBILITY.md)。`scripts/verify-clean.ps1` 从 Git 导出新源码目录，记录工具链与文件哈希，再执行所选验收；离线来源会明确标记。[已核对云端基线](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440)通过提交 `1f065527` 的 behavior、ASan、benchmark、generation、sdk、sqlite 六项：69+6+48+8 单测、704 个 Buffer/Eigen 生成场景、96 个 SQLite 场景、128 份历史输入及 189 次缩减通过。68 个关键文件逐任务匹配提交归档，96 份 SQLite 输入与本地字节一致，既有缩减基准不变；见 [云端证据](docs/evidence/github-ci-39248905440.json)。后续候选仍按自身提交验收。

本次升级先遇旧锁归档变化，再发现新标准库的随机算法变化；全部失败证据保留在 [验证记录](docs/VALIDATION.md)。Buffer/Eigen 原生成器版本使用固定历史随机流，保留旧输入 SHA 检查；独立 SDK 的新随机流明确标为 `counter-walk-2`。工具链仍按固定内容身份检查，不自动接受任意 latest 归档。

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

默认仍保存 Crash 原始退出码；显式启用 `native_errors=true` 后，可按主程序故障位置或完整 ASan 调用帧签名自动缩减。Windows/Linux 人工故障三策略均经固定提交验收，32→2 步、独立重放与不同位置对照通过；见 [原生错误协议与限制](docs/NATIVE-ERRORS.md)。报告不把普通崩溃归因为某种内存错误。

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

[社区 SQLite 独立消费者](examples/sqlite-lab/README.md)接入未经修改的 `moonbit-community/sqlite3` 固定源码，通过公开 core/runner 检查绑定参数、查询状态及连接/语句生命周期。[验收记录](docs/SQLITE-INTEGRATION.md)包含 48 项上游测试、8 项适配测试及 96 个隔离场景；[六项 Windows CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440) 全部通过且产物已核对。这证明真实绑定可以复用协议，尚未发现未知缺陷。

执行 `& .\scripts\verify-asan.ps1` 会在新的结果目录创建源码副本，仅在副本中启用 MSVC ASan：先要求三次明确标注的越界 canary 产生真实检测报告，再运行 Buffer/Eigen 各十个正常场景。主源码和普通构建配置保持原样，脚本保留构建日志、运行时和二进制哈希、源码清单及插桩范围。匹配的 ASan 诊断头与摘要被分类为 `MemoryError`；没有足够根因指纹时不自动缩减。普通构建拒绝 ASan profile/canary。

参数简化由 MoonBit `core.arguments_simpler` 控制：保留原有 JSON 编码长度下降规则，并支持等长十进制整数的绝对值下降，包括嵌套数组和对象；大整数按原始数字比较。候选仍须通过纯模型校验及相同失败指纹重放，规则见 [适配器指南](docs/ADAPTERS.md)。

参数候选现在会在每次接受变化后重新生成，并与单步删除交替，直到本轮没有可接受变化或预算终止。`reduction.json` 的 `argument_search` 保存参数扫描轮次、当前候选检查数、完成状态及未决结果；历史报告没有此字段时仍可读取。最终确认仍预留三次独立重放，搜索完成不代表参数最小。

状态修整使用 MoonBit 增量依赖索引，避免反复验证全部前缀；结构和模型都接受一步后才提交依赖变化。拒绝后的状态保持约定及复杂度范围见 [适配器指南](docs/ADAPTERS.md)。

当前维护候选 `33bbfea` 已在 PR 合成合并提交 `fee7f97`（完整源码树一致）通过 [Windows 七项 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40054024435) 及 [Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40054024444)，产物已核对，见 [固定提交证据](docs/evidence/maintenance-hosted-20261024.json)。后续仅文档变更不作为新的执行记录；运行代码变更须重新验收。Linux 不宣称与 Windows 七项 suite 完全等价。当前限制：ASan 仅插桩 Buffer C fixture、Eigen C++ shim（含其模板实例）及原生错误专项的 faults.c，MoonBit 生成的 C、运行时、async stubs 和其他预编译库未插桩。等长小数或指数编码尚无专门简化规则，也不保证参数最小。Eigen 的释放步骤只删除 MoonBit 引用，不验证 finalizer 的精确时刻或原生分配平衡。进程隔离是故障隔离机制。

旧 Eigen 绑定属于既有成果，新增引擎、适配器和验收脚本属于本项目工作。来源和许可见 [快照记录](vendor/eigen-binding/SNAPSHOT.md)。本项目 MIT；导入源码保留原有许可。
