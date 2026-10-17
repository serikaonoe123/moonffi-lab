# 缩减器验证记录

## MoonBit 可复用整数候选：2026-10-17

公开 `core.shrink_int(Int)` 为适配器生成至多 32 个确定性候选：先 0，再逐步靠近原值，包含向零相邻的整数；非零候选保持符号，绝对值严格下降，不对 Int 最小值取负。独立 SDK 在构造、加法和拒绝加法中使用它，模型与真实工作进程仍负责筛选合法且保持原失败的候选。

61/61 主模块单测、完整 behavior 和 6/6 SDK 单测及接入验收通过。独立标量阈值 oracle 检查 -128..128 起点的 16,769 个起点/阈值组合，另核对完整 32 位边界的唯一性、顺序、数量与收敛。18 组真实进程探针覆盖三策略，分别达到 `200→73`、`-200→-73`、`9→7`、`-9→-7`、`2147483647→2147483646` 和 `-2147483648→-2147483647`；日志同时确认通过的候选被拒绝，接受值保持原失败。

SDK 默认 error 案例仍为 32→2 步，初值 1 保持，拒绝加法量由 200 缩为越界边界 100；归零会掩盖缺陷，低于 100 的正向加法违反拒绝操作前置条件。执行次数由上一版 27 增至 29，三次最终确认、三个真子集、正确实现重放和六次预算边界通过。原始记录 `results/verify-integer-candidates-20261017`、`results/sdk-integer-candidates-20261017`，见 [本地快照](evidence/integer-candidates-20261017.json)。候选枚举完成不保证任意非单调性质的参数最小，也不提供加速结论。

本地固定语料 63 次缩减、214 个真子集及正确实现重放通过，输入/结果哈希、指纹、结构计数和参数进度与上一版本逐条一致，仍为 1,937 次工作进程。记录位于 `results/benchmark-integer-candidates-20261017`。提交 `70fcdca` 的 [Actions run 39040088228](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39040088228) 五项通过，全部产物已下载核对：61+6 单测、18 个新整数进程探针、既有数值/交替缩减/依赖检查、704 个生成场景和 ASan 控制通过；26 个关键源文件逐任务核对。189 次完整缩减的输入/结果哈希和参数进度均与本地对应，214 个真子集及全部正确实现重放通过。

云端执行计数重复一致为 **62/63** 组，具体结果哈希为 63/63 组一致。`resize-alias-2/state` 第三次的第 9 个工作进程在记录任何步骤前 Timeout（3901 ms），delete_block 阶段拒绝该结果；最终仍得到相同反例并通过三次确认与删除检查。该行 proposals 22→23、workers 28→29、repair_removals 18→23、semantic_write_removals 0→2，另 188 行结构计数与本地一致。全量缩减日志中仅此一个非标准候选结果，原始超时原因未确定；保存的候选在本地重放三次均保持原性质失败，不能用此替代云端差异。未重跑覆盖原始记录。完整核查、初次严格核对失败日志及后续明确差异核对均保留于 `results/github-ci-39040088228`，见 [云端快照](evidence/github-ci-39040088228.json)。

## MoonBit 增量依赖与修整：2026-10-17

通用依赖检查和状态修整改用共享增量索引，结构检查与模型接受后才提交依赖变化；删除解释覆盖也改为 ID 索引。保留旧错误优先级、重复/缺失解释诊断、schema 行为及按保留步数计算的 4096 步边界。不透明模型自身仍须遵守拒绝不改状态约定。

58/58 根模块单测、完整 behavior 和 5/5 SDK 单测与接入验收通过。独立数组 oracle 穷举 20,736 个四步轨迹，对照完整校验、修整结果、删除原因及模型调用顺序；另测拒绝释放/定义、后期结构失败、步骤 ID 回滚、诊断优先级、重复解释及边界。纯 MoonBit 探针以保留的旧前缀算法对照两种场景 × 三种长度 × 三次测量，18 项修整结果和删除原因一致。

本地 native/debug 纯修整的中位数（毫秒，三次样本）：

