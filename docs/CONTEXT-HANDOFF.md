# 开发进度与验证索引

本页保留公开的技术进度；开发过程交接记录留在本地，不作为产品文档。

## Mooncakes 验收缺口准备（2026-10-30）

按新验收指南，第 8 项 registry 发布为必做，独立使用者反馈不是该指南硬性条件；初审通过后无须再提交表格。PR #9 准备仅含 core/runner 的 32 文件 native 包、完整元数据与候选安装说明。候选 e4ca0fa 的四套 CI 和十份产物核对通过，归档消费者、17 项冻结发布控制及既有 Windows/Linux 回归通过；见 [准备记录](evidence/mooncakes-preparation-20261030.json)。

用户尚无 Mooncakes 账号，当前命名空间和 0.1.0 版本均为待确认方案，未登录或上传 registry，也未证明 registry-installed engine 的消费。下一步由用户注册并确认用户名，再确认包名/版本可用性、具体发布范围与发布后的新消费者安装。已发布 GitHub rc.1/rc.2 与其冻结资产不变。

## rc.2 交付（2026-10-26）

PR #7 已合并为 `381643a`，合并后 Windows 七项及 Linux CI 全部成功，八份产物及原始结果核对完成。用户随后明确批准固定草案，已公开 [rc.2](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.2)，标签指向已测候选 `20b608d`，prerelease、非 Latest；563 文件源码包及另外三附件完整回下载匹配，rc.1 保持不变。见 [执行快照](evidence/prerelease-v0.1.0-rc.2-20261026.json)与 [草案/执行记录](PRE-RELEASE-PROPOSAL-rc.2.md)。独立使用者反馈仍待完成，稳定版及 registry 包未发布；参赛者已确认通过初审，重新申报不再列为待办。

## main 验收历史（2026-10-24）

PR #5 已合并为 `f464479`，MoonBit 0.10.17 的合并后 [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40059560662)及 [Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40059560654)均成功，八份产物及原始结果核对完成，见 [main 验收记录](evidence/main-toolchain-acceptance-20261024.json)。合并后复跑核对这项工作已完成。独立使用者反馈和后续版本发布仍单独跟踪；下文较早提交及证据保留各自日期和范围。

## 已验收

- 状态契约：独立初态、命令、前置条件、状态推进、后置条件和不变量接口；见 [说明](STATE-CONTRACTS.md)与 [CI 证据](evidence/github-ci-39604001946.json)。
- 有界 FFI 参数策略：十类参数、实际 C ABI 消费、参数缩减和重放；见 [说明](ARGUMENT-STRATEGIES.md)与 [CI 证据](evidence/github-ci-39609263290.json)。
- Linux 普通 native：78+7 单测、212 个项目正确场景、88 个 SDK 正确场景、1024 次参数操作与 23 项 ABI 边界；见 [范围说明](LINUX-ORDINARY.md)与 [CI 证据](evidence/linux-ordinary-20261022.json)。

## 四项补齐验收（2026-10-22 历史记录）

当时的主分支验收提交为 `7d2716d`：[Windows 七项 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586714)及[Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586758)全部成功并核对产物，见[当时快照](evidence/main-acceptance-20261022.json)。[新版项目说明](HACKATHON-SUBMISSION.md)、[功能对照](FRAMEWORK-COMPARISON.md)和[表单填写材料](RESUBMISSION-TEXT.md)已准备；实际报名表尚未由本工具提交。

提交 `520cf68` 的 Windows 七项回归、Linux 普通 native/SDK 及原生崩溃/ASan 三策略缩减均已通过，并完成归档摘要、源码和原始报告核对。两个平台的六次专项缩减各为 32→2 步；见 [统一证据](evidence/native-acceptance-20261022.json)、[原生错误范围](NATIVE-ERRORS.md)与[环境复现约定](REPRODUCIBILITY.md)。本机 `41ff7e5` 另有干净导出的七项回归记录。

上述四项能力补齐的既定验收已完成。Linux 未声明与 Windows 七个 suite 全面等价，ASan 全程序覆盖、ASan 档五项控制、独立使用者反馈和新版本发布不在本次成功范围。

## 维护增量（2026-10-24）

ASan 档五项控制已在 Windows/Linux 均执行并核对。官方固定版本地址提供与原锁完全一致的三份归档；候选 `33bbfea` 已在源码树一致的 PR 合成合并提交 `fee7f97` 通过 Windows 七项和 Linux 验收，见 [当前云端记录](evidence/maintenance-hosted-20261024.json)。先前 [安装失败记录](evidence/maintenance-20261024.json) 保留，工具链内容摘要未变。独立使用者反馈和新版发布仍待完成。

## 官方工具链升级（2026-10-24）

PR #4 已合并为 `fdd8849`，合并后 Windows 七项和 Linux CI 均成功。本分支候选 `bda5201` 进一步锁定官方 moonc/core 0.10.17 与 moon/moonrun 2026-10-23 构建，Windows 七项及 Linux 验收全部通过，八份产物与原始结果已核对，见 [升级记录](evidence/toolchain-upgrade-20261024.json)。benchmark 189 次结构指标及具体结果字节不变；旧安装、旧锁对应提交、rc.1 发布范围及历史失败保留。独立使用者反馈和新版发布仍待完成。

## 来源与限制

工具链内容身份见 [锁定说明](TOOLCHAIN-LOCK.md)。第三方源码身份与许可保持记录。人工故障不计为未知上游缺陷；错误签名描述观测位置，不证明同根因或全局最小。

当前 [rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1) 的历史发布范围见 [发布计划](RELEASE-PLAN.md)，不能用作后续未验收代码的证明。
