# 接续工作摘要

来源聊天：`codex://threads/01a14797-c8a1-7730-86c8-978e53a1924d`。整理日期：2026-10-21（Asia/Shanghai）。此文件保存接续所需信息；不改变原聊天历史。

## 最新阶段：有界参数策略完成本地验收，2026-10-21

第一阶段及新锁的提交 7778f15757f83383f25e2cf42318b51de85be8f0 已通过 [CI 39604001946](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39604001946) 六项及全部产物核对。80 个关键文件逐任务匹配 Git 导出，73+7 单测、状态契约 32 正确场景/三策略、189 次原有缩减的字节与结构、63 组重复、214 真子集、SQLite 96 场景和 49 上游 blob、11 安装拒绝与五项发布准备控制通过。原始 results/github-ci-39604001946，见 [快照](evidence/github-ci-39604001946.json)。本地审计两次先后因扩展 Windows 路径和未上传的嵌套 failure.json 假设失败；保留 first/second-audit-failure 与 partial-inspection，最终按确切绝对二进制路径、已上传拒绝日志/控制汇总验证，全部断言后才写最终 inspection。

第二阶段新增 ArgumentStrategy：有界 bool、Int32/Int64、UInt32/UInt64、位保真 Float64、Unicode 标量文本、字节、数组及可空联合；最大四层/4096 值、128 个域内去重下降候选。Float64/text/bytes 用明确标签；可空联合不区分多层 Option 构造器。ffi_arguments_simpler 对类型语义作分量比较，避免 true/false 拼写长度回环，数值旧顺序保留。decode_trace 保留数字原文，拒绝宽整数前先被小数/Double 舍入；非规范整数旧输入可能因此被拒绝，已记录限制。见 [策略说明](ARGUMENT-STRATEGIES.md)。

新增 cmd/parameters 真实 C 消费者，不触及私有 fixture，分别走 int32_t/uint32_t/int64_t/uint64_t、Double 位、UTF-8/字节拷贝、数组加权和、NULL/本地标量指针包装。78 主模块 native 单测、7 SDK 单测，16 场景/1024 次 C 操作、23 显式极值/浮点/Unicode/NUL/空数组边界、三策略 32→1 步且仅保留 NUL、独立失败重放及正确实现对照通过。[快照](evidence/argument-strategies-20261021.json)。最终完整 SDK 在 results/argument-strategies-sdk-distinct-abi-20261021，驱动运行前后不变。早期 32 位域曾走 64 位回显，最终改独立 ABI 并完整复验；首次语法/纯测试/末尾测试标签错误日志均保留。

原 behavior 回归在 results/argument-strategies-20261021/behavior 通过（包含 78 单测及全部旧控制）。额外 Unicode 拒绝与数字原文断言随后通过最新 native 单测 native-tests-final-fixed.log；先前策略/测试源码保留 first-behavior-source，最终 SDK 与根当前源码逐文件核对。阶段二云端结果待另行记录。下一步仍为原生崩溃/ASan 自动缩减，再做 Linux native；已有未纳入产品的 C 证据原型仅在 results/native_guard-prototype-20261021.c，没有执行或声称通过。用户已授权四项分阶段推进和现有公开源码推送，遇安全拒绝立即报告停止，不自动发消息、重报或发布新版本。

## 最新阶段：首次申报被驳回，按四项要求补齐，2026-10-21

第一阶段实现提交 0eae789 已通过正式审批同步到公开仓库，tree/commit SHA 完全一致，force=false。[CI 39587481441](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39587481441) 六项均在 verify-archives 拒绝漂移的官方 Windows 包，accepted_archives=[]，业务测试未运行；六份 ZIP 和失败文件已下载按 GitHub 大小/SHA 核对，见 [失败快照](evidence/github-ci-39587481441-failed-bootstrap.json)。没有绕过拒绝或重新使用不符归档。

从官方重新取得并核验 Windows/Linux 归档及二进制清单，在 results/toolchain-review-20261021 独立安装 Windows 新候选。moon / moonrun 变为 0.1.20261020 (2284bd2)，moonc 仍 v0.10.16+b1a0e846e；编译器二进制和 1211 文件 core 源码树完全一致，core ZIP 仅归档摘要不同。根 toolchain.json 更新新归档及构建器身份，安装器/校验逻辑未放宽。新安装、11 项拒绝边界、73 主模块 native 单测和完整 SDK（7 单测、新契约 32 正确场景及三策略缩减/重放）通过，见 [刷新快照](evidence/toolchain-refresh-20261021.json)。首次根检查缺少 registry 索引，正常 moon update 后恢复，首次日志保留。Linux 包只下载检查了三份二进制 SHA，尚未在 Linux 运行，不冒称完成第四项。

