# 能力补齐与验收计划

按完整状态契约、常见 FFI 参数策略、原生错误缩减和 Linux native 四项能力分阶段补齐并验证。历史 rc.1 发布和既有 CI 只证明各自提交及记录范围。

## 当前基线与目标

| 评审要求 | rc.1 实际能力 | 本轮拟交付与验收 |
|---|---|---|
| 完整状态模型及前后置条件 | StateModel.apply 将检查与推进合并，Adapter.execute 自行判断结果 | 独立 initial_state / commands / precondition / next_state / postcondition / invariant 接口；生成、验证、修整共享纯模型；实际工作进程调用目标并检查结果；测试拒绝、错误后状态、清理和缩减重放 |
| 常见 FFI 参数生成与缩减 | 通用 Int / Int64 缩减，其他由各示例自写 | 有界布尔、整数、浮点、Unicode 文本、字节、数组及可选值策略；明确长度、数值/特殊值、编码及资源句柄边界；确定性、下降性及真实 FFI 消费者验证 |
| 原生崩溃和 Sanitizer 自动缩减 | 可分类 Crash / ASan MemoryError，但 fingerprint=None，缩减明确拒绝 | 定义保守错误签名，拒绝只有退出码或 ASan 类别的弱匹配；真实 C 崩溃/ASan 示例、三次基线/最终确认、不同错误拒绝、预算与不稳定控制；不宣称同底层根因或全局最小 |
| Linux native | Windows native 六任务通过 | Linux 独立工具链锁、编译与运行、原生崩溃/ASan 缩减及现有行为回归；保留 CI 与产物证据，不能用配置文件存在代替 Linux 运行成功 |

## 参考框架与实现边界

[Hypothesis 状态测试](https://hypothesis.readthedocs.io/en/latest/stateful.html)提供规则、前置条件、不变量和可复用结果集合；[PropEr proper_statem](https://proper-testing.github.io/apidocs/proper_statem.html)将初态、命令、前置条件、后置条件和状态推进拆开，并在生成和缩减时检查命令合法性。[Hypothesis 参数策略](https://hypothesis.readthedocs.io/en/latest/reference/strategies.html)用于核对参数种类与组合方式。

本项目据此补齐可复用协议和有边界的参数策略，不声称与成熟框架全面等价。并行状态机、任意内存指针生成、任意 SQL、任意外部库的自动建模均不由上述最小交付承诺覆盖。协议与生成/缩减的完整路径须由实例验证，新增接口本身不等于功能完成。

## 分阶段证据

1. 状态契约：本地验收通过。主模块 73 项 native 单测，外部 SDK 7 项单测；新增 C 契约入口 32 个正确场景，三策略均将 32 步人工错误缩至 2 步，独立失败重放及正确实现对照通过；见 [接口说明](STATE-CONTRACTS.md)和[本地快照](evidence/state-contracts-20261021.json)。新提交云端结果须另行记录，不用 rc.1 的旧 CI 代替。
   第一轮云端 39587481441 六项均在安装阶段因滚动归档身份变化被拒绝，未跑业务测试，失败产物全部核对；[新工具链构建器锁](TOOLCHAIN-LOCK.md)保持编译器和 core 身份不变。提交 7778f157 的 [六项 CI 39604001946](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39604001946) 全部通过且产物核对完成：[快照](evidence/github-ci-39604001946.json)记录 80 个关键文件逐任务匹配、73+7 单测、新契约、189 次既有缩减与字节/结构基准一致，以及五项发布边界控制。
2. 参数策略：本地与云端验收通过。新增十类有界域和公共类型顺序，78 项主模块 native 单测、7 项 SDK 单测通过；C 消费者通过 1024 次操作、独立 32/64 位 ABI 的 23 项显式边界、三策略 NUL 缩减及独立重放。见 [接口与限制](ARGUMENT-STRATEGIES.md)及[本地快照](evidence/argument-strategies-20261021.json)。提交 `18cc2953dc8ce6f868f04583ff897715757d378e` 的 [六项 Windows CI 39609263290](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39609263290) 全部成功且产物审计通过：[云端快照](evidence/github-ci-39609263290.json)记录六份归档的 GitHub 摘要及大小核验、逐任务源码和工具链身份匹配、16 份参数输入与本地字节一致、23 项 ABI 边界、三策略 32→1 步 NUL 缩减及独立失败/正确对照重放。189 次既有缩减的结构、输入与结果字节均匹配基准。
3. 原生错误缩减：仍处于本地实验阶段，尚未完成可提交代码的完整回归、云端及 Linux 专项验收，不计为已完成。已提交基线仍保留默认拒绝原生错误自动缩减的行为。
4. Linux：普通 native 构建、单测、正确场景和外部 SDK ABI 已实际验收。[CI 39709396891](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39709396891) 在提交 `7ccd5d67fbecf8d94c3b5477a01f17f34dc3065b` 通过并完成产物核对：78+7 单测、212 个项目正确场景、88 个 SDK 正确场景、1024 次类型参数操作和 23 项 ABI 边界。531 个项目文件和 519 个 SDK 源码输入身份匹配；见 [说明](LINUX-ORDINARY.md)及[证据](evidence/linux-ordinary-20261022.json)。原生错误/ASan 缩减和完整回归仍未完成，不计四项全部达标。

完成四项后更新项目说明，逐条链接实际代码、示例、测试、CI 和限制。原 rc.1 标签及附件保持历史记录，不用于证明后续代码。