| 场景 | 步数 | 原前缀算法 | 增量算法 |
|---|---:|---:|---:|
| 活句柄定义 | 256 | 20 | 0 |
| 活句柄定义 | 1024 | 352 | 0 |
| 活句柄定义 | 4096 | 5891 | 3 |
| 拒绝释放 | 256 | 8 | 0 |
| 拒绝释放 | 1024 | 128 | 0 |
| 拒绝释放 | 4096 | 2122 | 1 |

4096 步时旧算法分别检查 8,390,656 / 4,198,400 个前缀步骤位置。测量交替执行顺序，仅计 `repair_with_model`，不含结果校验、IO 和序列化；0 表示记录值低于毫秒分辨率，数值不构成整体 FFI 加速或跨机器性能保证，也不设置速度通过阈值。原始记录为 `results/verify-incremental-dependencies-20261017`、`results/sdk-incremental-dependencies-20261017`，见 [本地快照](evidence/incremental-dependencies-20261017.json)。

固定 21 输入 × 三策略的单轮 63 次缩减、214 个真子集及全部正确实现重放通过。与交替缩减版本相比，输入/结果字节、失败指纹、步骤数、候选及执行计数等全部一致，仍为 1,937 次工作进程；不将不同轮次的墙钟波动解释为整体加速。记录在 `results/benchmark-incremental-dependencies-20261017`。

提交 `3b881c6` 的 [Actions run 39037983530](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39037983530) 五项通过，全部产物已下载核对。58+5 单测、20,736 个 oracle、18 次纯修整对照、既有 11 个交替缩减探针及四组数值/预算检查、704 个生成场景、ASan 控制通过。189 次缩减的输入/结果哈希、结构计数与前一云端运行 `39036211299` 逐条相同；参数进度与本地一致，63 组重复一致、214 个真子集及正确实现重放通过。20 个关键源文件逐任务核对，六个纯修整输入哈希与本地相同，18 次语义记录一致。

云端 4096 步纯修整中位数为：活句柄定义 10302→4 ms，拒绝释放 3638→2 ms；仍只计 `repair_with_model`，不据此解释整个 CI 任务耗时。首次下载遇到一次 TLS 握手超时，保留未完成目录后在新目录正常重试成功；最终产物位于 `results/github-ci-39037983530/artifacts-final`，完整核查及 [云端快照](evidence/github-ci-39037983530.json) 保留实际测量和范围。

## MoonBit 交替参数与删除搜索：2026-10-17

runner 接受参数变化后立即丢弃旧候选，从当前轨迹重新扫描；单步删除被接受后也重启参数扫描。原有严格参数下降、纯删除修整、失败指纹和预算契约保留，报告新增可选 `argument_search` 进度对象。历史 JSON 报告缺少此字段时仍可读取。

52/52 根模块单测、完整 behavior 和 5/5 SDK 单测及接入验收通过。新增 11 组 MoonBit 进程探针：三策略均按 `[4,2,1,0]` 接受链式候选；三策略均先缩减失败步骤，再删除 blocker，再缩减更早的 arm 参数；10 次预算分别停在 1/2/2，保留三次最终确认并报告 execution_budget；参数修整删除前序步骤后继续缩减通过；异常参数工作进程保留为一个未决结果，不接受为等价失败。候选重复、反向变化和伪造操作不会成为接受结果。

原始记录在 `results/verify-iterative-arguments-20261017`、`results/sdk-iterative-arguments-20261017`；规则与字段见 [适配器指南](ADAPTERS.md)。完成候选枚举不保证参数最小，SDK 仍是公开 core/runner 的本地源码接入，未发布 registry 包。

21 个固定输入 × 三策略的单轮 63 次缩减、214 个真子集及全部正确实现重放通过，参数扫描全部完成且无未决结果。与上一轮相比，输入字节与最终步骤数全部不变，33 项参数编码进一步缩短，0 项变长，合计减少 1,236 字节；例如生成案例 error-17 的 New 数据 `fc7ee3 → fc`。单轮工作进程从 1,763 增至 1,937（+174），没有加速结论。原始记录为 `results/benchmark-iterative-arguments-20261017`，见 [本地快照](evidence/iterative-arguments-20261017.json)。