用户提供组委会驳回：要求完整状态模型/前后置条件、常见 FFI 参数生成缩减、原生崩溃/Sanitizer 自动缩减及 Linux native 验证，2026-10-31 前可改表复审。用户明确选择“按四项要求分阶段补齐并验证，再准备重报”。先前关于可申报的判断过于乐观；不能用 rc.1 或旧 CI 声称已达审核标准。对照官方 Hypothesis/PropEr 文档，新增 [补齐计划](REVIEW-RESPONSE.md)，不发消息或自动重报。

第一阶段新增 core.ContractModel / ContractTarget / ContractAdapter：显式初态、命令、前置条件、预期状态转换、后置条件、不变量；共享模型用于生成、验证和只删修整。原生目标仅在 worker 执行/观察/关闭，teardown 保证检查与清理，原 Adapter 不改。JSON 状态回调要求纯性，有限命令枚举不宣称均匀分布或支持任意符号表达式。C 计数器新增 cmd/contracts 入口及 SDK 验收，复用原 C fixture，人工越界错误由后置条件捕获。

本地 73 主模块 native 单测、7 SDK 单测、32 新正确场景、三策略 32→2 步、三次基线/最终确认、独立错误重放及正确实现对照、无效依赖预拒绝与跨进程生成一致通过；[快照](evidence/state-contracts-20261021.json)。原始记录 results/review-contract-20261021、results/review-contract-sdk-accepted-20261021。最初语法/弃用检查及消费者构造失败分别保留，最终 SDK 驱动运行前后摘要一致。只为进程使用既有 MSVC 环境和工作区临时目录，未改安全设置。

准备发布的旧冻结检查继续验证固定 23893d5；新开发 HEAD 必须被旧范围拒绝，新 CI 添加此负向控制，不把新代码套入旧发布基线。尚未发布新版本、改旧标签或重报。参数策略、原生错误缩减和 Linux 待继续实现，当前第一阶段云端结果另行记录。

## 历史阶段：rc.1 已发布并回下载核验，2026-10-20

用户对具体草案明确回复“发布吧”，已创建 [v0.1.0-rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1)，固定指向已验证提交 23893d5bb3a231a21df10db506d8da821a7e984d。发布前核对公开仓库、远端目标、同名标签/Release 不存在、正文及四附件摘要；正式审批后创建公开预发布，不标记 Latest。标签、正文与四附件回下载大小/SHA 全部一致，见 [快照](evidence/prerelease-v0.1.0-rc.1-20261020.json)；原始证据在 results/publish-prerelease-20261020。未发布 registry 包、稳定版或第三方工具包，未联系上游。原 candidate.json、publication-proposal.json 与旧证据保留准备时状态，不改写历史；以下阶段的“尚未发布/尚待授权”仅指当时。

十月黑客松官方页面当前要求参赛信息、公开仓库和一页说明，并列出主要语言、公开记录、示例测试、实质工作、许可和 AI 可解释等验收要求。项目材料具备申报基础，但预发布不等于通过赛事审核；参赛者身份、队伍、报名/入群状态未知，飞书正式章程/表单本次未能读取。新增 [项目说明草稿](HACKATHON-SUBMISSION.md)，明确 MoonFFI Lab 的引擎贡献与既有 Eigen 材料区别，未自动报名或发送消息。独立使用者反馈仍待完成。只更新发布/申报文档与证据，不改运行代码、锁或 CI；没有必要重跑原生测试。任何安全拒绝仍立即报告并停止对应动作。

## 历史阶段：社区反馈入口与明确预发布草案，2026-10-20

从干净的 710b45f 开始，只新增贡献说明、GitHub 复现反馈表单及预发布草案，不改运行代码、验证脚本、工具链锁或现有 CI workflow。表单采用 JSON（YAML 子集），本地核对六个字段、参与情况不预选、无自动 assignees/labels，未提交 Issue。README 和独立复现入口已链接贡献说明及表单。GitHub 表单语法来自官方文档；本地字段校验不冒称真实外部用户反馈或服务端实际提交验收。

只读查询当前公开 serikaonoe123/moonffi-lab 的 Issues 已启用，标签与 Release 列表当时为空，原记录 results/community-readiness-20261020；未改仓库设置。准备 docs/PRE-RELEASE-PROPOSAL.md 与 docs/evidence/community-readiness-20261020.json：拟议公开 GitHub 预发布 v0.1.0-rc.1，目标固定为已通过六项 CI 的 23893d5bb3a231a21df10db506d8da821a7e984d，不标记 Latest。源码保持既有 498 文件候选，不从当前未提交目录重打包。拟上传 source.zip、candidate.json、source-manifest.json、SHA256SUMS 四附件，正文和每份摘要均已备好。

