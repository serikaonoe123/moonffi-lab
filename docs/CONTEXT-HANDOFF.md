# 开发进度与验证索引

本页保留公开的技术进度；开发过程交接记录留在本地，不作为产品文档。

## 已验收

- 状态契约：独立初态、命令、前置条件、状态推进、后置条件和不变量接口；见 [说明](STATE-CONTRACTS.md)与 [CI 证据](evidence/github-ci-39604001946.json)。
- 有界 FFI 参数策略：十类参数、实际 C ABI 消费、参数缩减和重放；见 [说明](ARGUMENT-STRATEGIES.md)与 [CI 证据](evidence/github-ci-39609263290.json)。
- Linux 普通 native：78+7 单测、212 个项目正确场景、88 个 SDK 正确场景、1024 次参数操作与 23 项 ABI 边界；见 [范围说明](LINUX-ORDINARY.md)与 [CI 证据](evidence/linux-ordinary-20261022.json)。

## 待完成

1. 原生错误验证脚本与 CI、完整回归及云端产物核对。
2. Linux 原生错误/ASan 缩减及完整行为回归；普通构建、单测和正确场景已独立验收。
3. 验收完成后更新项目说明与支持范围。

## 来源与限制

工具链内容身份见 [锁定说明](TOOLCHAIN-LOCK.md)。第三方源码身份与许可保持记录。人工故障不计为未知上游缺陷；错误签名描述观测位置，不证明同根因或全局最小。

当前 [rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1) 的历史发布范围见 [发布计划](RELEASE-PLAN.md)，不能用作后续未验收代码的证明。
