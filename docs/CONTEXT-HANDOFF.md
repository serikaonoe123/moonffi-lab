# 接续工作摘要

来源聊天：`codex://threads/01a14797-c8a1-7730-86c8-978e53a1924d`。整理日期：2026-10-17（Asia/Shanghai）。此文件保存接续所需信息；不改变原聊天历史。

## 最新阶段：MoonBit 整数候选生成器

新增公开纯函数 `core.shrink_int(Int) -> Array[Int]`，先零、再逐步靠近原值、含向零邻值；至多 32 个唯一且严格减小绝对值的候选，支持完整 Int 边界。独立 SDK 的 New/Add/RejectAdd 使用该函数，保留原步骤身份与依赖。没有修改 JSON 参数排序门槛；模型和进程仍判断合法性与失败指纹。

本地 61 主模块/6 SDK 单测、完整 behavior/SDK 验收通过，16,769 个阈值组合和完整宽度边界通过，新增 18 个 MoonBit 进程探针通过。SDK 两步结果的初值仍是 1，拒绝加法量从 200 降到 100，执行数 27→29；三子集及正确实现重放通过。原始 `results/verify-integer-candidates-20261017`、`results/sdk-integer-candidates-20261017`，快照 `docs/evidence/integer-candidates-20261017.json`。本地 63 次固定语料、214 真子集和正确实现重放通过，输入/结果字节、结构计数及参数进度与上一版一致，1,937 个工作进程；记录在 `results/benchmark-integer-candidates-20261017`。

实现提交 `70fcdca61b35d7f67f12be9c0dedb8304e46eb64` 已推送，Actions `39040088228` 五项通过并下载全部产物。61+6 单测、新 18 探针及既有检查、704 场景、ASan 控制通过；26 个源码文件逐任务核对。189 次结果字节和参数进度与本地一致，214 真子集、189 正确重放通过。但结构计数重复一致是 62/63：`resize-alias-2/state` 第三次 case-9 的 delete_block 候选在任何记录步骤前 Timeout（3901 ms），被拒绝，workers 28→29、proposals 22→23、repair_removals 18→23、semantic_write_removals 0→2；其余 188 行结构计数一致。最终反例仍相同，63/63 组具体结果哈希一致，最终确认/删除检查通过。超时原因未知，原始记录没有被重跑覆盖；该保存候选本地三次重放保持性质失败。初次严格审计失败日志、修正为显式差异的核查、全部原始日志在 `results/github-ci-39040088228`，摘要 `docs/evidence/github-ci-39040088228.json`。继续优先 MoonBit 核心，不把此次云端计数写成 63/63 重复一致，也不通过隐藏脚本改语言统计。

## 最新阶段：MoonBit 增量依赖修整

`core/dependencies.mbt` 提供私有事务式依赖索引，`validate_dependencies` 和 `repair_with_model` 共用；逐步结构检查之后调用模型，模型接受后才提交依赖变化。拒绝释放/定义及后期结构错误不消耗步骤 ID 或改变引擎的句柄状态。`check_repair` 用 ID 索引核对删除解释，保留重复 ID 等畸形输入的旧诊断。适配器模型仍须自行遵守拒绝不改状态约定；哈希表平均开销下，结构工作不再重扫全部前缀，不含模型、字符串哈希和参数比较成本。

58/58 根模块单测与完整 behavior、5/5 SDK 单测及接入验收通过。新增独立数组 oracle 穷举 20,736 个四步轨迹，并验证调用顺序、删除理由、回滚和边界。`cmd/reducer-probe/dependency_checks.mbt` 保留旧前缀算法，2 场景 × 3 长度 × 3 样本共 18 项等价检查通过；由既有检查入口调用，无 PowerShell 源码改动。4096 步本地纯修整中位数：活句柄定义 5891→3 ms，拒绝释放 2122→1 ms；仅是纯依赖修整测量，不代表整体 FFI 加速，0 ms 不用于计算倍数。

原始记录 `results/verify-incremental-dependencies-20261017`、`results/sdk-incremental-dependencies-20261017`，快照 `docs/evidence/incremental-dependencies-20261017.json`。固定缩减语料与新提交 CI 尚须按实际结果核对，下面的成功记录属于前一轮版本。

固定语料单轮 63 次缩减、214 个真子集与全部正确实现重放通过。与前一交替缩减版本相比，输入/结果字节、指纹、步骤数及结构计数完全一致，仍为 1,937 次工作进程。记录在 `results/benchmark-incremental-dependencies-20261017`；本轮只对纯修整给出计时，不宣称整个 FFI 流程加速。

