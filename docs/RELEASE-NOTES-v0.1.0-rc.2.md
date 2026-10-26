# MoonFFI Lab v0.1.0-rc.2 发布说明草稿

状态：候选 `20b608d` 的 Windows 七项、Linux 和源码准备 CI 已通过并核对产物，具体附件见 [预发布草案](PRE-RELEASE-PROPOSAL-rc.2.md)。尚未创建标签、GitHub 预发布或 registry 包。项目清单版本仍为 0.1.0，拟议的试用标签为 v0.1.0-rc.2。

MoonFFI Lab 为原生 C/C++ 绑定生成有状态调用序列，在独立进程执行，保存具体输入和原始诊断，并把可重复的失败缩减为可重放案例。

本候选在 rc.1 基础上纳入显式状态契约接口、有界 FFI 参数策略、原生崩溃/ASan 错误缩减和 Linux native 验证。状态模型提供独立初态、命令、前置条件、状态推进、后置条件及不变量；十类参数覆盖 Bool、32/64 位有符号和无符号整数、Float64、文本、字节、数组与可空值。接入者仍需定义适配器、模型及性质。

原生错误缩减须显式启用，执行前后核对同一工作程序的字节身份；候选须保留结果类别和稳定指纹，基线及最终分别重复三次。位置签名不证明同根因，删除邻域最小不证明全局最短或参数最小。

已核对的业务基线为 `f464479107ea46369846a41dde090d25b28426d6`：Windows 七项和 Linux 普通 native/SDK、原生崩溃/ASan 验收通过，八份产物及原始报告已核对，见 [基线快照](evidence/main-toolchain-acceptance-20261024.json)。Windows 有 81+7 主模块/SDK 单测、48+8 SQLite 单测、704 生成场景及 189 次固定缩减；Linux 有 81+7 单测、212 项目及 88 SDK 正确场景。两平台类型参数操作各 1024 次、显式 ABI 边界各 23 项；crash/ASan 各三策略完成 32→2，两个 profile 的五项控制均通过。这些是上述基线的结果；候选自身的同项验收另见 [rc.2 统一证据](evidence/rc2-preparation-20261026.json)。

工具链为内容锁定的官方 moonc/core `0.10.17+d971670cd`，moon/moonrun `0.1.20261023 (3778465)`，async 0.22.5；使用固定版本 URL、归档大小及 SHA-256、三个工具二进制摘要和 core 源码身份验证。Windows 需要 x64、PowerShell 7.5+、MSVC C++ 工作负载和 Windows SDK。Linux 已验证 Ubuntu 24.04 x86_64/GCC；它的覆盖不等同于 Windows 七个 suite。

ASan 仅插桩列明的 C/C++ 单元，原生错误专项仅插桩自有 faults.c；弱证据 ASan 控制为合成的不完整诊断，其余控制执行真实插桩的人工故障。不声明覆盖 SQLite、全部生成 C、运行时或依赖，也没有堆泄漏证明。人工故障不计为未知上游缺陷。

源码包包含受版本控制的工程与既有第三方源码及原许可，不包含 MoonBit 工具包、async 缓存、下载的 SQLite 包或构建产物。完整验收依赖 Git checkout；ZIP 用于审阅和逐文件比对。公开 API 仍属实验性源码接口，未发布 registry SDK。独立使用者复现反馈仍待完成。

候选准备说明见 [rc.2 范围](releases/v0.1.0-rc.2-scope.json)。[复现入口](INDEPENDENT-REPRODUCTION.md)的固定提交与候选附件记录须区分；试用新候选时以候选 source_commit 为准，保留失败日志。
