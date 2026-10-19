# 原工具链 CI 恢复方案

后续决定（2026-10-19）：用户明确允许使用新工具链，当前改走官方 0.10.16 的独立安装与兼容性验收，见 [验证记录](VALIDATION.md)。下文保留为旧锁恢复路径的历史评估，不再要求先完成旧包镜像或联系上游；询问仍未发送，归档未上传。

评估日期：2026-10-19。基线提交 `00466bf`，原实现 `e7dd774`，失败运行 [39216392303](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39216392303)。当前状态是方案评估完成、尚未实施：继续保留 `toolchain.json`，没有上传归档、创建发布、修改设置或切换 CI 来源。证据见 [评估快照](evidence/toolchain-ci-recovery-assessment-20261019.json)。

## 已确认与待确认

两份保留的原始归档都重新核对了大小及 SHA-256，符合现有锁；本次仅读 ZIP 目录及许可文本，没有解包或执行工具。安装器现有的 `-ArchiveDirectory` 可接受这两份归档，仍在任何解包和执行前完成全部归档校验。因此恢复原内容不需要改版本、哈希或安装校验逻辑。

| 文件 | 字节数 | SHA-256 |
|---|---:|---|
| `moonbit-windows-x86_64.zip` | 91,640,641 | `6E3EF6CB96AA5086D122183972687F79FC912F80652000907D96EE6AD967E3BF` |
| `core-latest.zip` | 2,529,648 | `05556B27B156348950EA88AE6838032C8B478AE532B18B3929387D1DA4C18D55` |

公开仓库 `serikaonoe123/moonffi-lab` 的当前访问权限为 ADMIN，发布列表为空；只做了读取，尚未查询或启用发布不可变设置。管理员权限能说明技术操作权限，不能证明第三方工具包的再分发许可。

core 归档内有 `core/LICENSE`（Apache 2.0）及 `core/NOTICE`；若以后分发，须保留这些文件及适用的第三方声明。Windows 工具包共 253 个 ZIP 条目，按 license/copying/notice/eula/terms/copyright 文件名检查只命中 `share/why3/LICENSE`。该文本包含 LGPL 2.1 及例外，不能代替整个工具包的许可说明。文件名检索也不是完整的组件许可审计。

