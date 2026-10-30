# Mooncakes 发布准备

2026-10-30 状态：尚未注册/确认发布账号，未上传 Mooncakes。暂定模块名 `serikaonoe123/moonffi-lab`、版本 `0.1.0`，确认实际账号命名空间后才冻结具体发布草案。既有 GitHub rc.1/rc.2 标签、源码附件和证据不变；其源码准备门槛仍只接受冻结提交，不为新 registry 改动放宽。

## 注册与登录

按 [官方账号说明](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html#setup-mooncakes-io-account)运行 `moon register` 注册，再用 `moon login` 在本机完成登录。请先确认用户名能使用声明的命名空间。登录 token 不需要放在源码、CI 配置或聊天内容中。源码打包和离线消费者检查不需要发布账号。

## 本次包范围

发布专用 README 为根目录 README.mooncakes.md。moon.mod 提供 repository，并明确仅支持 native。`.moonignore` 只允许元数据、MIT 许可证、core/runner 的 MoonBit 源码及各自 moon.pkg、runner/native_guard.c。第三方 Eigen、历史随机流、故障 fixture、命令示例、文档脚本、依赖缓存和构建产物不随库包上传；它们在 GitHub 完整工程中保留原样来源和许可。

根 README 保留完整工程安装与演示；registry README 提供发布后的安装命令和最小调用，发布前明确标为候选用法。0.1.0 是实验性模块版本，不据此宣称稳定 API。

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