提交 `d804195` 的 [Actions run 39036211299](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39036211299) 五项通过，全部产物已下载核对。52+5 单测、11 个交替缩减探针、既有四组数值/预算检查、704 个生成场景与 ASan 控制通过。189 次完整缩减和参数进度与本地对应结果一致，63 组重复一致，214 个真子集与全部正确实现重放通过；11 个探针的汇总字节与本地一致，16 个关键导出源文件逐任务核对。详见 [云端快照](evidence/github-ci-39036211299.json)，不把更充分的参数缩减解释为更快或参数最小。

## MoonBit 等长整数参数缩减：2026-10-17

`core.arguments_simpler` 保留编码长度优先规则，新增等长整数绝对值逐项下降；嵌套容器保持形状，非数值参数保持不变，大整数按数字比较。`Step` 相等判断同样使用精确参数表示，修复相邻大整数被当作相同输入的问题，避免修整检查放过具体数值改写。51/51 根模块单测通过，含独立整数 oracle 的 6,561 组比较，以及超过 Double/Int64 范围、修整拒绝、补偿增长、对象键顺序与指数编码边界。

`cmd/reducer-probe --check-arguments DIR` 用 MoonBit 驱动真实独立工作进程并检查日志。plain/dependency/state 均将 `9` 简化为 `0`，各 12 次执行；同样更小但使失败消失的 `1` 被拒绝，补偿增长、重复和相对已接受结果变大的候选不执行。六次预算仅用于基线和最终确认，保留原输入并报告 execution_budget。PowerShell 验收只增加一条调用。

完整 behavior 验收及独立 SDK 验收通过：SDK 5/5 单测、8+32 正确场景、32→2 步/27 次执行、三个真子集及正确实现重放通过。精度修正后再次完整验收，记录位于 `results/verify-exact-arguments-final-20261017`、`results/sdk-exact-arguments-20261017`。本地复用明确指定的 async 源码，不构成独立主机验收。

21 个固定输入的单轮三策略对照共 63 次缩减、214 个真子集及全部正确实现重放通过；相比旧版本，输入字节全部保持一致，21 项缩减进一步简化参数（例如 RejectWrite 的 `99 → -1`），步数不变，各多执行一个候选。单轮结果不用于宣称重复计时一致或加速；见 [快照](evidence/numeric-arguments-20261017.json)。参数最小性与全局最小性仍不保证；旧版本的执行次数不可直接沿用到本版本。

最终核心提交 `66dcf8f` 的 [Actions run 39025741306](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39025741306) 五项全部通过，产物已下载核对。51+5 单测、四组 MoonBit 数值/预算探针、704 个生成场景、ASan 控制、189 次完整缩减、63 组重复一致、214 个真子集及全部正确实现重放通过；189 行输入/缩减结果字节和结构计数与本地对应结果一致，另核对后续轮次的子集缓存复用。见 [云端快照](evidence/github-ci-39025741306.json)。这证明本轮固定语料复现一致，不表示参数最小或全面加速。

## 工具链内容锁定：2026-10-17

新增固定 SHA-256 的 Windows 工具包/core 归档安装、三个二进制与 core 1,201 源码文件的身份检查。安装仅写新目录，在解包和执行前验证全部归档；不执行上游滚动安装器。来源仍为官方 latest URL，未确认不可变历史地址，故明确保留下载可用性限制和本地归档离线模式。

两次隔离安装通过，最终一次覆盖相对 LockFile 路径和调用进程环境恢复；11 项安装拒绝边界通过。新 MOON_HOME 初次验收因缺少 registry 索引失败，保留 `results/verify-locked-toolchain-20261017/check.log`；随后在该隔离目录执行 `moon update`，索引初始化成功，43/43 主模块单测及完整 behavior、5/5 SDK 单测与集成验收通过。SDK 显式复用了 async 源码，未将本地过程描述为全新下载全部依赖。