全部本地审阅文件在 results/community-readiness-20261020/prerelease-proposal：publication-proposal.json、release-body.md、assets/；source.zip SHA 仍为 EEA70786A734B8CDBD25FFD096AB607A9D2B282C43CDA78C8C3027F69D656E38。保留已有 Eigen/历史 RNG 源码及许可，不含编译器工具包、缓存或构建产物。candidate.json 是准备时的不可变快照，publish_ready=false 和独立反馈 pending 未改写；预发布是为收集反馈，不是假称完成正式用户验收。

现有授权仅明确覆盖源码/验证记录推送，尚无创建公开 Release、标签及四附件上传的明确批准；本轮不会执行这些动作，后续须让用户审阅这份具体草案再决定。没有 registry 发布、上游消息或第三方工具包上传。若用户批准，发布前必须重查标签不存在、目标提交及四附件摘要，任何权限/安全拒绝报告后停止，不覆盖同名标签或绕过限制。用户一旦针对这份具体草案给出批准，授权持续有效，不重复询问；后续简短答复须结合待决问题的上下文判断。

## 最新阶段：v0.1 源码候选准备完成，六项 CI 通过，2026-10-20

从 ea652c7 开始，不改 core/runner/fixture、既有验证脚本或工具链锁。候选代码提交 `23893d5bb3a231a21df10db506d8da821a7e984d` 已推送，[Actions 39361478378](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39361478378) 六项全部通过且产物核对完成；见 [发布准备](RELEASE-PLAN.md)、[本地准备快照](evidence/release-preparation-20261020.json)和[新云端快照](evidence/github-ci-39361478378.json)。75 个关键文件逐任务匹配提交归档，全部 498 份候选源文件的 Git blob/字节/SHA 与本地清单一致。既有 69+6+48+8 单测、704+96 场景、128 历史输入、189 次缩减、63 组重复与 214 真子集通过；输入/结果字节和结构计数与旧基准一致。新下载助手丢弃异步 CopyTo 返回值，本轮原始下载记录恰为六份具名记录，大小/SHA 已重新核对。后续只做文档收尾，运行代码保持该提交。

新增范围清单、发布说明草稿、独立使用者复现入口及反馈模板。README/复现指南纳入六项任务，明确 moonc 0.10.16 为实际自报，非文档 tag 或最新正式发行声明。源码 ZIP 用于审阅，完整 verify-clean 仍需 Git checkout；当前不提供解压后无 Git 的完整验收模式。复现入口已指向本轮确切候选代码 SHA，源码/许可来源保留。

prepare-release 只本地导出已提交源码，逐文件核对 Git blob/SHA，保留来源和许可，拒绝运行代码/既有验证脚本相对旧 CI 基线漂移；不下载/构建/打标签/发布。candidate.json 始终 prepared-not-published、publish_ready=false，显式区分已记录旧运行基线 1f065527 和候选自己的 CI。verify-release-preparation 四项控制（两份完整 ZIP/清单一致、已有输出、缺失提交、缺失冻结清单）本地和云端通过。sdk 任务因基线祖先比较 fetch-depth=0，其余仍浅克隆，persist-credentials=false 不变；CI 只上传准备清单/日志，不上传源码 ZIP/工具包。

预提交归档曾受 Windows Git 换行转换影响而与 .gitattributes Git blob 不符；失败保留 results/release-precommit-archive-20261020。仅本次归档命令指定 core.autocrlf=false/core.eol=lf 后，旧提交全部 491 文件匹配，并因未提交清单按预期拒绝，记录 results/release-precommit-exact-20261020。先前未推送的本地 2f27580 因补齐 sdk 历史配置修订为 23893d5，未改远端历史。最终完整本地控制在 results/release-preparation-final-20261020，a/source.zip 约 1.55 MB、498 文件，SHA 为 EEA70786A734B8CDBD25FFD096AB607A9D2B282C43CDA78C8C3027F69D656E38；a/candidate.json 与 a/source-manifest.json 可供审阅。托管 runner 的清单逐文件匹配，不声称不同 Git 版本产生相同 ZIP 压缩字节。云端原始记录在 results/github-ci-39361478378，审计脚本 results/inspect-release-ci-20261020.ps1。

尚待独立使用者按文档提供真实反馈，以及用户明确授权具体发布目标/附件。目前未发布 registry 包或 GitHub Release、未打发布 tag、未联系上游，候选不冒充正式发布。公开自写源码/文档推送授权继续有效；拒绝安全审查时须立即报告并停止对应动作，不修改安全设置或绕过限制。当前没有待运行的原生测试。

## 最新阶段：真实社区 SQLite 接入，六项 CI 通过，2026-10-19

