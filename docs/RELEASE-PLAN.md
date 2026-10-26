# v0.1.0 范围与发布准备

## 下一版试用候选：v0.1.0-rc.2

2026-10-26 开始准备新版源码候选，纳入显式状态契约、十类 FFI 参数、原生崩溃/ASan 缩减、Linux native 和官方 0.10.17 工具链。独立机器可读范围见 [rc.2 scope](releases/v0.1.0-rc.2-scope.json)，对外说明见 [rc.2 发布说明草稿](RELEASE-NOTES-v0.1.0-rc.2.md)。当前业务基线为 `f464479`，对应已核对的 [Windows 七项及 Linux 记录](evidence/main-toolchain-acceptance-20261024.json)；rc.1 冻结清单、标签和历史附件保持原义。

准备器默认继续按 rc.1 冻结范围检查。显式选择 rc.2 时，须在已提交的候选 checkout 中运行，输出目录必须尚不存在：

```powershell
& ./scripts/prepare-release.ps1 -Ref HEAD -ScopeFile docs/releases/v0.1.0-rc.2-scope.json -Out results/rc2-candidate
python scripts/test_release_rc2.py --ref HEAD --out results/rc2-controls
```

rc.2 入口要求已审阅锚点中的证据 Git blob、两平台工具链及来源许可保持一致；运行代码和既有验收脚本相对基线有变化时拒绝准备。本轮允许的准备器、准备控制及专用 CI 变更单独列在 candidate.json，不冒充已经包含在业务基线中。候选自身还需 Windows 七项、Linux 和专用源码准备 CI；准备成功始终是 prepared-not-published，publish_ready=false。

新的源码包、清单、SHA256SUMS 和具体目标提交会先整理为可审阅的发布草案。发布批准只在具体内容可核对后再处理；本轮不创建标签、GitHub release 或 registry 包。独立使用者反馈继续单独跟踪，托管 CI 不替代该反馈。

## rc.2 候选验收与拟议附件

候选 `20b608d6d8546873d5d66786dc8e12642dd70e9c` 已通过 Windows 七项、Linux 和 16 项源码准备控制，九份诊断归档与原始报告已核对，见 [统一证据](evidence/rc2-preparation-20261026.json)。已生成 563 份文件的固定源码包、候选元数据、逐文件清单和 SHA256SUMS。具体目标、四附件大小/摘要、正文与限制见 [rc.2 预发布草案](PRE-RELEASE-PROPOSAL-rc.2.md)；它们仍是待批准的具体发布内容。准备时的 pending 字段保留，不冒充实时发布状态。

## rc.1 冻结范围与历史发布准备

> 下文保留已发布 rc.1 的冻结范围与准备流程，只描述其固定提交及当时证据。后续新增能力及当前源码准备状态见上方 rc.2 说明。

当前状态：已于 2026-10-20 发布 [v0.1.0-rc.1 实验性源码预发布](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1)，尚未发布稳定版或 registry 包。`moon.mod` 中的 0.1.0 是项目自身版本；它与编译器自报的 `v0.10.16+b1a0e846e`、文档仓库标签是不同对象。

本轮候选代码提交 `23893d5bb3a231a21df10db506d8da821a7e984d` 已通过 [六项 CI 39361478378](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39361478378) 及产物核对。四项源码准备控制在本地和云端通过，498 份源码逐文件一致，75 个关键文件逐任务匹配提交归档，原有运行/缩减基准不变。见 [本地准备记录](evidence/release-preparation-20261020.json)与[本轮云端记录](evidence/github-ci-39361478378.json)。后续文档收尾不改变该提交的运行代码。

机器可读范围在 [v0.1.0-scope.json](releases/v0.1.0-scope.json)，面向使用者的说明在 [发布说明草稿](RELEASE-NOTES-v0.1.0.md)。本轮冻结功能范围，后续修复须对应新的提交和验证记录。

## 纳入范围