证据位于 `results/bootstrap-locked-final-20261017`、`results/toolchain-checks-final-20261017`、`results/verify-locked-toolchain-final-20261017`、`results/sdk-locked-toolchain-20261017`，见 [安装与范围](TOOLCHAIN-LOCK.md) 及 [本地快照](evidence/toolchain-lock-20261017.json)。

`00712a7` 的 [Actions run 39014758043](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39014758043) 五项通过，已核对五次在线内容锁定安装、11 项边界、43 主模块/5 SDK 单测、704 场景、189 次完整缩减及 214 个真子集。六个合成输入仅 environment JSON 键顺序与旧运行不同，影响 54 行输入/结果哈希；21 个输入与 189 个缩减内容、结构计数和指纹一致，见 [云端快照](evidence/github-ci-39014758043.json)。后续已将该 environment 显式 ordered；两个独立进程的九输入字节与彼此及旧基准一致，54 个预算边界结果仍保留预算耗尽状态。见 [序列化修正记录](evidence/benchmark-json-order-20261017.json)。

最终修正提交 `2b7f92c` 的 [Actions run 39015558264](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39015558264) 五项再次通过，全部产物已下载。五次在线锁定安装、11 项边界、43+5 单测、704 场景、189 次完整缩减、63 组重复一致与 214 个真子集通过；189 行输入/结果字节哈希及结构指标均与 `39013008257` 一致，字节差异数为零。诊断中没有归档或二进制文件。见 [最终云端快照](evidence/github-ci-39015558264.json)。

## Eigen 合法算术：2026-10-17

新增 `Add` / `Mul` 及 `eigen-arithmetic-1`，使用元素限制为 ±10^6 的 Int64 模型，核对精确 binary64 整数结果与全部存活矩阵的独立性；纯验证及状态修整检查形状和实际数值。绑定、core/runner 源码未修改。

43/43 根模块单测通过，新增 768 条独立二维算术 oracle、32 条 native 算术 walk、128 个修整子集、有符号非方阵字面期望、越界拒绝/状态不变及 10^12 量级乘积抵消测试。完整 behavior、Buffer 512 + Eigen 192 场景生成验收通过；旧 default/stateful 的 128 个输入哈希保持一致。ASan 新增 16 条算术 walk 和固定算术对照通过，原 canary 和控制继续通过。

运行与范围见 [算术实验](EIGEN-ARITHMETIC.md) 和 [本地快照](evidence/eigen-arithmetic-20261017.json)。这不验证任意浮点稳定性、完整程序 ASan 覆盖或精确资源释放时刻。

提交 `262d6ec5914bd62d4eeed7245ebd6fb043a57703` 的 [Actions run 39013008257](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39013008257) 五项均通过，已下载全部产物。43 根模块单测、5 SDK 单测、704 场景、192 个 Eigen 输入/覆盖与本地一致、128 次旧输入哈希检查、算术 ASan 控制通过。189 次缩减全部完成，63 组重复一致，214 个真子集与全部正确实现重放通过；189 行结构结果与前一提交一致。五个源码归档哈希一致，目标源码与固定输入哈希已核对。见 [云端快照](evidence/github-ci-39013008257.json)。

## SDK 版本五项云端验收：2026-10-17

[Actions run 39004016095](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39004016095) 对提交 `0768240f07807522fc21534297561748a3e2ee0d` 的 behavior、ASan、benchmark、generation、sdk 全部成功。已下载并核对五份产物：37 项根模块单测、5 项 SDK 单测、Buffer 512 + Eigen 128 场景、189 次完整缩减、63 组重复一致结果和 214 个真子集核验通过。SDK 8+32 个正确进程及人工失败 32→2 步/26 次执行与本地一致。见 [云端快照](evidence/github-ci-39004016095.json)。这是合法算术扩展前的提交。

## 外部 SDK 消费者：2026-10-17

新增独立模块 `moonffi-example/counter-lab`，仅依赖公开 core/runner 和 async。`verify-sdk.ps1` 在新目录中只复制这两个引擎包、模块清单与消费者，包图确认没有 fixtures/vendor/引擎命令，然后重新构建。显式离线依赖源码与默认工具缓存恢复两个路径均通过，证据为 `results/sdk-external-offline-20261017` 和 `results/sdk-external-cache-20261017`。