最终运行代码提交 `1f065527f9fa584dc52a79399f0a36e40ed3c321` 已推送，[Actions 39248905440](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440) 六项全部通过并核对全部产物，见 [接入记录](SQLITE-INTEGRATION.md)、[本地快照](evidence/sqlite-external-20261019.json)及[云端快照](evidence/github-ci-39248905440.json)。六次官方锁定工具链安装、68 个关键文件逐任务匹配 Git 导出，驱动按 LF/CRLF 校验；既有 69+6 单测、704 生成场景、128 历史输入、189 次缩减通过，全部输入/结果字节和结构计数与旧基准一致，63 组重复、214 真子集及正确实现重放通过。此后只做文档收尾，不改变已测试脚本。

新增 examples/sqlite-lab、verify-sqlite 和 verify-script-controls，仅用 core/runner，固定社区 sqlite3 提交 1405639063c52b1474b2622d4c5b5e36110aa74c、ZIP 大小/SHA 及 49 个 Git blob；上游源码保持原样，不执行上游脚本。tree 字段笔误已按官方 Git commit API 更正为 b948e0cfbe8e909efba2fe34a11ccf628e6708b2。async 声明 0.22.4，显式 workspace 源码成员选 0.22.5，不改上游清单。48+8 单测、1,024 修整子集、256 纯 walk、32 native 单测 walk、32+64 隔离场景、两份重放及边界通过；96 个输入与本地逐字节一致，49 blob 构建前后一致。没有发现未知缺陷或注入上游 mutant，不宣称 SQLite ASan/堆泄漏/并发覆盖，也不将托管 runner 等同独立维护者使用验收。

本地首次 47/48 上游测试：持久化单测依赖模块目录的 _build，仅创建普通空测试目录后原测试通过。verify-clean/verify-sqlite 修复缺失环境变量被恢复为空字符串，NullString 保留真正缺失；旧 absent 控制实际准备为空值，结论已更正且旧日志保留。九项存在/缺失/空值、归档大小/哈希及已有输出控制本地和最终 CI 均通过；成功路径另由 results/sqlite-clean-sdk-absent-success-20261019 验证 SDK 后 TEMP/TMP 仍真正缺失。

首两轮 CI 39247453969/39247655451：SQLite 断言通过，预期拒绝的 native 非零状态泄漏到外层而任务失败，九项控制未执行。be3ec51 修复仅在全部断言通过后归零。第三轮 39248320859 主验收成功，控制默认查 checkout 根缓存而失败；最终显式传入 results/ci/workspace/.mooncakes，无根缓存新目录回归和最终 CI 均通过。三次失败快照与日志均保留；首次新目录漏复制清单的准备失败也未覆盖。记录目录：results/sqlite-external-accepted-20261019、results/sqlite-ci-exit-accepted-20261019、results/script-controls-fresh-checkout-fixed-20261019、results/github-ci-39248905440。下载及审计均通过正式审批，没有越过安全拒绝、修改 ACL/完整性/TLS 或上传第三方工具包。

下一阶段是独立使用者按文档复现，以及 v0.1 范围冻结和发布准备。当前没有发布 registry 包或 Release，没有向上游发送消息；这些动作仍需对应授权。公开自写源码/文档推送授权继续有效，禁止绕过安全审查。

文档收尾复核发现下载器在 records 中混入空返回对象，实际六份具名产物均已通过校验；首次摘要断言失败后仍提交文档属于流程失误。后续仅在公开汇总中筛除无字段对象，原始下载记录保持不变，并重新逐 ZIP 对照 GitHub 大小/SHA：最终六份与三次失败各一份均匹配，全部文档字段/链接检查通过。原始 records 个数不等于产物数，按 artifact_id/name/digest 识别具名条目；本次没有改变运行代码或 CI 结论。

## 最新阶段：本机 MSVC D8050 恢复，2026-10-19

工作区内 moon 与自写诊断程序均带 Low 完整性标签，诊断令牌 RID=4096；系统临时目录没有 Low 标签。最小同命令在原 TEMP/TMP 下 D8050/退出 2，仅把临时目录设到工作区后退出 0，令牌仍为 Low。没有修改 ACL/标签/安全策略，没有移动已锁定程序或改锁。新增 `scripts/verify-clean.ps1 -WorkspaceTemp`，使用项目内新 `<Out>/temp`，finally 恢复调用进程 TEMP/TMP 和目录；成功及失败报告记录临时路径。通过 69 主模块单测、完整 behavior（21 个 Int64 探针、1701 缩减/预算执行及 36 独立对照）、6 SDK 单测和完整独立消费者验收，以及当时五项环境恢复/拒绝控制（其中 absent 实为空值，真正缺失的修复见最新阶段）。见 [本机记录](LOCAL-WINDOWS-TEMP.md)和[快照](evidence/local-msvc-temp-20261019.json)。本轮未重跑本机 ASan/benchmark/generation，不扩展结论。

