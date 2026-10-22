# Linux 普通 native 验证

本入口验证 Linux x86_64 的构建、普通单测、正确场景及独立 SDK 参数 ABI。原生故障/ASan 缩减、完整六项 Windows 验收的跨平台等价性不在本入口的成功结论中。

2026-10-22，提交 `7ccd5d67fbecf8d94c3b5477a01f17f34dc3065b` 的 [Linux CI 39709396891](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39709396891) 通过并完成产物核对：[证据](evidence/linux-ordinary-20261022.json)记录 78+7 单测、212 个项目正确场景、88 个外部 SDK 正确场景、1024 次类型参数操作及 23 项 ABI 边界。531 个导出项目文件匹配指定提交，519 个 SDK 源码输入匹配项目及依赖清单。

## 工具链

`toolchain-linux.json` 独立锁定 Linux 工具包、三个工具二进制及 core 源码身份。上述 CI 实际核对了归档、三个二进制、自报版本及 1,211 个 core 源文件；core bundling 前后身份一致。每个后续提交仍须自己的实际运行记录。

```sh
python3 scripts/linux_toolchain.py --destination /absolute/new/toolchain --out results/linux-bootstrap
python3 scripts/verify-linux.py --toolchain /absolute/new/toolchain --out results/linux-ordinary
```

需要 Linux x86_64、Python 3.11+、Git、GCC/G++ 及网络连接。默认仅下载锁中列出的官方归档；任何大小、哈希、二进制、core 或版本不匹配均停止，不执行上游安装脚本，不接受自动漂移。已保留匹配归档时，可给安装器添加 `--archive-directory /absolute/archive-directory`，证据明确标记离线来源。

官方归档中的工具文件不带执行位。内容核验后，安装器按[官方 Unix 安装步骤](https://cli.moonbitlang.com/install/unix.sh)仅为新安装目录的 `bin/*` 普通文件与 `bin/internal/tcc` 补充当前用户执行位，单独记录变更；不修改已有安装或系统目录。

## 构建与证据

驱动从指定 Git 提交导出源码，在副本中将四个 Eigen 相关包的编译/链接参数适配为 GCC/G++，并记录每个配置改动前后的哈希。先核对导入快照，C/C++ 源文件保持字节一致。[Moon 包配置说明](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html)说明了 native 编译器及链接参数。

验收要求主模块至少 78 项单测通过；Buffer/Eigen 共 212 个正确场景有完整工作进程报告；外部 SDK 7 项单测、计数器/契约/参数正确场景、1024 次类型参数操作及 23 项 ABI 边界通过。源码清单在运行前后核对，生成接口和构建缓存不当作源码输入。

成功时输出 `verification.json`；失败时输出 `failure.json` 并保留既有日志。目录必须新建，不能复用。对应 [CI 配置](../.github/workflows/linux-ordinary.yml)运行后仍须核对提交、原始报告和产物，配置存在不代表验证通过。

离线检查归档和安装边界，不执行 Linux 工具：

```sh
python3 scripts/test_linux_toolchain.py
python3 scripts/linux_toolchain.py --inspect-only --archive-directory /absolute/archive-directory --destination /absolute/new/inspection --out results/linux-inspection
```

## 只读产物审计

下载已有 CI 产物后，可独立核对运行状态、工具链内容锁、项目及 SDK 源码、编译配置、原始测试报告、正确场景和 ABI 边界：

```sh
mkdir -p results
gh run view 39709396891 --repo serikaonoe123/moonffi-lab --json headSha,status,conclusion,url > results/linux-run-metadata.json
gh run download 39709396891 --repo serikaonoe123/moonffi-lab --dir results/linux-artifacts
python3 scripts/audit-linux-ordinary.py --artifact-root results/linux-artifacts/linux-ordinary-39709396891 --run-metadata results/linux-run-metadata.json --out results/linux-audit/inspection.json
```

审计输出和参考源码目录必须是新路径。审计器只读取证据并导出指定 Git 提交，不启动测试程序。Windows 上导出时显式使用 LF 配置，导入目录的原始字节仍由 `-text` 属性保留；编译配置适配单独核对，不放宽源码哈希比较。复核及拒绝不完整/被改动证据的检查见 [审计工具证据](evidence/linux-audit-tool-20261022.json)。CI 产物按保留期过期后，需使用已下载的原始副本。

## 后续故障专项

提交 `520cf68` 的普通 native 回归已更新为 81+7 单测，并在同一独立 Linux runner 上完成 crash/ASan 各三策略 32→2 步缩减。见 [专项说明](NATIVE-ERRORS.md)和[统一证据](evidence/native-acceptance-20261022.json)。本页较早 7ccd5d6 的记录仍保持普通回归范围。