5/5 示例单测通过，覆盖 768 条独立标量 oracle 轨迹、七步轨迹全部 128 个子集的独立修整 oracle，以及 32 条 native walk。另有 8 条正确契约与 32 条正确 walk 的独立进程验收。人工 error 失败 32 → 2 步、26 次执行，稳定指纹保持，三个真子集核验及正确实现重放通过。纯阶段 C 调用审计、6 次预算、非法依赖预检、未知生成器、跨进程确定性及输出目录复用检查通过。

工作区、源码哈希和包图已保存；没有改动 core/runner 实现，也没有将主项目 ASan 范围扩展到计数器 C 文件。指南、范围与证据见 [SDK 接入](SDK.md) 和 [快照](evidence/sdk-20261017.json)。CI 增加 sdk suite，须按对应提交的实际运行确认云端结果。

## Eigen 探索版本的云端复现：2026-10-17

[Actions run 39002767161](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39002767161) 的四项任务全部通过，测试提交为 `46011be5ac260284acf78066756457089e742b25`。已核对四份产物：37/37 单测、Buffer 512 + Eigen 128 场景、16 条 Eigen ASan 轨迹、189 次缩减和 214 个真子集核验通过。128 个 Eigen 具体输入哈希及覆盖观测与本地逐项一致，固定示例重放通过。摘要见 [云端快照](evidence/github-ci-39002767161.json)；这是 SDK 接入示例之前的提交。

## Eigen 真实绑定的状态探索：2026-10-17

新增 `eigen-stateful-1`，按存活矩阵形状选择合法操作；构造、写入、转置及不兼容加法返回错误后检查全部存活矩阵。默认 `eigen-1` 与 vendored 源码保持原样。

37/37 单测和完整 behavior 集成验收通过。新增独立二维数组 oracle 验证 768 条纯轨迹及 32 条 64 步真实 native 轨迹；故意替换适配器句柄的单测确认全对象检查能发现意外共享。完整生成验收通过 Buffer 512 个场景及 Eigen 128 个场景，并验证保存案例哈希/重放、跨生成进程确定性及 CLI 拒绝边界。Eigen 的操作组合（含起点）由 14 扩至 37，矩阵形状由 10 扩至 16；这不是原生代码覆盖率或真实缺陷发现率。

ASan canary、原有正确场景及新增 16 条 Eigen stateful 正确轨迹通过；实际 ASan 源码清单与本阶段实现哈希一致。证据位于 `results/verify-eigen-stateful-20261017`、`results/generation-eigen-stateful-20261017`、`results/asan-eigen-stateful-20261017`，见 [实验报告](EIGEN-GENERATION.md) 与 [快照](evidence/generation-eigen-20261017.json)。原生内存检测范围、数值算法和 finalizer 限制仍保留。

## 重复缩减版本的云端验收：2026-10-17

[Actions run 38998166053](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38998166053) 的四项任务均通过，测试提交为 `166d86df8bbf9468c70e70d526b05183f43d5e4e`。已下载全部产物并核对 benchmark：189 次全部完成，63 组结果三轮一致，214 个真子集核验通过，189 个正确实现重放通过；具体缩减输入、候选数、指纹及停止状态与本地逐条一致。见 [云端快照](evidence/github-ci-38998166053.json)。这是新增 Eigen 生成器之前的提交，不能作为后续改动的云端验收。

## 扩展语料与三轮缩减：2026-10-17

`scripts/benchmark-reduction.ps1` 默认扩展为原九例加十二个 stateful 场景，先冻结/筛选全部输入，再进行三轮轮换顺序的测量。21 个输入均出现性质失败；189 次缩减全部完成搜索和确认，63 个“案例 × 策略”组合的具体结果与结构计数在三轮一致。189 个结果的正确实现重放通过，实际独立核验 214 个真子集，相同输入/指纹的核验复用有来源记录。

