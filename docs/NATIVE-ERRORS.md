# 原生崩溃与 ASan 错误缩减

原生错误签名是显式启用的观测协议。`Controller::new(..., native_errors=true)` 会在每次执行前后核对工作进程可执行文件的全部字节；CLI 接入方同时使用 `cli(..., native_errors=true)`，仅在独立工作进程内安装故障记录器。默认调用保持关闭。

崩溃记录须包含支持的异常/信号、细节和主可执行文件相对位置，且与进程实际退出码一致。退出码、最后一个步骤或任意模块地址不能单独成为签名。ASan 须有一个类别一致的诊断及前两层可定位调用帧；缺少这些证据时拒绝自动缩减。相同签名不等于同根因，签名不跨构建或控制器承诺稳定。

缩减共享现有的 plain/dependency/state 策略、预算及候选合法性检查；基线和最终各要求三次相同结果。超时、环境/协议错误和无签名异常不能成为可接受的替代失败。`deletion_minimal` 只表示完成已声明删除邻域的检查，不表示全局最短。

## Windows 复现

准备锁定工具链、MSVC x64 环境和 `moonbitlang/async@0.22.5` 源码后运行：

```powershell
& ./scripts/verify-native-errors.ps1
```

脚本在新结果目录分别创建普通与 ASan 源码副本，记录源码、工具链、运行时和二进制身份。普通副本运行专项单测。两个 profile 均对项目自有、明确标注的人工故障进行三策略缩减，并检查不同故障位置和正确实现对照。不稳定基线、最终确认不稳定、弱证据、预算和默认关闭五项控制现在分别在 crash 和 ASan 两档运行。ASan 的弱证据控制使用明确标注的合成残缺诊断（类别头和摘要、无调用帧），不是实际 ASan 检测；其余 ASan 控制使用插桩后的人工故障。验收同时检查结果类别，避免误把普通崩溃当作 ASan 控制通过。ASan 仅插桩 `fixtures/native-errors/faults.c`，不覆盖 MoonBit 生成 C、运行时或 async stubs。

从指定 Git 提交导出并验收：

```powershell
& ./scripts/verify-clean.ps1 -Suite native-errors -WorkspaceTemp
```

成功报告在新目录的 `verification.json`，每个 profile 的 `checks/` 保留输入、原始 stderr、候选报告、缩减日志及重放。失败不会清理已有记录。该专项不替代六项既有行为/ASan/benchmark/generation/SDK/SQLite 回归。

## 维护增量（2026-10-24）

维护提交 `2b29c6a73c1e61c19daec52f95b172312cd78d73` 已从 Git 导出源码完成本地 Windows 七项验收：81 项主模块、7 项 SDK、48+8 项 SQLite 单测、189 次缩减基准（非计时字段与既有记录一致），以及两档各三策略的 32→2 步专项缩减、两档各五项控制。工具链/脚本/发布边界另通过 11/9/5 项检查。SQLite 使用同一导出源码和显式缓存归档单独运行；这是复用已核验工具链与源码缓存的本机验证。

本轮 Windows/Linux CI 均在工具链归档内容校验阶段退出，接受归档数为零，未进入业务验收；新增 Linux 控制尚无执行结果。计数、报告摘要和失败链接见 [维护验收记录](evidence/maintenance-20261024.json)，安装状态见 [工具链内容锁](TOOLCHAIN-LOCK.md)。历史快照中 ASan 控制数为零的记录保持原义，原内容锁未修改。

## 已验证范围

主分支提交 `7d2716dd345224402437466f41ee9a34564749cf` 的 [Windows 七项 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586714)和 [Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586758)同样全部成功并完成产物核对，见[当前快照](evidence/main-acceptance-20261022.json)。以下保留早期验收及修复过程。

提交 `520cf68738a6693ca348b7af509b4d9bfaf5780f` 已完成 [Windows 七项 CI 39717451261](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39717451261) 和 [Linux CI 39717451254](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39717451254)，全部产物已下载并按 GitHub 归档摘要、指定提交源码和原始报告核对。结构化计数、归档身份和限制见 [统一验收证据](evidence/native-acceptance-20261022.json)。环境准备见 [复现约定](REPRODUCIBILITY.md)。

两个平台分别通过 49 项专项单测；crash/ASan 各三策略均从 32 步缩到 2 步，基线/最终各三次确认、独立同位置重放、不同位置区分和正确实现对照通过。每个平台核对六次缩减、222 次原始候选执行和 18 份独立对照报告。五项不稳定/弱证据/预算/默认关闭控制只覆盖 crash 档。

Windows 完整回归还包括 81 项主模块、7 项 SDK、48+8 项 SQLite 单测、704 个生成场景、189 次旧缩减对照和实际 ASan canary。Linux 独立通过 81+7 单测、212 个项目正确场景、88 个 SDK 正确场景及 23 项 ABI 边界，随后运行故障专项；不宣称 Linux 与七个 Windows suite 完全等价。

首轮 Linux 人工崩溃 fixture 被报告为 Pass，缩减器按预期拒绝，未计为通过。改为运行时读取 volatile 地址后，保留两个实际故障位置，并获得 SIGSEGV/ASan 原始证据；首次失败记录仍保留。早期 Windows 本地实验与外部提供记录只证明各自源码和环境，不替代上述固定提交验收。
