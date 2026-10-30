# Mooncakes 发布准备

2026-10-30 状态：用户已注册并确认账号 `serikaonoe123`，候选模块名 `serikaonoe123/moonffi-lab`、版本 `0.1.0`；未上传 Mooncakes。官方公开 manifest 接口查询该版本返回 404/Package not found，同一接口对 async 0.22.5 返回 200；上传前仍须重查。本机 CLI 登录、最终归档复核及具体发布授权尚待完成。既有 GitHub rc.1/rc.2 标签、源码附件和证据不变；其源码准备门槛仍只接受冻结提交，不为新 registry 改动放宽。

## 账号确认前的准备验收

候选 `e4ca0fafc08b75237f59fba0714d6e61645a42a8` 在源码树一致的 PR checkout `960933f` 完成 [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558109)、[Linux](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558243)、[实际归档消费者](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558261)和 [17 项冻结发布控制](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558111)，十份诊断归档及原始记录已核对，见 [准备证据](evidence/mooncakes-preparation-20261030.json)。Windows 每项 571 文件匹配，189 次 benchmark 结构指标和具体结果字节与旧基准一致。

本地实际 ZIP 为 45,488 字节、32 文件，SHA-256 `1D9F15C0D55CB6860603586B971A41A3E0F9A9011B63E7CBA6338C0A539CBC99`。云端清单逐文件匹配 Git，报告的 ZIP 摘要与本地相同，29 份引擎输入来自该归档；SDK 7 单测、1024 次真实 C FFI 操作和 23 项 ABI 边界通过。此摘要仅对应账号确认前的候选说明。注册信息确认后已定稿 registry README，须生成新的归档与摘要；旧记录不作为新归档的验收结果。

首轮本地预检拒绝不被锁定构建器支持的 homepage 字段；首轮云端预检因索引恢复后未安装依赖，被 frozen 检查正确拒绝。记录均保留。修订先正常执行依赖检查，再保持 frozen 打包并核对 async 0.22.5；没有放宽文件集合、Git 字节或旧发布门槛。当前结果不等同于真实 registry 安装。

## 注册与登录

账号注册和用户名确认已完成。按 [官方账号说明](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html#setup-mooncakes-io-account)用 `moon login` 在本机完成登录；本项目使用锁定工具链所在的 MOON_HOME。登录 token 不需要放在源码、CI 配置或聊天内容中。源码打包和离线消费者检查不需要发布账号。

## 本次包范围

发布专用 README 为根目录 README.mooncakes.md。moon.mod 提供 repository，并明确仅支持 native。`.moonignore` 只允许元数据、MIT 许可证、core/runner 的 MoonBit 源码及各自 moon.pkg、runner/native_guard.c。第三方 Eigen、历史随机流、故障 fixture、命令示例、文档脚本、依赖缓存和构建产物不随库包上传；它们在 GitHub 完整工程中保留原样来源和许可。

根 README 保留完整工程安装与演示，并记录尚未发布的当前状态；registry README 面向包使用者，提供安装命令和最小调用，不随包携带账号注册或内部准备记录。安装命令须在实际发布后使用。0.1.0 是实验性模块版本，不据此宣称稳定 API。

## 上传前检查

```powershell
# 在锁定工具链环境下运行；输出目录必须是新目录且位于 Git checkout 外。
python scripts/verify_mooncakes.py --ref HEAD --out D:/moonbit/moonffi-registry-check
# 离线检查：显式提供 .mooncakes 源码缓存目录。
python scripts/verify_mooncakes.py --ref HEAD --out D:/moonbit/moonffi-registry-offline --dependency-source ./.mooncakes
```

脚本从指定提交导出源码，使用实际 `moon package` 生成 ZIP，并要求归档文件集合非空且精确等于公开包清单，每份内容匹配 Git。还加入明确标注的非敏感排除探针，验证任意 txt/obj/隐藏文件未混入包中。输出路径若在 checkout 内直接拒绝，避免继承仓库上层 results 忽略规则产生空包；只检查命令退出码不足以证明归档有效。

脚本解包被审查的 ZIP，再用已有外部计数器、契约和真实 C ABI 消费者运行 SDK 检查。只有 core/runner/moon.mod 来自归档，测试驱动和示例另作为清楚记录的 harness 输入；不得用仓库引擎副本替代缺失的归档文件。报告中 registry_installed_engine 始终为 false，此阶段不证明已经从 Mooncakes 安装。

源码准备 CI 单独测试冻结 rc.2 提交 `20b608d`，并要求当前开发提交被旧门槛拒绝；它不把新模块元数据伪装成旧 rc.2 已发布范围。新的 package preflight CI 负责本轮归档消费检查。

## 实际发布与发布后验收

先确认账号与包名、版本未占用、最终源码提交、上传文件清单/摘要和线上权限；通过当前提交的 Windows/Linux CI 与 package preflight 后，才整理具体发布授权。正式上传另行确认，不由检查脚本自动执行。

发布后在仓库/源码工作区之外建立全新消费者，不提供本地引擎成员、不复用本地 engine 缓存，通过 registry 安装指定版本。核对依赖解析树、下载来源和核心源码身份，再运行相同的 native SDK 行为/契约/FFI 路径。只有包页面可访问且这一轮安装/运行通过，才能将验收指南第 8 项计为已完成。独立使用者反馈不是该指南列明的硬性条件，已过初审无需再提交表格。
