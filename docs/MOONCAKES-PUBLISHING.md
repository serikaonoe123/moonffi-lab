# Mooncakes 发布与复现

2026-10-30 已公开发布 [serikaonoe123/moonffi-lab@0.1.0](https://mooncakes.io/docs/serikaonoe123/moonffi-lab)。公开版本 metadata、实际下载 ZIP 与 32 份安装文件均匹配批准内容，全新 Windows 消费者的 native SDK 与 README 最小例通过，验收指南第 8 项已完成，见 [发布快照](evidence/mooncakes-0.1.0-20261030.json)。既有 GitHub rc.1/rc.2 标签、附件和冻结门槛保持原义。

## 0.1.0 发布验收

已发布源码固定为 `ab41b683ce199bda2ac47f8e8792e744e5f71b8d`，ZIP 为 45,277 字节、32 文件，SHA-256 `BFB879EF357DC4700CB665DAE7C3BB6D44A93D9DEC9993584312D2D5B43BD95D`；[包身份与清单](releases/mooncakes-0.1.0.json)独立保存。该候选在源码树一致的 checkout `0f95853` 完成 Windows 七项、Linux native、归档消费者和 17 项冻结发布控制；十份诊断归档摘要、大小及原始结果已核对。账号确认前的旧候选仅包内 README 与最终版本不同。

正式发布前匿名查询版本不存在并复核账号与全部包字节。首次上传前检查因本机索引缺失停止；恢复官方索引后，`publish --frozen` 又因新建验收目录无法安装依赖停止。保留两次记录后，在独立目录恢复精确 async 0.22.5，编译及 frozen 打包仍匹配原摘要，再通过官方默认 `moon publish` 完成完整解包、依赖和编译验收后上传。

实际 registry 消费者没有本地引擎成员，下载前没有该 engine archive 缓存；真实下载后复核 ZIP 和全部安装文件。首次 C 编译出现 MSVC D8050，保留记录并采用项目内 TEMP/TMP 后，全新消费者重新从 registry 下载并通过 7 项 SDK 单测、契约/重放、1024 次 C FFI 操作及 23 项 ABI 边界。原源码工作区 SDK 模式也已回归。此轮 registry 安装验证为当前 Windows 主机；Linux 的既有源码验收与独立使用者反馈分别记录。

## 复现真实 registry 消费者

在锁定工具链、MSVC 及可写 TEMP/TMP 环境下，从仓库根目录运行，输出目录须尚不存在：

```powershell
pwsh -NoProfile -File scripts/verify-sdk.ps1 -Out ../moonffi-registry-sdk-check -RegistryPackage docs/releases/mooncakes-0.1.0.json
```

该入口只创建消费者工作区成员，通过 registry 解析引擎，匹配批准 ZIP 与全部源文件，再运行完整 SDK 路径。报告的 `registry_engine.archive_cached_before` 明确区分首次下载与 archive 缓存命中；本轮正式验收为 false，重复运行若命中缓存不能再次称为首次下载。README 的原始安装命令及两段最小代码也已独立运行成功；数组打印会有 Show 弃用提示，退出码为 0。

## Linux registry 消费者维护入口（2026-10-31）

新增 Linux x86_64 专用入口，从指定 Git 提交导出测试驱动，但不把仓库引擎或 async 加入消费者工作区。它要求下载前没有该引擎 ZIP 缓存，通过 registry 解析并核对模块树、批准 ZIP、全部 32 份源文件；执行前后均检查包内容。执行范围为 7 项 SDK 单测、88 个正确场景、1024 次类型参数 C FFI 操作及 23 项 ABI 边界，与既有源码 SDK 检查共用驱动。

```bash
python3 scripts/test_registry_consumer.py
python3 scripts/linux_toolchain.py --destination "$PWD/results/registry-linux-toolchain" --out results/registry-linux-bootstrap
python3 scripts/verify-linux-registry.py --toolchain "$PWD/results/registry-linux-toolchain" --ref HEAD --out results/registry-linux-consumer
```

安装和输出目录必须尚不存在；工具链内容锁保持不变，async 要求从 registry 解析为 0.22.5。9 项离线控制已本地及云端通过。候选 `8c67523` 在源码树一致的 PR checkout `ed8c632` 完成真实 Linux 下载与全部上述检查；归档大小/摘要、四份驱动、14 份消费者输入、88 份原始正确报告及 ABI 边界已核对，见 [Linux registry 证据](evidence/linux-registry-consumer-20261031.json)。这是该候选的托管 Linux 消费者结果，与 0.1.0 发布时的 Windows 验收、源码 Linux 回归及独立使用者反馈分别记录。

`Mooncakes package preflight` 在 PR、main push 及手动触发时分别执行归档消费者和 Linux registry 消费者，并保存 JSON/日志，不上传消费者或工具链工作区。此入口不发布新版本，也不执行原生错误/ASan 缩减；既有专项仍由原 Linux CI 验收。

## 账号确认前的准备验收

候选 `e4ca0fafc08b75237f59fba0714d6e61645a42a8` 在源码树一致的 PR checkout `960933f` 完成 [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558109)、[Linux](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558243)、[实际归档消费者](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558261)和 [17 项冻结发布控制](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40999558111)，十份诊断归档及原始记录已核对，见 [准备证据](evidence/mooncakes-preparation-20261030.json)。Windows 每项 571 文件匹配，189 次 benchmark 结构指标和具体结果字节与旧基准一致。

本地当时的 ZIP 为 45,488 字节、32 文件，SHA-256 `1D9F15C0D55CB6860603586B971A41A3E0F9A9011B63E7CBA6338C0A539CBC99`。云端清单逐文件匹配 Git，报告的 ZIP 摘要与本地相同，29 份引擎输入来自该归档；SDK 7 单测、1024 次真实 C FFI 操作和 23 项 ABI 边界通过。此摘要仅对应账号确认前的候选说明；最终 README 定稿后已另行生成上述 45,277 字节包和发布验收，旧记录不作为新归档的结果。

首轮本地预检拒绝不被锁定构建器支持的 homepage 字段；首轮云端预检因索引恢复后未安装依赖，被 frozen 检查正确拒绝。记录均保留。修订先正常执行依赖检查，再保持 frozen 打包并核对 async 0.22.5；文件集合、Git 字节和旧发布门槛保持原约定。该早期阶段仅验证归档消费，真实 registry 验收见上方 0.1.0 记录。

## 注册与登录

本轮账号注册、用户名确认及本机登录均已完成。后续维护者按 [官方账号说明](https://docs.moonbitlang.com/en/stable/toolchain/moon/package-manage-tour.html#setup-mooncakes-io-account)用 `moon login` 在本机登录；本项目使用锁定工具链所在的 MOON_HOME。登录 token 不进入源码、CI 配置或聊天。公开包消费者及源码打包检查不需要发布账号。

## 本次包范围

发布专用 README 为根目录 README.mooncakes.md。moon.mod 提供 repository，并明确仅支持 native。`.moonignore` 只允许元数据、MIT 许可证、core/runner 的 MoonBit 源码及各自 moon.pkg、runner/native_guard.c。第三方 Eigen、历史随机流、故障 fixture、命令示例、文档脚本、依赖缓存和构建产物不随库包上传；它们在 GitHub 完整工程中保留原样来源和许可。

根 README 保留完整工程安装与演示，并链接已发布库包；registry README 面向包使用者，提供安装命令和最小调用，不随包携带账号注册或内部准备记录。0.1.0 是实验性模块版本，不据此宣称稳定 API。

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

本轮 0.1.0 已按具体授权完成。后续版本仍须确认账号、未占用的新版本、最终源码提交、文件清单/摘要及线上权限，并通过对应 Windows/Linux CI 与 package preflight，再取得新版本的具体发布确认；检查脚本不自动执行上传，也不覆盖已有版本。

发布后在仓库/源码工作区之外建立全新消费者，不提供本地引擎成员、不复用本地 engine 缓存，通过 registry 安装指定版本。核对依赖解析树、下载来源和核心源码身份，再运行相同的 native SDK 行为/契约/FFI 路径。只有包页面可访问且这一轮安装/运行通过，才能将验收指南第 8 项计为已完成。独立使用者反馈不是该指南列明的硬性条件，已过初审无需再提交表格。