seed 20 的 share 场景中 plain 为 6 步、dependency/state 为 4 步；全语料每轮工作进程次数为 555/587/600，无效候选为 333/14/0。这支持候选合法性和特定案例的缩短，不支持 state 全面更快或优于 dependency 的结论。完整协议、逐例中位数/范围及限制见 [缩减实验](REDUCTION-STUDY.md) 与 [快照](evidence/reduction-repeated-20261017.json)。原始记录在 `results/benchmark-repeated-final-20261017`，前一轮同协议结果保留于 `results/benchmark-repeated-20261017`。

预算为 6 的九例边界运行保留全部 27 个预算耗尽结果，没有误报最小性。新增 seed 26 的边界运行保留 12 个筛选输入，其中 nul 为 Pass，余下 11 例的 33 个缩减均保留预算耗尽状态。以上是实验驱动脚本验证；本阶段没有修改 MoonBit 引擎或原生 fixture。

## 状态探索版本的四项云端验收：2026-10-17

[Actions run 38997018833](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38997018833) 对提交 `ee6bb3a034d84500dbf34e33addbc7022a391e9b` 的 behavior、ASan、benchmark、generation 四项全部成功，最后一项于 **11:00:47（Asia/Shanghai）** 完成。四份产物均已下载并核对，源码归档哈希一致，严格工具链检查通过，registry 重新下载 async 0.22.5。

behavior 通过 32/32 单测与完整集成，ASan 额外 16 条 stateful 正确轨迹通过，generation 复现 512 个场景、三个固定案例及与本地相同的计数。该提交的 benchmark 仍是旧版九例单轮（27 次及 111 个真子集），不将它作为本页新增 189 次重复实验的云端验证。托管 runner 为 `win25-vs2026 / 20261007.264.1`、PowerShell 7.6.6；声明范围仍受文档中的安装器与 ASan 限制约束。见 [云端快照](evidence/github-ci-38997018833.json)，完整下载位于 `results/github-ci-38997018833/`。

## 状态探索生成器：2026-10-17

新增 Buffer `--generator stateful`，默认契约场景保持原生成版本。32/32 单测、原有完整集成验收与 ASan profile 验收通过；ASan 额外运行 16 条 64 步 stateful 正确轨迹，全部通过。

独立纯模型核验 768 条轨迹；两个生成器在四种 fixture 模式下各运行 64 个独立进程，共 512 场景。stateful 的 64 个正确场景全部通过，人工 nul/share/error 分别在 59/63/58 个场景被观察到。三个首次失败样本均稳定缩减并在正确实现上重放通过。完整方法、指标定义、证据路径和限制见 [生成实验](GENERATION-STUDY.md)，固定最小化输入见 [示例](../examples/stateful/README.md)。

## 云端与用户手动验收：2026-10-17

[GitHub Actions run 38994542498](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38994542498) 对提交 `4f46b0188fb2f355761e2c1389f5be5af3fca2c9` 的 behavior、ASan、benchmark 三个任务全部成功，最后一个任务于 **10:22:08（Asia/Shanghai）** 完成。下载并核对了三个任务的验收产物，而不只依据绿色状态。

三个任务使用 GitHub 托管的 Windows x64 runner，镜像 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6。安装 MoonBit 后通过严格版本检查；依赖检查日志均记录重新下载 async 0.22.5，`dependency_mode=registry`；三个源码归档哈希一致。behavior 的 28/28 单测与完整集成检查、ASan 三次 canary 和正常对照、benchmark 的 27 次策略对照与 111 个真子集核验全部通过。

这是开发机之外的托管 runner 复现证据。脚本自身的 `independent_environment=false` 字段仍保留原义；独立运行来源由 Actions 任务、runner 信息、安装日志和产物共同补充。不能据此宣称任意 Windows 版本、整个程序的 ASan 覆盖或不可变工具链复现。结构化摘要见 [云端证据快照](evidence/github-ci-38994542498.json)，本地完整下载在 `results/github-ci-38994542498/`。

用户随后手动运行 `verify.ps1` 也通过：`results/verify-0fe000bac8dc42f0b3dfd7aabb7b3470`，完成时间 10:34:55（Asia/Shanghai），已核对 28/28 单测及 verification.json。后文保留早期本地验证与限制记录，其中当时的“云端待验证”状态已由上述运行更新。