最终新选项入口记录在 `results/local-msvc-workspace-final-20261019`，驱动运行前后哈希一致；选项独立 SDK 与恢复控制在 `results/local-msvc-temp-option-sdk-20261019` 和 `results/local-msvc-temp-controls-20261019`。验证导出源码为 c53a019，本轮驱动变更单独记录 SHA。首次根目录验证扫描了 results 中缺文件的历史部分源码快照，失败记录在 `results/local-msvc-recovery-20261019`，未删除快照。优先使用 `verify-clean -WorkspaceTemp` 导出指定提交，避免诊断目录被视为产品包。首轮外层手动设置 TEMP 的通过记录在 `results/local-msvc-clean-recovery-20261019`；该轮驱动文件中途被编辑，结束时读取的 driver_sha256 不能单独证明实际加载版本，最终另跑固定驱动验证，没有覆盖初次记录。

修复提交 `b43aad65254a2254118cbe736e1c327793109d69` 已通过正式审批以相同 Git tree/commit SHA、预期父提交及 `force=false` 同步到现有公开仓库；[Actions 39239977335](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39239977335) 五项通过且全部产物核对完成。53 个关键文件逐任务匹配 Git 导出，五次驱动匹配 LF/CRLF 内容身份，默认 TEMP/TMP 行为不变；云端未开启新选项，新选项的证明来自上述本地验证。69+6 单测、11 项安装边界、704 场景、128 份历史输入通过，189 次缩减的输入/结果字节、结构计数与旧基准逐项一致，63/63 重复、214 真子集及全部正确实现重放通过。见 [新云端快照](evidence/github-ci-39239977335.json)。后续仅更新本轮验收文档，不改变已测试脚本。

本轮下载前三份 CLI 产物成功；剩余下载超过两分钟未报告完成后，仅取消已核实的本轮 gh 进程，未确定是网络还是解包缓慢，原目录保留。标准 HTTPS 客户端经正式审批只向官方 API 使用既有登录凭据，产物主机请求不携带凭据，保留 TLS 校验；两份 ZIP 大小和摘要与 GitHub 元数据完全一致。首次解包因 CLI 留下的已有目标而主动停止，随后仅在新的 `verified-artifacts` 解包。全部核对使用该新目录，三个完整 CLI 产物只复制过去；没有删除/覆盖旧目录、改权限或解除安全限制。传输与解包记录在 `results/github-ci-39239977335`，没有向公开证据写入凭据或签名下载 URL。

## 前一阶段：官方工具链 0.10.16 升级与随机流兼容，2026-10-19

最终实现 `410612240ac6be025148cc6505d3155cd726d912` 已同步 GitHub；[Actions 39233803279](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39233803279) 五项全部成功并下载核对，CI 旧锁阻塞已解决。五次官方在线安装、11 项拒绝边界、69+6 单测、21 个 Int64 探针、704 生成场景、128 份历史 Eigen 输入、189 次缩减、63/63 重复一致、214 真子集及正确实现重放通过。44 个关键源文件逐任务对照 Git 归档，所有 189 行输入/结果字节及结构计数与旧 Int64 本地基准一致；见 [最终快照](evidence/github-ci-39233803279.json)。后续收尾仅为文档，不改变已验收代码。

普通 Git 推送三次连接失败；官方 GitHub API 可用且父提交与写权限已确认。通过正式审批以 Git 数据 API 同步了完全相同的本地 tree 和 commit SHA，父提交前后核对，分支更新 `force=false`，未修改网络、安全或身份设置。本轮 benchmark 产物在 CLI 下 TLS 握手超时，改经正式审批使用系统 HTTPS 客户端请求原 GitHub 签发的同一地址；保持 TLS 校验，ZIP 摘要与 GitHub artifact digest 相同，检查 ZIP 路径后才解包诊断。该升级阶段结束时本机 native D8050 未解决，后续恢复见本文件首节；原安装未覆盖，全局 PATH 未修改。

首轮候选提交 `3b7e0d4` 已推送，CI `39225026215` 四项成功、generation 失败；五项新锁安装通过，云端 68+6 单测通过。失败是新 core 修改 SplitMix 后改变历史 Eigen seed 数据（17 的初始矩阵 `[6,-4,-1]` → `[-9,4,7]`），并使 benchmark 语料/真子集计数变化，详见 [失败快照](evidence/github-ci-39225026215.json)。随后以 `fixtures/random` 固定原 core 0.10.15 流，保留 Apache LICENSE/NOTICE、所有历史 SHA 检查及原 Buffer/Eigen generator_version；独立 SDK walk 使用新 RNG，版本提高为 `counter-walk-2`。新纯随机流锚点 wasm-gc 单测与 native 静态检查通过，完整云端 69+6 单测通过。PATH 双 moon 发现修复的默认身份校验通过。本机全新源码与核心运行时仍有 D8050，不能写成本地 native 通过。