最终核心提交 `3b881c65c6244693aed10af7400738c762d82c0f` 已推送，Actions `39037983530` 五项通过并下载核对：58+5 单测、18 次纯修整对照、11 个交替缩减探针及四组数值/预算检查、704 场景、ASan 控制、189 次完整缩减、63 组重复一致和 214 个真子集通过。189 行输入/结果字节与结构计数也与前一云端 `39036211299` 逐条一致；参数进度与本地一致。20 个关键源文件逐任务核对，18 次对照语义及六份输入哈希与本地一致。云端 4096 步纯修整中位数：10302→4 ms、3638→2 ms，仅作主机上的纯函数计时。

下载最初有一次 TLS 超时，未完成输出保留在 `results/github-ci-39037983530/artifacts`；重试成功的五份完整产物在 `artifacts-final`。完整核查 `results/github-ci-39037983530/inspection.json`，持久快照 `docs/evidence/github-ci-39037983530.json`。本轮没有增加 PowerShell 源码；后续仍优先 MoonBit 核心与原生验证，不把纯修整加速等同整体 FFI 加速。

## 最新阶段：MoonBit 交替缩减

用户要求继续优先 MoonBit 核心开发。本轮 runner 从一次参数遍历改为参数/单步删除交替：接受任何变化后重新生成候选，丢弃可能失效的步骤索引及旧候选；共用原预算，预留最后三次确认。报告增加 `argument_search: ArgumentSearch?`，记录扫描轮数、当前候选检查数、完成状态及未决数；旧 JSON 可缺失该字段，不表示已完成。只在参数枚举和最终删除检查都完成时返回 search_complete，仍不保证参数最小。

52/52 根模块单测及完整 behavior、5/5 SDK 单测和完整接入通过。新增 `cmd/reducer-probe/iterative_checks.mbt`，由既有 `--check-arguments` 入口调用，没有增加 PowerShell。11 个纯 MoonBit 进程探针覆盖三策略多级缩减、参数/删除相互解锁、10 次预算稳定中间值、修整删除前序步骤及异常候选的未决记录。日志位于 `results/verify-iterative-arguments-20261017`、`results/sdk-iterative-arguments-20261017`。本轮基准与 CI 状态须核对实际新结果，下面的成功记录属于历史提交。

单轮 63 次固定语料缩减、214 个真子集及全部正确实现重放通过，33 项参数编码更短、0 项更长，步骤数和输入哈希不变，合计减少 1,236 参数编码字节；工作进程总数 1,763→1,937，未声称加速。原始记录为 `results/benchmark-iterative-arguments-20261017`，持久快照为 `docs/evidence/iterative-arguments-20261017.json`。必须针对本轮实际提交检查新的五项 CI；前一版 189 条结构计数不能直接沿用。

最终核心提交 `d804195c66e9f38617186f86b5170c1939c4002b` 已推送，Actions `39036211299` 五项全部通过并下载核对：52+5 单测、11 个交替缩减探针、四组既有数值/预算检查、704 个生成场景、ASan 控制、189 次完整缩减、63 组重复一致及 214 个真子集通过。189 项输入/结果哈希、结构计数和 argument_search 进度与本地对应结果一致；后续轮次的子集缓存另行核验；探针汇总字节一致，16 个关键导出源文件逐任务核对。原始证据 `results/github-ci-39036211299`，快照 `docs/evidence/github-ci-39036211299.json`。后续继续优先 MoonBit 核心与原生验证；本轮没有新增 PowerShell 源码。

## 当前优先方向与 MoonBit 参数缩减

用户指出 MoonBit 占比偏少，后续优先增加 MoonBit 核心能力和原生 MoonBit 验证，控制 PowerShell 编排规模。接续前 GitHub 语言 API 返回 MoonBit 114,012 字节、PowerShell 107,522、C 3,907、AMPL 330，MoonBit 约 50.5%；Eigen vendor 已被排除，不应通过隐藏自有脚本调整占比。

新增 `core/arguments.mbt` 的公开纯函数 `arguments_simpler`：保留编码更短规则，等长时允许同形 JSON 中十进制整数绝对值逐项下降，禁止其他分量增长，避免 Double 舍入和 Int64 溢出。runner 使用该函数相对于最新参数检查候选。MoonBit 单测覆盖 6,561 对有符号整数与精度边界；合成探针以 `--check-arguments DIR` 驱动三种策略及预算，并在 MoonBit 内检查日志。PowerShell 仅多一条调用，没有修改语言统计配置。