## Windows CI 与源码复验：2026-10-17

`92dd00f` 新增 Windows CI 三个独立 suite，以及 `verify-clean.ps1` 和工具版本闸门。使用 `git archive` 从该提交导出的源码，在 `results/clean-ci-offline-20261017` 完成全新项目构建；明确使用本地 async 0.22.5 源码缓存，没有复制项目构建产物。28/28 单测、完整 behavior 集成验收、ASan 三次 canary 与 Buffer/Eigen 正常对照及 Resize 控制、27 次策略对照和 111 个真子集核验全部通过。

补齐环境元数据后，又用同一源提交运行 behavior 验收，验证驱动脚本哈希和环境记录正确。完整本地结果及边界检查摘要保存在 [源码复验快照](evidence/clean-source-20261017.json)。

工具版本漂移测试会失败并保存报告；无效 commit 会保存失败阶段；复用输出目录会在启动构建前拒绝，原报告哈希不变。边界证据保存在 `results/ci-script-checks-20261017` 与 `results/clean-ci-invalid-ref-20261017`。本地先完成了两个 CI 内嵌 PowerShell 块的语法解析，随后完整 YAML 与云端执行也已通过上述 Actions 运行验证。

这次本地离线运行证明的是“从指定提交的新源码目录重新构建”，不是独立机器或全新依赖下载。官方安装脚本的早期本地下载先被套接字权限拒绝，经批准的沙箱外诊断请求又遇到传输 EOF；后续云端运行已成功安装并恢复 registry 依赖。版本安装入口当前为 latest，但实际工具必须与 toolchain.json 完全匹配。配置和操作见 [复现指南](REPRODUCIBILITY.md)。

## 最新状态：2026-10-17 10:00（Asia/Shanghai）

状态感知缩减版本已完成 **28/28 单测**、完整 behavior 集成验收和 ASan stub profile 验收。证据分别保存在 `results/verify-state-final-20261017` 和 `results/asan-state-final-20261017`。后者额外检查通过别名扩容、关闭原句柄、缩到零和重新扩容，结果为 Pass。

新增验证包括纯状态修整、共享别名索引约束、七步轨迹全部 128 个子集的独立模型校验，以及最终删除邻域审计。预算耗尽和错误修整器不能报告 `deletion_minimal=true`。错误修整器可以稳定重放原失败，也可以走完邻域遍历，但未决邻居使其证据不足以判定删除最小性。

9 个案例、27 次策略对照与 state 结果 111 个真子集的独立重放已通过。具体数据、方法和结论限制见 [对照实验](REDUCTION-STUDY.md)；历史验证记录保留如下。

本次上下文接续后重新运行完整验收，28/28 单测及集成检查通过，证据位于 `results/verify-context-continuation-20261017`。带语义修整覆盖断言的三策略对照也已重新通过，证据位于 `results/benchmark-context-continuation-20261017`。ASan 源清单核对仅发现 `core/repair.mbt` 的注释变化；原生及适配器实现与前述 ASan 验收一致。

验证时间：2026-10-16 21:55（Asia/Shanghai）。平台：Windows x64 / MSVC，native debug，behavior profile。
工具链：moon 0.1.20261012、moonc 0.10.15，async 0.22.5。

## 本次执行

```powershell
moon test --target native --deny-warn -j 1
& .\scripts\verify.ps1 -Out results/verify-reducer-retry-20261016
```

单测 **20/20 通过**；完整集成验收退出码 0。
原始证据位于 `results/verify-reducer-retry-20261016/`：
`verification.json` 保存工具链、二进制 SHA-256 和验证事实；各命令日志、案例输入和子进程证据分别保留。
该目录被 Git 忽略，重新运行脚本会产生一份新的本地证据。

## 真实 FFI 场景

Buffer 与 Eigen 各运行 10 个独立进程的正确场景，全部通过。
专用崩溃探针得到 Crash，原始退出码 -1073740286；超时探针得到 Timeout。

