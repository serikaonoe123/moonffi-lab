# v0.1.0-rc.1 预发布草案与执行记录

当前状态：2026-10-20 已按下列草案创建 [v0.1.0-rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1)。标签指向下列固定提交，四份附件回下载后的大小与 SHA-256 全部匹配，正文核对一致；见 [发布核验快照](evidence/prerelease-v0.1.0-rc.1-20261020.json)。发布前复查确认标签不存在，没有覆盖标签。以下保留原审阅范围与正文。

## 拟议的具体动作

- 仓库：`serikaonoe123/moonffi-lab`，现有公开仓库。
- 新标签：`v0.1.0-rc.1`，指向已测提交 `23893d5bb3a231a21df10db506d8da821a7e984d`。
- GitHub 标题：`MoonFFI Lab v0.1.0-rc.1 (Windows native preview)`。
- 公开预发布：`prerelease=true`，不标记为 Latest。
- 上传下列四个附件，发布前重新核对其大小/SHA；保留 GitHub 自动生成的源代码下载与这些已核验附件的区别。

| 附件 | 字节数 | SHA-256 |
|---|---:|---|
| `candidate.json` | 2754 | `B5F8AE2FE6316858293E01129191DB3580FF9A11198088A80898C77FFA840844` |
| `SHA256SUMS` | 245 | `15B4A9125583AEB61396CE295FCA1100338A16A9ACD139851AE6F1D3F66ED447` |
| `source-manifest.json` | 123771 | `19A236CABF25AA98806A542AA511A1A5D5E0468E25551CFDED6B5C0818C5CFF6` |
| `source.zip` | 1550203 | `EEA70786A734B8CDBD25FFD096AB607A9D2B282C43CDA78C8C3027F69D656E38` |

`source.zip` 恰为上一轮核验过的 498 文件候选包，不从未提交工作区重新拼装。包含仓库已有的 Eigen 绑定/头文件、历史随机流源码及原许可；不含 MoonBit 编译器工具包、async 缓存、下载的 SQLite 包或构建产物。`SHA256SUMS` 列出前三份附件的摘要，其自身摘要保存在本表。

`candidate.json` 是源码准备时的不可变快照，其中的未发布/待办字段不充当 GitHub 发布状态的实时记录；即使批准试用预发布，也不会把待完成的独立使用者反馈改写为已完成。

## 发布正文草稿

这是 MoonFFI Lab 的实验性 Windows native 源码试用候选，用于征集独立使用者的首次运行与复现反馈；独立使用者验收尚未完成。

- 源码提交：`23893d5bb3a231a21df10db506d8da821a7e984d`。
- [六项 Windows CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39361478378) 与产物核对通过；498 份候选文件、四项源码准备控制及原有缩减基准已核对。
- 下载附件 `source.zip`，配合 `candidate.json`、`source-manifest.json` 和 `SHA256SUMS` 审阅。源码包含仓库已有的 Eigen 等源文件及原许可，未包含编译器工具包、依赖缓存或构建产物。
- 完整验收从 Git checkout 选择上述提交，按[复现入口](https://github.com/serikaonoe123/moonffi-lab/blob/main/docs/INDEPENDENT-REPRODUCTION.md)运行；源码 ZIP 当前用于审阅和比对。
- 可手动提交[复现反馈](https://github.com/serikaonoe123/moonffi-lab/issues/new?template=independent-reproduction.yml)，失败或未完成同样有价值。请注明是否参与过该提交开发/验证。

公开接口仍属实验性；当前完整验证为 Windows native。Buffer/计数器中的目标缺陷为人工教学示例；SQLite 接入尚未发现未知上游缺陷。ASan 仅覆盖记录中的 Buffer/Eigen C/C++ 单元，未覆盖 SQLite 或整个运行时；不保证全局最短或堆泄漏证明。

本标签为 GitHub 试用候选 `v0.1.0-rc.1`，项目清单版本仍为 `0.1.0`；这不是 registry 包发布。编译器版本以工具链锁和实际自报为准。

## 授权边界与尚未完成项

独立使用者反馈仍待完成；预发布只用于邀请试用，不能写成已获得独立用户验收或已发现未知缺陷。registry 发布、上游消息和第三方工具包上传不在这份草案的动作清单中。

本预发布仅包含上述标签、预发布和四附件，不代表后续版本或 registry 包已发布。实际执行与回下载核验见下方发布记录。GitHub CLI 的 target/prerelease/latest 语义以[官方 create 文档](https://cli.github.com/manual/gh_release_create)为依据。

本地审阅文件在 `results/community-readiness-20261020/prerelease-proposal/`：publication-proposal.json、release-body.md 和 assets/，保留准备时快照，不改写为事后授权记录。实际执行与回下载核验在 `results/publish-prerelease-20261020/`。仓库中的反馈表单和贡献说明用于等待真实反馈，未自动提交 Issue 或联系其他人。