进一步修复 `Step` 相等判断继承 Json 的 Double 舍入问题，避免只删除修整错误接受相邻大整数改写；对象键顺序仍不影响相等。最终本地 51/51 根模块单测及完整 behavior 通过，5/5 SDK 单测及完整外部接入通过；SDK 缩减仍为两步，因新增一次不保持失败的参数尝试，执行数从 26 变为 27。最终日志在 `results/verify-exact-arguments-final-20261017`、`results/sdk-exact-arguments-20261017`。63 次单轮缩减、214 个真子集通过，其中 21 项进一步简化等长参数，步骤数不变，各增加一次执行。见 VALIDATION 和 `docs/evidence/numeric-arguments-20261017.json`。本轮 CI 状态须按实际提交核对，不能沿用下面旧工具链提交的成功。

最终核心提交 `66dcf8f471ca63005412bd9514845a94e59ff82f` 已推送，Actions `39025741306` 五项全部通过并下载核对：51+5 单测、四组数值探针、704 场景、189 次缩减、63 组重复一致、214 个真子集与全部正确实现重放通过。189 个输入/缩减哈希及结构计数与本地 63 项对应结果一致，后续轮次子集缓存另行核验；13 个关键导出源文件（含新 MoonBit 核心与测试）逐任务核对。原始证据在 `results/github-ci-39025741306`，持久摘要为 `docs/evidence/github-ci-39025741306.json`。GitHub 当前语言 API 为 MoonBit 127,844、PowerShell 107,645、C 3,907、AMPL 330 字节，MoonBit 约 53.3%；本轮 MoonBit 净增约 300 行，PowerShell 仅新增一条调用。

## 最新阶段：工具链内容锁定

新增 `scripts/install-toolchain.ps1`、`toolchain-common.ps1`、`verify-toolchain.ps1`，增强 assert-toolchain；toolchain.json 固定两个官方归档的大小/SHA、三个工具二进制 SHA 与 core 1,201 源码文件的整体 SHA。全部归档匹配后才解包和执行工具，目标/证据必须为新目录，进程环境在 finally 恢复。CI 五项使用新流程，behavior 另跑 11 项拒绝边界；bootstrap 产物仅保留报告/日志，不上传工具包。

来源 URL 仍为 latest；历史候选地址没有取得成功响应，不能声称取得不可变下载地址。当前实现锁定内容、漂移就失败，并支持保留归档后离线重装。Windows 包摘要与官方清单一致；core 包摘要为本轮 HTTPS 实测，源码身份与原有安装一致。见 TOOLCHAIN-LOCK.md 及 `docs/evidence/toolchain-lock-20261017.json`。

本地两次全新目录安装、11 边界通过；新 MOON_HOME 用 moon update 初始化索引后，43 主模块测试/完整 behavior 与 5 SDK 测试/集成通过。最初索引缺失失败日志保留，SDK 依赖明确使用本地 async 源码。对应提交的云端结果见下文。

`00712a7` 已推送，Actions `39014758043` 五项通过，全部产物在 `results/github-ci-39014758043`，快照为 `docs/evidence/github-ci-39014758043.json`。五次在线归档身份一致，11 边界、43+5 单测、704 场景、189 次缩减、63 组重复和 214 个真子集通过。与旧基准比较时有六个合成 JSON 的 environment 键顺序变化，影响 54 行字节哈希；21 输入/189 缩减的具体内容和结构结果相同。后续已将 benchmark 中该对象改为 ordered，两个独立进程的九输入哈希与旧基准一致；后续提交的完整 CI 需按其自身 run 确认。初次差异没有被隐藏为字节一致。

顺序修正提交 `2b7f92c3272e154b2d3c9d488d6f20418259e6e0` 已推送，Actions `39015558264` 五项通过，全部产物在 `results/github-ci-39015558264`，快照为 `docs/evidence/github-ci-39015558264.json`。189 行输入/结果字节哈希、指纹和结构结果与算术基准 `39013008257` 完全一致；五次在线锁定安装、11 边界、43+5 单测、704 场景、63 组重复及 214 个真子集通过。之后仅记录该运行的文档提交不改变已测试脚本和代码。后续可推进更多外部真实库语料或历史归档可用性；当前只锁定归档内容，不锁定下载地址和宿主环境。

