# 开发进度与验证索引

本页保留公开的技术进度；开发过程交接记录留在本地，不作为产品文档。

## 已验收

- 状态契约：独立初态、命令、前置条件、状态推进、后置条件和不变量接口；见 [说明](STATE-CONTRACTS.md)与 [CI 证据](evidence/github-ci-39604001946.json)。
- 有界 FFI 参数策略：十类参数、实际 C ABI 消费、参数缩减和重放；见 [说明](ARGUMENT-STRATEGIES.md)与 [CI 证据](evidence/github-ci-39609263290.json)。
- Linux 普通 native：78+7 单测、212 个项目正确场景、88 个 SDK 正确场景、1024 次参数操作与 23 项 ABI 边界；见 [范围说明](LINUX-ORDINARY.md)与 [CI 证据](evidence/linux-ordinary-20261022.json)。

## 本轮补齐验收

当前主分支验收提交为 `7d2716d`：[Windows 七项 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586714)及[Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586758)全部成功并核对产物，见[当前快照](evidence/main-acceptance-20261022.json)。[新版项目说明](HACKATHON-SUBMISSION.md)、[功能对照](FRAMEWORK-COMPARISON.md)和[表单填写材料](RESUBMISSION-TEXT.md)已准备；实际报名表尚未由本工具提交。

提交 `520cf68` 的 Windows 七项回归、Linux 普通 native/SDK 及原生崩溃/ASan 三策略缩减均已通过，并完成归档摘要、源码和原始报告核对。两个平台的六次专项缩减各为 32→2 步；见 [统一证据](evidence/native-acceptance-20261022.json)、[原生错误范围](NATIVE-ERRORS.md)与[环境复现约定](REPRODUCIBILITY.md)。本机 `41ff7e5` 另有干净导出的七项回归记录。

上述四项能力补齐的既定验收已完成。Linux 未声明与 Windows 七个 suite 全面等价，ASan 全程序覆盖、ASan 档五项控制、独立使用者反馈和新版本发布不在本次成功范围。

## 来源与限制

工具链内容身份见 [锁定说明](TOOLCHAIN-LOCK.md)。第三方源码身份与许可保持记录。人工故障不计为未知上游缺陷；错误签名描述观测位置，不证明同根因或全局最小。

当前 [rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1) 的历史发布范围见 [发布计划](RELEASE-PLAN.md)，不能用作后续未验收代码的证明。
