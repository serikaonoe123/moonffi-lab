# 四项补齐与复审验收回应

更新：2026-10-22。本次回答反馈中的四项技术建议，并明确实现范围。固定验收提交为 [`7d2716dd345224402437466f41ee9a34564749cf`](https://github.com/serikaonoe123/moonffi-lab/tree/7d2716dd345224402437466f41ee9a34564749cf)，不是旧 rc.1 发布提交。

## 逐项完成情况

| 反馈要求 | 已实现内容 | 代码、实例和验收 |
|---|---|---|
| 完整状态模型及前后置条件接口 | initial_state / commands / precondition / next_state / postcondition / invariant；生成、输入验证、修整共享纯模型，运行时检查实际返回值及全目标观察值，后置条件失败不推进模型 | [ContractModel/ContractAdapter](../core/contracts.mbt)、[纯模型测试](../core/contracts_wbtest.mbt)、[C 计数器契约接入](../examples/adapter-starter/counter/contracts.mbt)；SDK 验证 32 个正确场景、三策略 32→2 步错误缩减、独立重放、正确对照及无效输入前置拒绝 |
| 常见 FFI 参数类型生成及缩减 | 十类有界域，覆盖布尔、32/64 位有/无符号整数、Float64、Unicode 文本、字节、数组及可空值；组合值按语义顺序下降 | [ArgumentStrategy](../core/strategies.mbt)、[域和候选测试](../core/strategies_wbtest.mbt)、[真实 C 消费者](../examples/adapter-starter/counter/parameters.mbt)；1024 次类型参数操作、23 项显式 C ABI 边界、三策略 32→1 步 NUL 文本缩减及独立失败/正确重放 |
| 原生崩溃和 Sanitizer 错误自动缩减 | 显式启用位置/调用帧签名；接受候选须结果和签名相同；基线和最终各三次确认，核对二进制不变；弱证据拒绝 | [签名协议](../runner/native_errors.mbt)、[工作进程记录器](../runner/native_guard.c)、[自有人工 C 故障](../fixtures/native-errors/faults.c)、[专项断言](../cmd/native-errors/main.mbt)；Windows/Linux 各通过两档、三策略 32→2 步缩减，每平台核对 222 次候选执行和 18 份独立对照报告 |
| Linux native 验证 | Linux x86_64 独立内容锁、安装、编译和执行；项目正确场景、外部 SDK ABI 及 crash/ASan 专项；main/PR 自动触发 | [Linux 锁](../toolchain-linux.json)、[普通验收入口](../scripts/verify-linux.py)、[故障入口](../scripts/verify-linux-native-errors.py)、[CI](../.github/workflows/linux-native-errors.yml)；81+7 单测、212 项目及 88 SDK 正确场景、1024 次参数操作、23 项 ABI 边界及上述故障缩减 |

状态契约、参数生成/缩减的接口细节分别见 [STATE-CONTRACTS](STATE-CONTRACTS.md) 和 [ARGUMENT-STRATEGIES](ARGUMENT-STRATEGIES.md)。共同的 Windows 自动验收入口为 [verify-sdk.ps1](../scripts/verify-sdk.ps1)，原生专项的两平台编译/执行步骤分别由 [Windows 脚本](../scripts/verify-native-errors.ps1)和 Linux 脚本保存证据。

## 对照与拟实现范围

已按官方文档整理 [Hypothesis / PropEr 功能对照](FRAMEWORK-COMPARISON.md)。本轮交付四项已经实现的串行、有界原生绑定能力；不是成熟框架的完整替代品。模型仍由接入者定义，本项目不做任意库自动建模；next_state 不提供 PropEr 式任意符号结果求值，不实现并行状态机或线性化检查。

## 同一提交的执行证据

[Windows CI 39720586714](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586714) 的 behavior、asan、benchmark、generation、sdk、sqlite、native-errors 七项全部通过；[Linux CI 39720586758](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586758) 的普通 native/SDK 和自有故障专项全部通过。两者实际执行提交均为 `7d2716dd345224402437466f41ee9a34564749cf`。

对应归档大小/SHA256、工具链及源码身份、原始候选/重放报告已核对，见[机器可读快照](evidence/main-acceptance-20261022.json)。Windows 每个任务 551 个项目输入匹配提交，81 主模块、7 SDK、48+8 SQLite 单测、704 个生成场景及 189 次既有缩减通过；189 次缩减结构及具体结果字节与 CI 39609263290 一致。Linux 核对 551 个项目输入、522 个 SDK 输入，原生专项每档核对 35 个源码输入和 478 个 async 源码输入。

这些数字不跨平台相加冒充不同测试覆盖；CI、接入者实例及声明范围共同构成证据。独立复现按 [INDEPENDENT-REPRODUCTION](INDEPENDENT-REPRODUCTION.md) 选择固定提交。

## 必须保留的限制

- 故障缩减使用自有、标注的人工崩溃和内存错误，不计为未知上游缺陷。相同签名只描述同一未变可执行文件的观测位置，不证明同根因。
- 五项不稳定基线/最终、弱证据、预算及默认关闭控制只在 crash 档执行。ASan 档未完成这五项控制，不宣称相同控制覆盖。
- 专项 ASan 仅插桩 faults.c；Windows 通用 ASan 另覆盖 Buffer C 和 Eigen shim，未插桩全部 MoonBit 生成 C、运行时或依赖。
- Linux 包含实际普通及故障回归，但不宣称与七个 Windows suite 完全等价。deletion_minimal 仅指声明的删除邻域，不保证全局最短或参数最小。
- 独立使用者反馈、新版源码包及正式复审结果不在当前已完成成果中；旧 rc.1 标签和附件不作为新能力的发布证据。

可用于更新报名材料的正文见 [RESUBMISSION-TEXT](RESUBMISSION-TEXT.md)，一页式项目说明见 [HACKATHON-SUBMISSION](HACKATHON-SUBMISSION.md)。历史补齐过程、失败和修复见 [VALIDATION](VALIDATION.md)及 [native-acceptance-20261022](evidence/native-acceptance-20261022.json)。