## 最新阶段：Eigen 合法算术

新增 Add/Mul、`--generator arithmetic`（`eigen-arithmetic-1`），旧 default/stateful 的 128 个已记录输入哈希不变。Int64 模型把存储元素限制在 ±10^6，点积中间量不超过 4×10^12，因此对 binary64 结果精确比较。Eigen 改用纯数值状态修整，覆盖删除 Set 后算术越界；所有变更核对全部存活矩阵。真实绑定、core/runner 未改动。

本地 43/43 根模块单测、完整 behavior、704 个生成场景、ASan（新增 16 算术 walk 与手写固定对照）通过。新增 768 条纯 oracle、32 条 native walk、128 个独立修整子集，另有非方阵手算和大整数抵消/别名探针。证据、复现与限制见 [算术报告](EIGEN-ARITHMETIC.md)、`docs/evidence/eigen-arithmetic-20261017.json` 及 `examples/eigen-arithmetic/README.md`。

代码提交 `262d6ec5914bd62d4eeed7245ebd6fb043a57703` 已推送，Actions `39013008257` 五项通过。全部产物在 `results/github-ci-39013008257`，核对摘要见 `docs/evidence/github-ci-39013008257.json`：43 根模块 + 5 SDK 单测、704 场景、192 个 Eigen 输入和覆盖与本地一致、128 次旧输入回归、算术 ASan 对照、189 次完整缩减、63 组重复一致及 214 个真子集通过。189 行缩减结构与前一 SDK 提交一致。后续仅记录该 CI 的文档提交不改变已测试代码。

前一 SDK 提交 `0768240` 的 Actions `39004016095` 五项全部通过，已核对全部产物；SDK 与本地一致，189 次缩减全部完成。持久快照为 `docs/evidence/github-ci-39004016095.json`，原始下载在 `results/github-ci-39004016095`。下面各阶段的较小测试数和六操作范围为历史记录。

下一阶段可优先锁定不可变工具链安装包，或增加外部真实库语料。仍不宣称任意浮点稳定性、全局/参数最小性、相同原生根因或原生分配平衡。不要将此前的 CI 成功替代后续提交的验证。

## 目标与约束

项目路径 `D:\moonbit\moonffi-lab`。MoonBit 原生 FFI 测试引擎，支持进程隔离、具体输入保存、重放及缩减；Buffer 为人工 fixture，Eigen 为有来源记录的真实绑定快照。

用户要求继续未完成工作，优先加深并验证依赖与状态感知缩减，保留必要诊断。已授权本地实现、提交及推送到现有私有 GitHub 仓库。遇到权限或安全限制时停止对应操作、解释原因，不尝试绕过。源聊天曾收到安全风险拦截，原始记录保留在该聊天。

远端为私有仓库 `serikaonoe123/moonffi-lab`，接续前最新提交 `ce7fd9c`。公开发布此前被自动审批拒绝，当前没有新增公开授权。

## 已有实现

- `examples/adapter-starter`：独立 `moonffi-example/counter-lab` 模块，通过 `examples/moon.work` 只导入公开 core/runner 与 async；C 计数器、纯状态修整、默认契约/walk 生成器和 CLI 完整接入。
- `scripts/verify-sdk.ps1`：新工作区只保留 core/runner 与消费者，用包图确认接入范围，5 项单测和完整运行/缩减/重放/边界验收。CI 与 verify-clean 新增 sdk suite。
- `fixtures/eigen/generator.mbt`：`eigen-stateful-1`，六操作、最多八个存活矩阵、1–4 行列，按当前形状选合法操作；Eigen CLI 注册 `stateful`，默认保留 `eigen-1`。
- `fixtures/eigen/adapter.mbt`：构造、写入、转置及不兼容 Add 的错误后按 ID 排序核对全部存活矩阵；独立二维数组 oracle 及故意别名探针验证观察能力。
- `core/repair.mbt`：StateModel、纯删除修整、删除原因与子序列完整性检查。
- `fixtures/buffer/adapter.mbt`：别名共享状态、Resize、索引语义校验及修整。原生 fixture 与 FFI 同步支持 Resize。
- `runner/shrink.mbt`：plain/dependency/state 策略，统一调度与预算，最终单步删除审计，confirmed 与 deletion_minimal 分别报告。
- `cmd/reducer-probe`：可控稳定性和错误修整器；`scripts/verify.ps1` 覆盖预算、指纹变化和重放不稳定边界。
- `scripts/benchmark-reduction.ps1`：默认 21 个固定语料、三种策略、三轮轮换顺序，冻结/筛选输入，保留通过和预算终止结果；计时后进行正确实现重放，对不超过六步的 state 结果独立核验全部真子集，相同具体输入/指纹复用核验。

