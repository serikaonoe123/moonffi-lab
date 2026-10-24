# 独立使用者复现入口

**工具链（2026-10-24）**：本页固定候选使用官方 0.10.17 版本地址及独立内容锁，Windows 七项和 Linux 云端验收通过并完成产物核对。旧版固定来源恢复、历史失败及新版精确身份见 [工具链状态](TOOLCHAIN-LOCK.md)。离线归档必须匹配所选提交的锁。

这份入口供未参与开发的人在自己的 Windows x64 或 Linux x86_64 环境中复现。此前的本机或托管 runner 成功不算独立使用者反馈。请记录你实际选择的提交、安装来源和输出；失败也保留原始结果。

## Windows 环境与源码

从带 C++ 工作负载及 Windows SDK 的 Developer PowerShell 启动 PowerShell 7.5+，确认 `git` 和 `cl` 可用。已有托管验证使用 PowerShell 7.6.6；没有验证所有 MSVC/SDK 组合。

```powershell
git clone https://github.com/serikaonoe123/moonffi-lab.git
Set-Location moonffi-lab
# 这是已通过官方 0.10.17 工具链验收的固定源码提交。
# 复现其他提交时，填写该提交完整 SHA，并另行记录其实际结果。
$candidate = 'bda5201cec5851f8221b33400fec1f01a0b58a1f'
git checkout --detach $candidate
git rev-parse HEAD
git status --short
```

此候选的 PR 合成合并提交为 `c8a728ebeb9fd6609450704bdb246fe49cffe105`，其完整 Git 源码树与候选一致；Windows 七项及 Linux 验收均通过并核对产物，见 [验收快照](evidence/toolchain-upgrade-20261024.json)。历史 rc.1 对应 `23893d5bb3a231a21df10db506d8da821a7e984d`，仍按其六项 suite 复现；新提交使用下面七项入口。旧冻结发布清单和 prepare-release 仍绑定 rc.1，不表示已为新代码生成、批准或发布新的候选包。不要用一个提交的报告代表另一个提交已经通过。

## 安装与完整验收

以下安装、证据和输出目录必须尚不存在；重试时使用新名字，保留失败目录。

```powershell
$project = (Get-Location).Path
$toolchain = Join-Path $project 'results/repro-toolchain'
& ./scripts/install-toolchain.ps1 -Destination $toolchain -Out results/repro-bootstrap
```

安装器先验证所有内容，再解包和运行。若来源不再提供锁定内容，失败就是有效结果；不要修改摘要继续。已有两份完全匹配的官方归档时，可按 [离线安装说明](TOOLCHAIN-LOCK.md) 明确指定 `-ArchiveDirectory`，在反馈中注明来源。这些工具包不随项目源码分发。

```powershell
$savedPath = $env:PATH
$savedMoonHome = $env:MOON_HOME
try {
  $env:MOON_HOME = $toolchain
  $env:PATH = (Join-Path $toolchain 'bin') + ';' + $savedPath
  & ./scripts/assert-toolchain.ps1
  & ./scripts/verify-clean.ps1 -Ref $candidate -WorkspaceTemp `
    -Suite behavior,asan,benchmark,generation,sdk,sqlite,native-errors -Out results/independent-repro
  & ./scripts/verify-script-controls.ps1 `
    -UpstreamArchive results/independent-repro/sqlite/upstream-source.zip `
    -OfflineDependencySource results/independent-repro/workspace/.mooncakes `
    -Out results/independent-controls
} finally {
  $env:PATH = $savedPath
  $env:MOON_HOME = $savedMoonHome
}
```

`-WorkspaceTemp` 让临时文件位于该次输出中，结束后恢复调用进程环境，不修改系统配置或访问控制。首次验收需要 registry 和固定 SQLite 提交源码；缓存复用须明确记录，不能写成全新下载。七项 suite 包括大量工作进程，benchmark 通常耗时最长。

全部所选验收成功才产生顶层 verification.json。另核对七个 suite 的 verification.json 及 independent-controls/verification.json；它们仍应解释具体范围，例如 SQLite 通过输入的 shrink 返回 unsupported_outcome，而不是缺陷发现。若收到权限/安全审查拒绝，停止对应动作并记录原文，不换身份或解除限制继续。

## Linux 环境与专项验收

已有云端验证使用 Ubuntu 24.04 x86_64、Python 3.12 和 GCC/G++；其他发行版或工具组合须按实际结果记录。下面只运行 Linux 普通 native/SDK 和自有故障专项，不表示与七个 Windows suite 覆盖完全等价。源码 checkout 同样固定为 `bda5201cec5851f8221b33400fec1f01a0b58a1f`，在仓库根目录执行；各输出和安装目录必须尚不存在。

```bash
python3 scripts/test_linux_toolchain.py
python3 scripts/linux_toolchain.py --destination "$PWD/results/repro-linux-toolchain" --out results/repro-linux-bootstrap
python3 scripts/verify-linux.py --toolchain "$PWD/results/repro-linux-toolchain" --ref bda5201cec5851f8221b33400fec1f01a0b58a1f --out results/repro-linux-ordinary
python3 scripts/verify-linux-native-errors.py --toolchain "$PWD/results/repro-linux-toolchain" --ref bda5201cec5851f8221b33400fec1f01a0b58a1f --dependency-source results/repro-linux-ordinary/workspace/.mooncakes/moonbitlang/async --out results/repro-linux-native-errors
```

核对 bootstrap、ordinary 和 native-errors 各自的 verification.json；失败时保留 failure.json 和原始日志。工具链内容校验、async 实际来源、临时编译参数变更和源码清单须保留。原生错误专项的 crash/ASan 各有三策略 32→2 步缩减、同位置重放、不同位置及正确实现对照；五项不稳定等控制已覆盖 crash 和 ASan 两档；ASan 弱证据控制使用合成不完整诊断，其余 ASan 控制执行真实插桩的自有故障，专项只插桩 faults.c。详见 [协议与限制](NATIVE-ERRORS.md)。

## 反馈

使用 [GitHub 复现反馈表单](https://github.com/serikaonoe123/moonffi-lab/issues/new?template=independent-reproduction.yml) 或 [本地反馈模板](templates/INDEPENDENT-REPRODUCTION.md) 记录实际提交、环境、结果和卡住的步骤。可以在本地保存，或由你选择是否向仓库提交；本脚本不会自动发消息或上传日志。最有价值的是第一次按入口执行时遇到的文档缺口和原始失败，不必只反馈成功。参与过开发/验证时注明，详见 [贡献说明](../CONTRIBUTING.md)。
