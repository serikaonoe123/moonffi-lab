# v0.1.0-rc.2 预发布草案

状态：2026-10-26 已准备候选源码与四份附件，候选自身 Windows、Linux 和源码准备 CI 均通过，九份产物与原始结果已核对；尚未创建标签或发布。见 [统一证据](evidence/rc2-preparation-20261026.json)。本页列出可审阅的发布动作，不表示已获发布批准。独立使用者反馈仍待完成。

## 拟议动作与固定内容

- 仓库：`serikaonoe123/moonffi-lab`。
- 新标签：`v0.1.0-rc.2`，仅指向 `20b608d6d8546873d5d66786dc8e12642dd70e9c`；2026-10-26 只读检查时尚不存在。
- 标题：`MoonFFI Lab v0.1.0-rc.2 (Windows and Linux native source preview)`。
- 公开 GitHub 预发布，`prerelease=true`，不标记 Latest；项目清单版本仍为 0.1.0。
- 仅上传下列四份附件；保留 rc.1 标签、附件及历史证据。

| 附件 | 字节数 | SHA-256 |
|---|---:|---|
| `candidate.json` | 2727 | `632BC4828AC0E3271BB5849BE239DC0846914DE9AB079D9DCCDBDC5378BA9923` |
| `source-manifest.json` | 138501 | `9B447DCCE21AA53C69E64A77AA257976AD6F6EC0563D3258FA9FEE983E550143` |
| `source.zip` | 1689710 | `1AB5296F4DC5F8CDB3862704D878151056D5025A9046CCC2C8B3333DA895D4E0` |
| `SHA256SUMS` | 245 | `097C357745DF9FF8A127DE94A3BD9861F667EA163E876C8B4D566D7E54C9865C` |

源码包固定为 563 份受版本控制文件，逐文件匹配 Git blob 与摘要。`SHA256SUMS` 列出另外三份附件，其自身摘要在上表。四份附件保存在本地 `results/rc2-preparation-20261026/proposal/assets/`，可审阅的机器清单和正文为同目录上一级的 `publication-proposal-reviewed.json` 与 `release-body.md`。源码 ZIP 当前用于审阅，完整运行依赖同提交的 Git checkout。

## 验收与准备记录

[Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069688)、[Linux](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069753)与 [源码准备](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069774)全部成功。实际 checkout 为 `9f0729bde2f3a0e5db7da3d4ed91486c62220a2b`，父提交和规范 Git 对象身份已核对，完整源码树与拟议目标一致。Windows 每项核对 563 份源码，benchmark 189 次结构指标及具体结果字节与旧基准一致；两平台 crash/ASan 各三策略均为 32→2。16 项源码准备控制、本机原有 rc.1 五项控制通过。基线、候选自身运行、准备工具控制和真实用户反馈分别记录。

云端准备的 ZIP 指向 PR 合成提交，本地发布附件指向拟议标签目标，因此 ZIP 摘要不同；全部源文件 Git blob 与源码清单字节相同。云端源码 ZIP 未上传为 CI 产物，本次直接复核的是其清单、诊断和控制记录；本地拟议发布 ZIP 已逐文件核对。不能据此声称云端与本地 ZIP 字节相同。

`candidate.json` 和归档内文档保留准备时状态；其中 candidate-hosted-acceptance 待办已由后续证据满足，不能改写成准备器本身执行过 native 验收。发布批准和独立使用者反馈仍未完成。若源码提交或附件变动，必须重新生成相应清单并复核，不能沿用上表。

## 拟议发布正文

这是 MoonFFI Lab 的实验性原生绑定测试源码候选，用于独立使用者试用；独立使用者复现反馈尚未完成。

- 固定源码提交：`20b608d6d8546873d5d66786dc8e12642dd70e9c`，项目清单版本仍为 `0.1.0`。
- [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069688)、[Linux native/SDK 和原生崩溃/ASan](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069753)及 [16 项源码准备控制](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40320069774)全部通过，九份诊断归档及原始报告已核对。实际 PR checkout 为 `9f0729bde2f3a0e5db7da3d4ed91486c62220a2b`，完整 Git 树与目标提交一致。
- 纳入显式状态契约、十类有界 FFI 参数策略、三策略原生错误缩减与官方 MoonBit 0.10.17 内容锁。189 次固定 benchmark 的结构指标和具体缩减结果字节与旧基准一致。
- 附件 `source.zip`、`candidate.json`、`source-manifest.json` 与 `SHA256SUMS` 用于审阅和比对；源码包含已有第三方来源和许可，不包含工具链、依赖缓存、下载的 SQLite 包或构建产物。563 份源码逐文件匹配 Git；附件基于上面的目标提交，区别于 GitHub 自动生成的源码下载。
- 完整验收须从 Git checkout 选择该提交，依照 [复现入口](https://github.com/serikaonoe123/moonffi-lab/blob/20b608d6d8546873d5d66786dc8e12642dd70e9c/docs/INDEPENDENT-REPRODUCTION.md)的 Windows 七项或 Linux 指令运行，将其中的固定 ref 替换为上面的候选提交。rc.2 源码准备需显式传入 `-ScopeFile docs/releases/v0.1.0-rc.2-scope.json`。

Windows 与 Linux 的覆盖范围不同；ASan 仅插桩列明单元，专项只插桩自有 faults.c。弱证据 ASan 控制为合成诊断，其余控制执行真实插桩人工故障。人工故障不计为未知上游缺陷；位置指纹不证明同根因或全局最小，删除邻域最小不保证参数最小。公开源码 API 仍属实验性，未发布 registry SDK。

`candidate.json` 及归档内说明保留准备时快照；其中的待验收/未发布字段不充当之后的 CI 或 GitHub 发布状态实时记录。后续候选验收以独立证据记录为准。


## 范围边界

本草案只覆盖上述新标签、公开预发布和四份具体附件；不包含 registry 发布、工具链镜像上传、联系上游或修改报名表。赛事初审结果也不等同于使用者独立复现或稳定版验收。完整功能与限制见 [rc.2 发布说明](RELEASE-NOTES-v0.1.0-rc.2.md)。