用户最新明确表示“也不用保持旧锁，有新的可以使用新的”，取代保留旧锁的决定；可从官方评估新版本，无须公开镜像旧包或联系上游。公开代码推送及必要正式审批授权继续有效，禁止绕过权限/安全审查。

官方新包对应 moon 0.1.20261016 (1af328f)、moonc v0.10.16+b1a0e846e；工具包及三个关键二进制先与官方 SHA-256 核对，core 版本一致，源码 1,211 文件。原安装保留，新安装及全部记录位于 `results/toolchain-upgrade-20261019`。候选锁更新归档、二进制、版本和 core 源码身份；安装器/校验规则不放宽。11 项安装边界检查通过，源码漂移控制的旧文件数常量改为读取当前锁。

隔离安装、core bundle、静态检查通过。首次静态检查缺少新安装的 registry 索引，`moon update` 后通过，日志分别保留。native 单测在 async C 编译阶段因 MSVC D8050 失败，本机尚无新版本 native 测试断言通过；本机初始化 Developer PowerShell、明确同一 cl.exe、官方 C 后端兼容模式仍失败，未改变产品测试要求。最小 C 的路径/工作目录/窗口模式对照以及直接 async 编译成功，底层差异尚未确定，不归因为安全审查拒绝。独立云端验证见本节首段，旧版单测未代替本次验收。新构建器自动生成的 `pkg.generated.mbti` 加入忽略规则。

## 历史阶段：64 位整数候选，2026-10-19

2026-10-19 后续：用户同意继续评估保留原锁的 CI 恢复方案。两份原始归档重新核对仍匹配；公开仓库当前 ADMIN、发布列表为空。只读检查 ZIP 目录与许可文本后，完整 Windows 工具包的再分发依据仍未建立，不能把当前 Wasm 编译器源码库许可直接套用到整包。已准备 [恢复方案与未发送的上游询问草稿](TOOLCHAIN-CI-RECOVERY.md)及[评估快照](evidence/toolchain-ci-recovery-assessment-20261019.json)。仅改文档，未上传归档、创建发布、改设置、改锁/安装脚本/workflow 或联系上游。文档首次提交审批因自动审查超时未完成，命令未执行，已向用户报告；审查返回明确允许通过同一正式入口重试一次，不据超时推断操作不安全，也不绕过权限。后续需先取得上游固定来源或适用许可依据，再针对具体公开附件清单请求用户授权，不自动实施镜像。

从干净的 `252e269` 开始，新增公开纯函数 `core.shrink_int64(Int64) -> Array[Int64]`：先零，再逐步靠近原值，最多 64 个唯一且绝对值严格下降的候选，包含向零邻值。支持 Int64 最小值，不对它取绝对值或取负。原 `shrink_int`、JSON 参数排序、runner 和原生 fixture 没有改变。当前工具链的标准 Int64 ToJson 是字符串；适配器若需要等宽数值下降，须显式保存精确十进制 JSON 数字，并从保留的文本解码，见 ADAPTERS。

新增四项 MoonBit 单测：16,769 个小范围单调阈值组合、完整 64 位边界及最小负数、32 位兼容样例、超过 Double 精度的相邻整数和字符串编码边界。68/68 主模块单测、静态检查、原生构建、完整 behavior 和 6/6 SDK 单测及外部接入通过。首次静态检查因测试误用了工具链没有的 Array.find 失败，已改为显式枚举后通过；初次日志保留在 `results/int64-candidates-20261019/check.log`，没有写成初次成功。

新增合成阈值进程探针 `cmd/reducer-probe/integer64_checks.mbt`，接入既有 `--check-arguments`，也提供 `--check-int64 DIR`。三策略共 18 次完整缩减及三次六执行预算检查，缩减/预算部分共 1,701 次工作进程，另有 36 次独立重放/通过对照。正负 200 到 73、正负 2^53+1 到 2^53，以及 Int64 两端到向零邻值均按预期；保存的 18 份反例保留精确的未加引号数字。预算结果仍保持初值并标为搜索未完成。这些是合成阈值 oracle，对照的是引擎的数值生成、保存及重放能力。