| 部分 | v0.1.0 范围 |
|---|---|
| 环境 | Windows x64、MoonBit native、MSVC；完整环境控制复现使用 PowerShell 7.5+，已有云端为 7.6.6 |
| 引擎 | core / runner 公开源码包；编译期接入 Adapter / StateModel、确定性生成、独立进程、具体输入保存及重放 |
| 缩减 | plain / dependency / state，删除与参数候选交替、预算、指纹和三次确认、删除邻域检查 |
| 输入协议 | trace schema 1，保存具体步骤及 adapter / generator 版本；seed 不代替输入 |
| 示例 | 人工 Buffer、既有 Eigen 快照、独立 C 计数器教学模块、未修改的社区 SQLite 消费者 |
| 证据 | 六项 Windows CI；异常、超时、预算、拒绝边界和固定缩减基准；保留失败记录 |
| ASan | 既有 Buffer C 和 Eigen C++ stub profile；具体插桩边界按验证报告解释 |

0.x 接口仍属实验性。冻结的是此候选提交的行为、来源和已验证范围，不承诺后续小版本无破坏性变更。新增操作、生成规则或编码语义须审视 adapter_version / generator_version；旧具体输入按自身版本重放。当前不覆盖 Linux/macOS、并发/任意 SQL、通用崩溃缩减、全局最短、任意参数最小、堆泄漏证明或 SQLite ASan，也没有发现未知上游缺陷。

## 本地准备可核对的源码包

在包含本脚本和冻结清单的已提交源码 checkout 中运行：

```powershell
& ./scripts/prepare-release.ps1 -Ref HEAD -Out results/release-candidate
& ./scripts/verify-release-preparation.ps1 -Out results/release-checks
```

输出目录必须是新目录。准备器用 Git 导出已提交源码，并仅为归档命令指定换行参数，逐文件核对 Git blob 与 SHA-256，要求所有受版本控制文件都在归档内，保留许可及来源文件，拒绝构建产物、工具包、缓存及不支持的文件类型。它不解包或运行归档内脚本。`source.zip` 包含仓库中已存在的 Eigen 等第三方源码及原许可，不含 MoonBit 工具链、async 缓存或下载的 SQLite 包。

`candidate.json` 记录提交/tree、源码 ZIP 大小/SHA、逐文件清单摘要、原生运行代码与已验收基线的差异、准备器哈希及未完成项；任何运行代码或既有验证脚本漂移都要求先更新基线。基线是明确的旧运行记录，不冒称为当前候选自身的 CI。准备控制另核对两份本地 ZIP/清单一致、已有输出保留、不存在提交及缺失冻结清单被拒绝；这不证明不同 Git 版本下 ZIP 压缩字节一致。

成功状态始终为 `prepared-not-published`，`publish_ready=false`。本地准备不执行发布、打标签、下载或构建。CI 仅保存准备控制的 JSON/日志，不上传源码 ZIP 或第三方工具包。

源码 ZIP 用于审阅和比对；完整验收入口 verify-clean 依赖 Git 对象，请从 Git checkout 选择包中记录的相同提交运行。当前没有提供解压 ZIP 后不依赖 Git 的完整验收模式。

## 预发布记录与稳定版前剩余工作

用户明确批准具体草案后，已创建固定指向 23893d5 的预发布标签，上传四份审阅过的附件，不标记 Latest。四份附件回下载后大小/SHA-256、标签目标及发布正文全部匹配，见 [执行记录](PRE-RELEASE-PROPOSAL.md)与[核验快照](evidence/prerelease-v0.1.0-rc.1-20261020.json)。原 candidate.json / publication-proposal.json 保留准备时状态，不作为实时发布状态。

候选自身六项 CI、准备控制和产物核对已经完成。稳定版前仍需：

1. 请独立使用者按 [复现入口](INDEPENDENT-REPRODUCTION.md) 提供 [反馈记录](templates/INDEPENDENT-REPRODUCTION.md)；自动化或托管 runner 不替代真实使用者反馈。
2. 根据反馈决定是否修复，变更代码时重新验证对应提交；后续稳定版或 registry 发布须另行明确目标及附件，本次批准仅覆盖 rc.1 草案。

预发布用于收集试用反馈，不表示已获得独立使用者验收或赛事审核通过。复现反馈可以通过 [贡献入口](../CONTRIBUTING.md) 手动提交；十月黑客松申报说明草稿见 [项目说明](HACKATHON-SUBMISSION.md)。

当前无需上传历史工具链镜像或联系上游。官方 latest 地址将来若改变内容，安装应拒绝，按 [工具链锁定](TOOLCHAIN-LOCK.md) 重新评估；不放宽现有校验。候选源码包提供来源和复现入口，不包含一套永久可下载的完整离线工具环境。
