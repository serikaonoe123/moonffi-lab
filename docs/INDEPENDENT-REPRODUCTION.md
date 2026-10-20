# 独立使用者复现入口

这份入口供未参与开发的人在自己的 Windows x64 环境中复现。此前的本机或托管 runner 成功不算独立使用者反馈。请记录你实际选择的提交、安装来源和输出；失败也保留原始结果。

## 环境与源码

从带 C++ 工作负载及 Windows SDK 的 Developer PowerShell 启动 PowerShell 7.5+，确认 `git` 和 `cl` 可用。已有托管验证使用 PowerShell 7.6.6；没有验证所有 MSVC/SDK 组合。

```powershell
git clone https://github.com/serikaonoe123/moonffi-lab.git
Set-Location moonffi-lab
# 这是本轮已通过六项验收及源码准备控制的候选代码提交。
# 审阅其他候选时，改成其 candidate.json 记录的完整提交。
$candidate = '23893d5bb3a231a21df10db506d8da821a7e984d'
git checkout --detach $candidate
git rev-parse HEAD
git status --short
```

旧运行基线 1f065527 没有本轮新增的 prepare-release 脚本；上面的新候选包含冻结清单和准备脚本。不要用一个提交的报告代表另一个提交已经通过。

## 安装与完整验收

以下安装、证据和输出目录必须尚不存在；重试时使用新名字，保留失败目录。

```powershell
$project = (Get-Location).Path
$toolchain = Join-Path $project 'results/repro-toolchain'
& ./scripts/install-toolchain.ps1 -Destination $toolchain -Out results/repro-bootstrap
```

安装器先验证所有内容，再解包和运行。若官方 latest 内容已变化，失败就是有效结果；不要修改摘要继续。已有两份完全匹配的官方归档时，可按 [离线安装说明](TOOLCHAIN-LOCK.md) 明确指定 `-ArchiveDirectory`，在反馈中注明来源。这些工具包不随项目源码分发。

```powershell
$savedPath = $env:PATH
$savedMoonHome = $env:MOON_HOME
try {
  $env:MOON_HOME = $toolchain
  $env:PATH = (Join-Path $toolchain 'bin') + ';' + $savedPath
  & ./scripts/assert-toolchain.ps1
  & ./scripts/verify-clean.ps1 -Ref $candidate -WorkspaceTemp `
    -Suite behavior,asan,benchmark,generation,sdk,sqlite -Out results/independent-repro
  & ./scripts/verify-script-controls.ps1 `
    -UpstreamArchive results/independent-repro/sqlite/upstream-source.zip `
    -OfflineDependencySource results/independent-repro/workspace/.mooncakes `
    -Out results/independent-controls
} finally {
  $env:PATH = $savedPath
  $env:MOON_HOME = $savedMoonHome
}
```

`-WorkspaceTemp` 让临时文件位于该次输出中，结束后恢复调用进程环境，不修改系统配置或访问控制。首次验收需要 registry 和固定 SQLite 提交源码；缓存复用须明确记录，不能写成全新下载。六项 suite 包括大量工作进程，benchmark 通常耗时最长。

全部所选验收成功才产生顶层 verification.json。另核对六个 suite 的 verification.json 及 independent-controls/verification.json；它们仍应解释具体范围，例如 SQLite 通过输入的 shrink 返回 unsupported_outcome，而不是缺陷发现。若收到权限/安全审查拒绝，停止对应动作并记录原文，不换身份或解除限制继续。

## 反馈

使用 [GitHub 复现反馈表单](https://github.com/serikaonoe123/moonffi-lab/issues/new?template=independent-reproduction.yml) 或 [本地反馈模板](templates/INDEPENDENT-REPRODUCTION.md) 记录实际提交、环境、结果和卡住的步骤。可以在本地保存，或由你选择是否向仓库提交；本脚本不会自动发消息或上传日志。最有价值的是第一次按入口执行时遇到的文档缺口和原始失败，不必只反馈成功。参与过开发/验证时注明，详见 [贡献说明](../CONTRIBUTING.md)。