当前[官方编译器源码库](https://github.com/moonbitlang/moonbit-compiler)说明了 Wasm 源码及其公开范围；其 [MoonBit Public Source License](https://raw.githubusercontent.com/moonbitlang/moonbit-compiler/main/LICENSE.TXT) 第 7 节对覆盖的二进制分发涉及相应源码条件。不能仅凭这个当前源码仓库，就认定它覆盖已锁定的完整 Windows native 工具包，也未确认每个组件的相应源码及其他义务。本次结论是**整包再分发依据尚未建立**，不是断言上游禁止再分发。

## 存放方式评估

| 方式 | 评估 |
|---|---|
| 上游提供原始内容的固定地址 | 优先使用上游明确提供且可获取的地址。当前没有确认这样的地址；不再猜测此前返回拒绝的历史 URL。取得有效来源后仍按原锁校验。 |
| 当前仓库的专用 GitHub Release | 技术上可行的候选。两份归档均小于 GitHub 文档的单附件 2 GiB 限制；但这是在公开仓库分发第三方工具包，须先补齐许可依据并取得针对具体发布的用户授权。 |
| Actions 缓存或诊断 artifact | 不作为长期权威来源。现有诊断明确不上传工具归档，不能悄悄扩大其范围；缓存失效后仍需要可靠来源。 |
| 自托管 runner / 其他私有存储 | 本轮不选择。没有已授权的 runner 或存储配置，且会引入访问控制、凭证和维护工作。私有存放本身也不自动解决许可问题。 |

GitHub [Release 附件](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)可承载归档。若许可依据成立且用户批准此方式，建议先草稿、完整上传和核对，再发布为[不可变 Release](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)。不可变性须实际查询并确认；本评估不声称当前已启用。GitHub 附件身份或发布证明只说明该附件与发布的关系，不等于上游签名或再分发许可。

## 待批准方案的具体范围

候选目的地为 `https://github.com/serikaonoe123/moonffi-lab/releases`，建议的新标签名为 `moonffi-toolchain-20261012-6e3ef6cb`，目前不存在该发布，也未创建标签。公开内容只包括上表两份逐字节不变的原归档、一份身份/来源清单，以及经确认需要随附的许可、声明或相应源码材料；不包含本机目录、账户凭证、工作区结果或生成的工具副本。若许可要求使附件集合变化，必须先更新这个清单再申请发布授权。即使是草稿上传也须先完成这些条件。

实施顺序：

1. 取得适用于这份完整 Windows 工具包的上游许可或明确再分发说明，核对编译器、构建器、运行时、Why3 和其他随附组件的许可/源码要求。优先取得上游固定下载来源；不以用户授权代替版权方许可。
2. 如选择公开镜像，给用户审阅最终附件清单、准确目的地、发布标签及不可变设置变更。当前“允许推送到公开仓库”的代码授权不视为自动允许公开上传第三方工具包。任何正式权限审查拒绝均停止对应操作并报告，不改用其他通道。
3. 许可与授权齐备后，创建专用发布并核对下载回来的每份附件与原锁逐字节一致；保存发布/附件 ID、URL、大小、摘要和来源证据。保留原来的滚动下载失败记录。
4. 单独提交 CI 下载接入变更，将准确来源固定到专用标签及附件身份；不使用 `latest`，不在失败时自动换源或接受新内容。`toolchain.json` 继续记载原始上游来源和身份，新增下载来源证据，避免把镜像误记为官方直接下载。
5. 按下方接口把归档放在新的下载目录。沿用 `install-toolchain.ps1 -ArchiveDirectory` 及现有 11 项拒绝边界检查；CI 消费权限继续为 `contents: read`，发布操作与测试工作流分开。下载故障、附件缺失、大小/摘要不符都应在执行前明确失败。
6. 运行五项全量 CI，再核对源码身份、本轮 68+6 单测、21 组 Int64 探针及既有 behavior/ASan/benchmark/generation/sdk 结果。只有产物实际通过后才更新验收状态，不能借用历史运行。

拟议的安装接口如下；**仅展示接入形状，不是当前已改动或运行的 workflow**。安装器要求证据目录 `results/bootstrap` 在调用前不存在，因此下载步骤先把归档放到独立的新目录，另存准确 URL 和附件身份，再传入安装器；边界检查的 `-ArchiveDirectory` 也使用同一个目录：

```powershell
# 前置步骤把两份已获准的原始附件下载到新的 $archiveRoot，保存来源证据。
# $archiveRoot 应位于 RUNNER_TEMP 下，不在 results/bootstrap 内。
& ./scripts/install-toolchain.ps1 -Destination $toolchainRoot `
  -ArchiveDirectory $archiveRoot -Out results/bootstrap
# behavior 套件继续检查同一份下载内容；其余五套验收入口保持原样。
& ./scripts/verify-toolchain.ps1 -ArchiveDirectory $archiveRoot `
  -ToolchainRoot $toolchainRoot -Out results/toolchain-checks
```

实际变更时还应调整安装器文档中来源模式的描述：`explicit-local-archives` 表示安装器读入本地文件，不等于这些文件未经过网络下载。下载凭证不得写入 URL、诊断或 artifact。现有诊断继续排除归档和工具目录。

## 上游询问草稿（未发送）

此草稿需要用户明确授权联系上游后才能发送；本轮没有创建 issue、邮件或论坛帖子。建议目的地为 [moonbitlang/moonbit-docs 的 Issues](https://github.com/moonbitlang/moonbit-docs/issues)，这是官方[下载页](https://www.moonbitlang.com/download)反馈链接指向的仓库；拟议标题为“历史 Windows 工具链固定下载地址与原样镜像许可说明”。发送前仍须核对该仓库的 issue 要求，并按正式审批执行。该消息只询问来源与许可，不上传归档。

> 我们希望持续验证一个公开的 Windows native MoonBit 项目，并保留原工具链内容锁。当前 latest 下载内容已经变化，旧版 CI 会按设计拒绝不匹配的归档。
>
> 我们保留了官方 Windows x64 工具包：moon 0.1.20261012 (748b63c)、moonc v0.10.15+943464bfa；归档 91,640,641 字节，SHA-256 为 6E3EF6CB96AA5086D122183972687F79FC912F80652000907D96EE6AD967E3BF。另有同版本 core 原归档，2,529,648 字节，SHA-256 为 05556B27B156348950EA88AE6838032C8B478AE532B18B3929387D1DA4C18D55。
>
> 请问是否有仍可获取这两份原内容的官方固定下载地址？如果没有，是否有覆盖整个 Windows 工具包的明确许可，允许在公开项目的专用 GitHub Release 中原样镜像，仅用于可复现安装及 CI？应附带哪些组件许可、NOTICE、相应源码或其他材料？当前公开编译器源码库的许可是否适用于该版本完整 native 工具包？我们会继续按上述原始 SHA-256 校验，不修改或重新打包这些归档。

在取得来源或许可依据之前，维持 CI 阻塞和本地已验证状态。本轮没有恢复云端验收，也没有升级工具链。