本地记录 `results/verify-int64-candidates-20261019`、`results/sdk-int64-candidates-20261019`；固定语料一轮 63 次缩减、214 真子集及正确实现重放通过，输入/结果哈希、结构计数及参数进度与上一轮逐项相同，工作进程仍为 1,937 次，见 `results/benchmark-int64-candidates-20261019` 与 `results/int64-candidates-20261019/corpus-comparison.json`。本地快照 `docs/evidence/int64-candidates-20261019.json`。没有新增受版本控制的 PowerShell 源码，权限及公开推送授权沿用下方记录，仍禁止绕过安全审查。

实现提交 `e7dd7743f1cb1df4cf579a307b31d5fbcb4b79e1` 已推送。[Actions 39216392303](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39216392303) 五项均在工具链安装的 `verify-archives` 阶段因 `moonbit-windows-x86_64.zip` 身份不符失败，接受归档数为零，未解包或执行下载的工具，未运行云端业务测试或源码导出核对。下方历史成功不能代替本轮验收。五份失败报告和日志保留于 `results/github-ci-39216392303`，见 [失败快照](evidence/github-ci-39216392303.json)。

用户明确选择“保留当前锁，记录 CI 阻塞”。`toolchain.json`、安装脚本及 CI 配置保持原样，不升级或放宽校验；后续不自动改变这一决定。2026-10-19 只读取得的官方滚动归档校验值为 `653EBF0A3B2683048FAA8AD79B7B7D0721BF78726BF1A7E58678E9740B0D430F`，与原锁不同；保留的原始归档仍匹配原锁。CI 失败报告没有记录实际拒绝内容的 SHA-256/字节数，不能据此证明其具体版本或与当前官方清单相同。未再次尝试历史下载地址，未重跑覆盖失败结果，也未执行被拒绝的归档。

## 最新阶段：重复参数候选，2026-10-19

本轮从干净的 `02b21ae` 开始，在 runner 的每个步骤、每次参数扫描内缓存 JSON 编码完全相同且已有 Pass/PropertyFailure 的候选，避免重复执行消耗预算。缓存不跨步骤或接受后的轨迹变化；超时/协议等未决结果与无效候选不缓存。保持报告格式，查看过的重复项仍计入 candidates_checked，不创建虚假的进程日志。没有修改适配器、原生 fixture 或 PowerShell 源码。

新增 `cmd/reducer-probe/duplicate_checks.mbt`，由原有参数检查入口调用，也可单独使用 `--check-duplicates DIR`。九组进程探针在授权执行环境全部通过，共 116 次工作进程。重复通过候选只执行一次，三策略均在不超过 12 次总执行内将 9 缩到 0，并保留三次最终确认；重复协议错误各自保留两条未决记录；相同 arm 参数在三个不同轨迹上下文中重新执行，且不影响另一操作的相同参数。独立入口与完整验收内的九组摘要一致。

工具链内容校验、静态检查和原生构建通过。受限入口首次根模块单测在 core.whitebox_test.exe 退出 99 后终止，无断言结果；详细核心测试、单个核心测试和定向探针没有返回结果，均已取消，原因未确定。原始构建日志和观察记录保留在 `results/duplicate-candidates-20261019`。用户随后明确授权按正式审批提权；在批准的本机环境中，同一组源码的 64/64 主模块单测、完整 behavior、6/6 SDK 单测及外部接入通过。记录在 `results/duplicate-permission-20261019`、`results/verify-duplicate-candidates-20261019`、`results/sdk-duplicate-candidates-20261019`。状态快照 `docs/evidence/duplicate-candidates-20261019.json` 同时保留初次失败和后续通过证据。实现提交 `0869321c0f8eab9816509c41c61f7c83f8649e92` 已推送；对应 Actions `39210490957` 的五项 CI 已全部通过并下载核对，见下段新证据，不沿用上一版本的云端成功。

固定语料一轮 63 次缩减、214 个真子集和正确实现重放通过。相对于 `results/benchmark-binding-arguments-20261018`，63 行输入/结果哈希、性质指纹、步数、结构计数及参数进度全部一致，工作进程仍为 1,937 次；不宣称该固定语料获得加速或重复实验一致性。记录 `results/benchmark-duplicate-candidates-20261019`，逐行对照 `results/duplicate-permission-20261019/corpus-comparison.json`。本轮节约重复候选预算的效果来自新增定向探针，而非固定语料。

实现提交 `0869321` 的 [Actions 39210490957](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39210490957) behavior、ASan、benchmark、generation、sdk 五项通过。34 个关键源文件逐任务核对 Git 归档；64+6 单测、九组新探针的 116 次工作进程及既有 Buffer/Eigen 探针通过，新探针摘要与本地逐字节一致。189 次完整缩减的输入/结果哈希、结构计数、参数进度与本地对应记录一致，63/63 组重复一致，214 个真子集及 189 次正确实现重放通过；704 个生成场景、ASan 控制和锁定工具链检查通过。原始产物 `results/github-ci-39210490957`，快照 `docs/evidence/github-ci-39210490957.json`。本轮没有增加受版本控制的 PowerShell 源码；九组探针表明重复候选预算得到保留，不宣称固定语料整体加速。

