# v0.1.0 范围与发布准备

当前状态：实验性源码候选，尚未发布 registry 包或 GitHub Release。`moon.mod` 中的 0.1.0 是项目自身版本；它与编译器自报的 `v0.10.16+b1a0e846e`、文档仓库标签是不同对象。

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

## 发布前剩余工作

1. 核对候选自身六项 CI 和准备控制的产物，并记录确切提交。
2. 请独立使用者按 [复现入口](INDEPENDENT-REPRODUCTION.md) 提供 [反馈记录](templates/INDEPENDENT-REPRODUCTION.md)；自动化或托管 runner 不替代真实使用者反馈。
3. 用户审阅候选清单、许可来源、发布说明和上述未完成项后，再明确授权具体发布目标与附件。GitHub Release 和 registry 发布是不同动作，目前都没有执行。

当前无需上传历史工具链镜像或联系上游。官方 latest 地址将来若改变内容，安装应拒绝，按 [工具链锁定](TOOLCHAIN-LOCK.md) 重新评估；不放宽现有校验。候选源码包提供来源和复现入口，不包含一套永久可下载的完整离线工具环境。