| 人工缺陷 | 原始步数 | 缩减后步数 | 缩减执行次数 | 独立核验的真子集 |
|---|---:|---:|---:|---:|
| NUL 字节截断 | 32 | 2 | 19 | 3 |
| 提前关闭共享资源 | 32 | 4 | 23 | 15 |
| 返回错误后破坏状态 | 32 | 3 | 23 | 7 |

三类失败都先连续执行三次确认基线，缩减后再连续执行三次确认相同指纹；独立重放仍失败，改用正确 fixture 重放全部通过。
子集核验通过枚举最终轨迹的全部真子集实现，不调用被测 delete_block 算法。非法依赖子集须被拒绝；合法子集均未保持原失败指纹。
这验证了这些具体案例在保留参数、仅删除步骤的范围内没有更短子集，不表示任意输入或任意参数下全局最短。

## 缩减器边界

独立的 `cmd/reducer-probe` 合成程序通过同一子进程协议运行，以 case-N 启动序号构造可控的稳定性变化，不调用受测原生库。

| 场景 | 实测结果 |
|---|---|
| 稳定合成失败，预算 100 | 32 → 2 步，27 次执行，search_complete，confirmed=true |
| 只有 6 次执行预算 | 正好 6 次，保留 32 步，execution_budget；仅确认失败，不宣称已经缩短 |
| 基线第二次通过 | 2 次后停止，unstable_baseline，confirmed=false |
| 基线第二次换指纹 | 2 次后停止，unstable_baseline，confirmed=false |
| 基线后失败消失 | 98 次，unstable_final，confirmed=false |
| 原始案例通过 | 1 次，unsupported_outcome，confirmed=false |
| 挂起案例，wall-ms=100 | 114 ms，wall_budget，基线 Timeout，confirmed=false |

参数候选改变操作类型或依赖声明时，会在启动工作进程前拒绝；同操作但参数类型不合法时也会拒绝。稳定合成案例记录了这三种无效候选。
逐候选诊断位于各缩减目录的 `reduction-events.jsonl`，已执行候选对应 `case-N` 完整证据；合成验收同时核对日志中的执行记录数与报告执行次数一致。
输出目录复用会返回错误，已有报告哈希保持不变。

## 历史限制和剩余工作

上次原生测试在启动 `buffer.whitebox_test.exe` 时返回“拒绝访问（os error 5）”，当时已停止，没有用其他方式绕过限制。
诊断保留在 `results/verify-reducer-boundaries-20261016/tests.log`；本次按用户要求正常重试后通过，没有修改权限或安全设置。

当时仍需补齐 CI 和独立干净环境复现；2026-10-17 的后续结果见本文开头。behavior 测试通过不代表已完成内存检测。
本节历史版本要求参数的 JSON 编码长度严格减少；后续 MoonBit 核心新增等长整数逐项下降，规则见 [适配器指南](ADAPTERS.md)。搜索完成仍不宣称任意适配器下的全局最小性。

## ASan stub profile：2026-10-16 22:01

`scripts/verify-asan.ps1 -Out results/asan-20261016-second` 已通过。三个独立工作进程的人工 canary 均产生 heap-buffer-overflow 检测报告，被控制器分类为 MemoryError；Buffer 与 Eigen 各十个正常场景通过。对 canary 请求缩减时明确返回 unsupported_outcome，不把内存错误类别当作同根因指纹。

仅 `fixtures/buffer/buffer.c` 和 `vendor/eigen-binding/eigen_shim.cpp`（含其 Eigen 模板实例）插桩。MoonBit 生成的 C、MoonBit runtime、async C stubs 及其他系统/预编译库未插桩。运行时、二进制哈希和具体范围见该目录 verification.json；所有 stderr 保留。ASan 副本使用本地固定版本依赖源码缓存，未复制已有构建产物，也不构成独立干净环境复现。

第一次 ASan 构建因并行 /Zi 编译争用 vc140.pdb 失败，诊断保存在 results/asan-20261016-first。随后改为保留 moon 默认 /Z7 调试信息、链接时启用 /DEBUG，第二次通过。主源码构建配置没有被临时改写。