## 已验证事实

2026-10-17 的 28/28 单测、完整集成验收和 ASan stub profile 验收全部通过。原始证据在 `results/verify-state-final-20261017` 和 `results/asan-state-final-20261017`；七步状态模型覆盖 128 个子集。

`results/benchmark-state-separated-20261017`：27 次对照、111 个最终真子集核验通过。plain/dependency/state 无效候选分别为 65/1/0，执行次数为 186/219/219，最终步数相同。状态修整确实删除了失去扩容前提的写入，但当前数据没有证明更快或缩得更短。详见 [实验记录](REDUCTION-STUDY.md)。

## 继续实现：Windows CI 与新源码目录复验

`cd93caa` 已提交状态感知缩减阶段。`92dd00f` 新增 `.github/workflows/windows-native.yml`、`toolchain.json`、`scripts/assert-toolchain.ps1` 和 `scripts/verify-clean.ps1`。CI 拆分 behavior、asan、benchmark，并在失败时上传诊断；版本安装入口使用 latest，严格版本闸门会拒绝漂移。详见 [复现指南](REPRODUCIBILITY.md)。

`results/clean-ci-offline-20261017` 从 92dd00f 导出无构建产物的源码，在新目录完成 28/28 单测、完整集成、ASan 和 27 次对照。依赖明确复用本地 async 源码。这不算独立主机或全新联网依赖验证。

早期本地下载安装器遇到套接字权限拒绝；经批准的诊断请求又遇到传输 EOF。这些历史失败保留。后续已将提交 `4f46b01` 推送到私有 GitHub 仓库，Actions run `38994542498` 的 behavior、ASan、benchmark 三个任务全部成功。托管 runner 使用 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6，重新下载 async 0.22.5。三个产物已下载核对，见 `docs/evidence/github-ci-38994542498.json` 及 VALIDATION。

用户手动运行也已通过，证据目录为 `results/verify-0fe000bac8dc42f0b3dfd7aabb7b3470`；已核对 28/28 单测和完整集成结果。用户此前在 Windows PowerShell 5.1 遇到签名报错；没有修改或绕过执行策略，随后指导使用项目要求的 PowerShell 7。未将签名错误的具体原因归因于版本差异。

## 后续工作

新增阶段已完成 Buffer 状态探索生成器 `buffer-stateful-1`：通过 `--generator stateful` 选择，按当前资源状态选操作，最多 8 个活句柄、256 字节、256 步，不附加固定触发后缀。default 继续使用 `buffer-1`。`runner.cli` 通过可选 generators 映射注册额外纯生成器；replay/shrink 拒绝重新指定生成器。随后 Eigen 也接入相同生成器选择机制，见下文最新阶段。

本地 32/32 单测、完整集成、ASan 及 16 条额外 ASan 随机正确轨迹已通过。`results/generation-stateful-20261017` 记录 512 场景的生成实验：操作组合（含起点）14→50，stateful 正确场景 64/64 通过，人工 nul/share/error 失败 59/63/58；三个首次失败均稳定缩减并修复后通过。768 条轨迹经独立状态 oracle 验证。详情见 GENERATION-STUDY；CI 新增 generation 任务，最新云端结果须按实际提交查询。这里的覆盖是操作与状态特征观测，不是原生代码覆盖或真实缺陷发现率。

状态探索版本 `ee6bb3a` 已推送。[Actions run 38997018833](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38997018833) 的 behavior、ASan、benchmark、generation 四项通过，四份产物已下载核对：32 单测、512 场景及固定案例一致，记录见 `docs/evidence/github-ci-38997018833.json`。其中 benchmark 仍为旧九例单轮，不代表后续新增重复实验的云端通过。

新增重复实验：原九例 + seed 17–20 × nul/share/error 的十二条 64 步 stateful 轨迹，三轮共 189 次缩减，全部完成，63 组结构结果三轮一致。所有正确实现重放通过；实际真子集核验 214 次，缓存覆盖首轮 259 个逻辑子集位置。每轮 plain/dependency/state 的无效候选为 333/14/0，工作进程次数为 555/587/600。share-20 从 plain 六步到 dependency/state 四步；state 没有优于 dependency 的最终步数，没有全面加速结论。见 `results/benchmark-repeated-final-20261017`、REDUCTION-STUDY 及 `docs/evidence/reduction-repeated-20261017.json`。6 次预算边界、seed 26 的 Pass 输入保留边界均已通过。