用户要求遇安全审查先报告，不越权限。Win32_Process 只读查询初次返回“拒绝访问”后已立即报告并停止，没有改用其他进程查询入口。用户随后明确允许申请必要权限，同时禁止绕过安全审查。正式提权审批通过后，同一只读查询成功，未发现残留的 MoonBit 编译或测试进程；后续测试均经正式审批执行，没有新的审查拒绝。未修改执行策略、安全设置或系统权限。此前聊天的安全审查拦截保持记录，不作为已解除处理；后续如出现明确权限/安全拒绝，应停止对应操作并向用户报告。

## 最新阶段：真实 Buffer/Eigen 整数候选

2026-10-18：Buffer Write、Eigen Set 接入 `core.shrink_int`，Eigen New 先整体归零，再单元素缩减，跳过重复零和原样候选，保持形状/坐标/依赖。没有新增公共 API。64 主模块/6 SDK 单测及完整本地 behavior/SDK 通过；新单测覆盖 256 字节值、201 赋值及矩阵边界。既有 reducer-probe 可额外接收 Buffer/Eigen 路径，原有三参数检查方式仍可用；verify.ps1 只改变一行调用。

新增进程探针：真实 Buffer error 中的 Write 200 在三策略均缩为 1，接受链 `[100,50,25,13,7,4,2,1]`，归零掩盖失败被拒绝；执行数 32/35/35，四步保持原指纹。每策略独立 15 真子集和正确实现重放通过。Eigen 36 个真实独立进程执行正负构造/赋值候选及转置/乘法，全部六步 Pass，不是发现 Eigen 缺陷。原始 `results/verify-binding-arguments-20261018`、`results/sdk-binding-arguments-20261018`，快照 `docs/evidence/binding-arguments-20261018.json`。本地固定语料 63 次缩减与 214 真子集通过，所有字节/计数/参数进度与上一版本一致，1,937 个工作进程；记录 `results/benchmark-binding-arguments-20261018`。实现提交 `d7d0c1b` 已推送。首次 CI `39116730378` 的 64 单测及新探针通过，另外四套也通过；behavior 因既有 crash 探针 500 ms 内未观察到异常退出而失败，s2 读取已开始、完成两步，记录 Timeout 502 ms。全部首次产物和 `docs/evidence/github-ci-39116730378.json` 保留，不写成通过，也不推断已证明的主机原因。

修复提交 `b7c961cf75a7bf0e4ae3f4e4a1135e321119cef1` 单独给 crash 探针 10 秒预算，hang 仍 500 ms；两者须达到目标 read，crash 必须保留真实非零退出码。没有改变产品超时/分类逻辑。完整本地回归 `results/verify-binding-arguments-final-20261018` 再次通过。最终 Actions `39117413994` 五项通过并下载核查：64+6、新三策略 Buffer/36 Eigen 与本地汇总逐字节一致，33 个源文件逐任务对照归档，704 场景及 ASan 控制通过；189 次结果字节、结构计数、参数进度与本地一致，63/63 组重复一致、214 语料真子集及正确重放通过，另 45 新探针真子集通过。原始 `results/github-ci-39117413994`、快照 `docs/evidence/github-ci-39117413994.json`。上一轮的 62/63 计数差异不属于本轮。

默认受限 shell/Node 执行入口在本轮开始无响应；通过授权的 require_escalated + login=false 本地命令恢复读取、编辑和验证。工作开始时 main 干净且同步，未修改系统安全设置。继续优先 MoonBit 实际能力，不通过语言统计排除自有脚本。
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

用户要求继续未完成工作，优先加深并验证依赖与状态感知缩减，保留必要诊断。已授权本地实现、提交及推送到现有 GitHub 仓库；2026-10-19 已确认仓库公开并取得本轮公开推送授权，见下段。遇到权限或安全限制时停止对应操作、解释原因，不尝试绕过。源聊天曾收到安全风险拦截，原始记录保留在该聊天。

远端为 `serikaonoe123/moonffi-lab`，早期接续时记录为私有，接续前最新提交 `ce7fd9c`。2026-10-19 经 GitHub 实时只读查询确认 `isPrivate=false`，已先暂停推送并告知公开可见性；用户随后明确回复“允许推送到当前公开仓库”，授权本轮候选去重改动及验证记录公开推送并触发 CI。没有修改仓库可见性。此前公开发布的自动审批拒绝仍作为历史记录保留；本次操作仍须通过正式审批，如再被安全审查拒绝须立即报告并停止。

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
