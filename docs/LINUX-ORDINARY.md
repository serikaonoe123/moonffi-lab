# Linux 普通 native 验证

本入口验证 Linux x86_64 的构建、普通单测、正确场景及独立 SDK 参数 ABI。原生故障/ASan 缩减、完整六项 Windows 验收的跨平台等价性不在本入口的成功结论中。

## 工具链

`toolchain-linux.json` 独立锁定 Linux 工具包、三个工具二进制及 core 源码身份。保留归档的内容检查已完成；Linux 实际自报版本与运行结果仍须由本平台验证。

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