本次接续已完成持久摘要、实验快照、完整实验文档、语义修整分支覆盖、开发机之外 CI 复现，以及固定本地语料的重复缩减测量。后续可推进真实绑定的探索生成、更多真实库语料、不可变安装包锁定及 SDK/示例整理。参数简化仍受 JSON 编码长度下降限制，不能声称全局最小、任意参数最小或同一原生根因。

上述重复缩减版本已提交并推送为 `166d86d`。[Actions run 38998166053](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38998166053) 四项通过；全部产物已下载，189 条结构结果与本地逐条一致，214 个真子集及 189 个正确实现重放通过。完整下载在 `results/github-ci-38998166053/`，持久快照为 `docs/evidence/github-ci-38998166053.json`。

最新阶段完成 Eigen 状态探索与全对象数值检查：37/37 单测、768 条独立纯 oracle 轨迹、32 条独立 native 数值 oracle 轨迹、完整 behavior 验收、Buffer 512 + Eigen 128 场景生成验收、ASan（含额外 16 条 Eigen stateful）通过。生成验收已集成进既有 CI generation suite；未知生成器/模式、replay 生成器选项、跨进程确定性及固定案例哈希和重放均验证。当前本地证据为 `results/verify-eigen-stateful-20261017`、`results/generation-eigen-stateful-20261017`、`results/asan-eigen-stateful-20261017`。报告与快照见 EIGEN-GENERATION 及 `docs/evidence/generation-eigen-20261017.json`，示例见 `examples/eigen-stateful/README.md`。对应提交的云端状态须查询实际 Actions，不能沿用前一提交的成功。

后续优先项可推进 SDK/接入示例，或扩展真实绑定的合法算术操作与更多外部语料。当前 Eigen 只覆盖受限整数域的六操作，不包含合法加法结果、乘法或求解器稳定性；Drop 只移除引用，不证明 finalizer 时刻和原生分配平衡。导入的绑定和 Eigen 源码未改动。

Eigen 阶段已提交为 `46011be`，Actions `39002767161` 四项通过，下载的 128 个 Eigen 输入哈希和覆盖观测与本地一致，37 单测、额外 16 条 Eigen ASan、189 次缩减及 214 个真子集通过。持久摘要见 `docs/evidence/github-ci-39002767161.json`。

最新阶段完成 SDK 起步模块与指南。`results/sdk-external-offline-20261017` 和 `results/sdk-external-cache-20261017` 两条路径均通过：5 单测，768 条独立标量 oracle，128 个修整子集，32 条 native 单测 walk，8 + 32 个正确独立进程；人工失败 32→2 步/26 次执行，原缺陷重放与正确实现重放按预期，三个真子集及预算/预检/输出复用边界通过。源码哈希与当前例子一致，core/runner 未修改。见 SDK.md、示例 README 及 `docs/evidence/sdk-20261017.json`。新增提交的云端结果仍须按自身 run 核对。

示例使用 MoonBit `moon.work` 做源码接入，没有发布 registry SDK 包；async fn main 需要显式导入 async。工作区下直接不带路径执行 moon test 会测试所有成员，示例单测使用 `moon test ... counter` 限定包。SDK C 计数器仅 behavior 验收，不在旧 ASan profile 范围内。后续可扩展真实绑定的合法算术操作、更多外部语料或锁定不可变安装包。

Git 直连 GitHub 的 HTTPS 曾连接失败；本机已有启用的系统代理 `127.0.0.1:7892`。使用单条命令 `git -c http.proxy=http://127.0.0.1:7892 push origin main` 可以正常推送，没有改全局代理或安全设置。普通传输错误与权限/安全拒绝须区分。

接续后的复验已完成：`results/verify-context-continuation-20261017` 的 28/28 单测和完整集成验收通过；`results/benchmark-context-continuation-20261017` 的 27 次对照和 111 个真子集核验通过，语义修整覆盖断言生效。候选数、步数及执行次数等结构指标与上一轮逐条一致。详见实验快照的 continuation 字段。

构建与验证从 README 的命令继续。输出目录必须是新目录；`results/` 被 Git 忽略。不要因为汇总文件齐全就删除原始失败、候选或重放日志。
