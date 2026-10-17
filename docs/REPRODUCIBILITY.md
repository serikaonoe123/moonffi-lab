# Windows 自动验收与源码复现

仓库提供 `.github/workflows/windows-native.yml`。push 到 main、pull request 和手动触发会分别运行 behavior、ASan、benchmark 三个任务。任务只申请读取仓库权限，使用新 runner，不复用项目构建或依赖缓存；失败时仍上传 JSON、候选、原始日志和源码清单。归档不含工作目录或二进制。

## 版本与安装

`toolchain.json` 记录当前实际验证过的 moon、moonc、moonrun 版本及 async 版本。`scripts/assert-toolchain.ps1` 要求三个工具的版本字符串完全匹配，并记录可执行文件 SHA-256；不匹配时写出诊断并失败。

CI 使用 [MoonBit 官方安装入口](https://www.moonbitlang.com/download/)，通过 `MOONBIT_INSTALL_VERSION` 选择版本。当前配置为 `latest`，随后运行严格的版本检查。这是检测版本漂移的闸门，不是历史安装包或安装脚本的不可变锁定。历史安装标识和包哈希尚未联网确认，因此没有臆造一个日期版本 URL。安装器哈希保存在 CI 的 bootstrap 诊断中。将来升级工具链时，需要一起更新版本记录并重新验收。

Windows runner 自带的 MSVC、Windows SDK 和全局环境不由本仓库锁定；ASan 报告保存实际运行时路径与哈希。只有查看实际云端任务、runner 镜像和验收产物后，才能记录独立环境验收成功。

## 指定提交的源码复现

先提交待验证代码，使用 PowerShell 7，在仓库根目录运行：

```powershell
& .\scripts\assert-toolchain.ps1
& .\scripts\verify-clean.ps1 -Suite behavior,asan,benchmark
```

该脚本默认导出 HEAD，可用 `-Ref <commit>` 指定另一个包含复现工具的提交。未提交修改不进入导出的源码。脚本使用 `git archive` 导出，在新目录解包，并要求没有 `.git`、`.mooncakes`、`_build` 或旧 `results`。它记录 commit、归档哈希和逐文件源码哈希，再更新 registry、恢复声明的依赖并构建。每个 suite 的输出在源码目录外，便于保留完整诊断。

已有同版本依赖源码且需要离线复验时，可明确指定来源：

```powershell
& .\scripts\verify-clean.ps1 -Suite behavior,asan,benchmark `
  -OfflineDependencySource .\.mooncakes
```

离线模式仅复制指定 async 模块的源码，排除构建目录和编译产物，校验版本并生成依赖文件哈希。源码检查使用 `--frozen`。结果标记 `dependency_mode=explicit-local-source-cache`，不能把这种运行写成从 registry 重新下载、全新安装工具链或独立机器验证。

## 输出与验证边界

`results/clean-<随机ID>/` 保存：

- `source.tar`、`source-manifest.json`：实际测试的提交及文件内容。
- `toolchain.json`、`dependency-manifest.json`：实际工具版本、二进制与依赖哈希。
- `behavior/`、`asan/`、`benchmark/`：所选 suite 的完整证据。
- `verification.json`：只有全部所选任务成功才产生；出错则保存 `failure.json` 和阶段，保留已有文件。

`fresh_project_build=true` 只说明没有复制项目构建产物。脚本的 `independent_environment=false` 始终表示它自身不能证明主机、标准库或 registry 全局缓存是全新的；CI runner 的独立性须由云端执行记录补充。输出目录不可复用，不自动删除任何证据。

`host_environment` 保存操作系统、PowerShell、进程架构与可用的 GitHub runner 镜像信息；`driver_sha256` 标识实际执行复现脚本的版本。当脚本从一个仓库验证较早提交时，该脚本可能与导出源码中的脚本不同，不能仅凭 source_commit 推断驱动脚本内容。

本地实际验收使用提交 `92dd00f` 和显式依赖源码缓存，三套 suite 全部通过；结果摘要见 [验证记录](VALIDATION.md)。该结果保留了离线来源和环境边界。

2026-10-17 的 [Actions run 38994542498](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38994542498) 已在三个托管 runner 任务中完成提交 `4f46b01` 的安装、registry 依赖恢复及 behavior、ASan、benchmark 验收，全部成功。镜像为 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6，三个任务的依赖日志均记录下载 async 0.22.5。安装器 SHA-256 为 `A5101E91FFA9905FB25CD009B9A4AA942971A294BD055C89836E3AF89B710C64`。产物已下载核对，结构化摘要见 [云端证据快照](evidence/github-ci-38994542498.json)。

早期本地安装器下载曾被套接字权限拒绝，经批准的诊断请求又遇到传输 EOF；这些历史失败保留，云端安装成功不改变其记录。已验证的范围是该提交、该 runner 镜像及其工具链，不把 latest 入口视作不可变安装包锁定。
