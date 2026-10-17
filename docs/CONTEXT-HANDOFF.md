# 接续工作摘要

来源聊天：`codex://threads/01a14797-c8a1-7730-86c8-978e53a1924d`。整理日期：2026-10-17（Asia/Shanghai）。此文件保存接续所需信息；不改变原聊天历史。

## 目标与约束

项目路径 `D:\moonbit\moonffi-lab`。MoonBit 原生 FFI 测试引擎，支持进程隔离、具体输入保存、重放及缩减；Buffer 为人工 fixture，Eigen 为有来源记录的真实绑定快照。

用户要求继续未完成工作，优先加深并验证依赖与状态感知缩减，保留必要诊断。遇到权限或安全限制时停止对应操作、解释原因，不尝试绕过。源聊天曾收到安全风险拦截，原始记录保留在该聊天。本轮只继续本地实现、正确性验证及文档整理。

远端为私有仓库 `serikaonoe123/moonffi-lab`，接续前最新提交 `ce7fd9c`。公开发布此前被自动审批拒绝，当前没有新增公开授权。

## 已有实现

- `core/repair.mbt`：StateModel、纯删除修整、删除原因与子序列完整性检查。
- `fixtures/buffer/adapter.mbt`：别名共享状态、Resize、索引语义校验及修整。原生 fixture 与 FFI 同步支持 Resize。
- `runner/shrink.mbt`：plain/dependency/state 策略，统一调度与预算，最终单步删除审计，confirmed 与 deletion_minimal 分别报告。
- `cmd/reducer-probe`：可控稳定性和错误修整器；`scripts/verify.ps1` 覆盖预算、指纹变化和重放不稳定边界。
- `scripts/benchmark-reduction.ps1`：9 个确定性语料、三种策略、修复后重放、state 最终轨迹全部真子集独立重放。

## 已验证事实

2026-10-17 的 28/28 单测、完整集成验收和 ASan stub profile 验收全部通过。原始证据在 `results/verify-state-final-20261017` 和 `results/asan-state-final-20261017`；七步状态模型覆盖 128 个子集。

`results/benchmark-state-separated-20261017`：27 次对照、111 个最终真子集核验通过。plain/dependency/state 无效候选分别为 65/1/0，执行次数为 186/219/219，最终步数相同。状态修整确实删除了失去扩容前提的写入，但当前数据没有证明更快或缩得更短。详见 [实验记录](REDUCTION-STUDY.md)。

## 继续实现：Windows CI 与新源码目录复验

`cd93caa` 已提交状态感知缩减阶段。`92dd00f` 新增 `.github/workflows/windows-native.yml`、`toolchain.json`、`scripts/assert-toolchain.ps1` 和 `scripts/verify-clean.ps1`。CI 拆分 behavior、asan、benchmark，并在失败时上传诊断；版本安装入口使用 latest，严格版本闸门会拒绝漂移。详见 [复现指南](REPRODUCIBILITY.md)。

`results/clean-ci-offline-20261017` 从 92dd00f 导出无构建产物的源码，在新目录完成 28/28 单测、完整集成、ASan 和 27 次对照。依赖明确复用本地 async 源码。这不算独立主机或全新联网依赖验证。

早期本地下载安装器遇到套接字权限拒绝；经批准的诊断请求又遇到传输 EOF。这些历史失败保留。后续已将提交 `4f46b01` 推送到私有 GitHub 仓库，Actions run `38994542498` 的 behavior、ASan、benchmark 三个任务全部成功。托管 runner 使用 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6，重新下载 async 0.22.5。三个产物已下载核对，见 `docs/evidence/github-ci-38994542498.json` 及 VALIDATION。

用户手动运行也已通过，证据目录为 `results/verify-0fe000bac8dc42f0b3dfd7aabb7b3470`；已核对 28/28 单测和完整集成结果。用户此前在 Windows PowerShell 5.1 遇到签名报错；没有修改或绕过执行策略，随后指导使用项目要求的 PowerShell 7。未将签名错误的具体原因归因于版本差异。

## 后续工作

本次接续已完成持久摘要、实验快照、完整实验文档、语义修整分支覆盖及开发机之外的 CI 复现。后续可推进更多真实库语料、生成器探索能力、不可变安装包锁定和重复性能测量。参数简化仍受 JSON 编码长度下降限制，不能声称全局最小、任意参数最小或同一原生根因。

接续后的复验已完成：`results/verify-context-continuation-20261017` 的 28/28 单测和完整集成验收通过；`results/benchmark-context-continuation-20261017` 的 27 次对照和 111 个真子集核验通过，语义修整覆盖断言生效。候选数、步数及执行次数等结构指标与上一轮逐条一致。详见实验快照的 continuation 字段。

构建与验证从 README 的命令继续。输出目录必须是新目录；`results/` 被 Git 忽略。不要因为汇总文件齐全就删除原始失败、候选或重放日志。
