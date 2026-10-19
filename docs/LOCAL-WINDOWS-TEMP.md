# 本机 MSVC D8050 与工作区临时目录

2026-10-19，在不改变 Windows 完整性标签、ACL、执行策略或锁定工具二进制的前提下，已恢复本机 MoonBit 0.10.16 的 native 验证。复现入口是 `scripts/verify-clean.ps1 -WorkspaceTemp`。

## 原因与对照

只读检查发现，工作区内的 `moon.exe` 和自写最小进程启动程序继承了 Low Mandatory Level，系统临时目录则没有低完整性标签。诊断程序查询自身令牌得到完整性 RID `4096`（Low）；通过正式审批启动它也不会把它变成中完整性进程。

同一个诊断程序、同一条 MSVC `/Z7` 编译命令，在继承原 `TEMP/TMP` 时退出 2，报告 D8050；仅将这两个进程环境变量指向工作区内新目录后退出 0，令牌仍为 Low。直接从 PowerShell 启动同一编译命令成功。路径形式、工作目录、引号、进程组、标准句柄和窗口标记的其他对照未解决故障，原始失败保留。

这与 [Microsoft 的强制完整性控制说明](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control)一致：低完整性进程不能写中完整性对象；没有完整性标签的对象按中完整性处理；启动进程的完整性不高于可执行文件的完整性。没有据此将文件标签的来源归因于某个尚未确认的设置。

## 复现

在 PowerShell 7 中选择与 `toolchain.json` 匹配的安装后运行：

```powershell
Set-Location D:\moonbit\moonffi-lab
& .\scripts\assert-toolchain.ps1
& .\scripts\verify-clean.ps1 -WorkspaceTemp -Suite behavior,sdk `
  -OfflineDependencySource .\.mooncakes
```

`-OfflineDependencySource` 明确复用现有的 async 0.22.5 源码缓存；没有该缓存时省略此参数，按原流程恢复依赖。`-Out` 仍可指定一个尚不存在的目录；使用 `-WorkspaceTemp` 时该目录必须在项目内。脚本把本次 `TEMP/TMP` 设为 `<Out>/temp`，所有子进程继承，成功或抛错后均恢复调用者原值，包括变量原先不存在的情况。临时目录与失败日志保留，不自动删除。成功及失败 JSON 记录实际临时目录；没有使用该选项时记录为 null。

默认行为和 CI 不会自动改用这个选项。它只改变临时文件的位置，不改变完整性、身份或访问控制；权限或安全审查拒绝仍须报告并停止对应操作。

使用干净源码导出还有另一个原因：本机 `results` 内保存了部分历史源码快照，其中有 `moon.pkg` 却没有完整源文件。直接在原根目录运行全包测试会把这些快照识别为包，并因缺少 `buffer.c` 退出。该失败日志在 `results/local-msvc-recovery-20261019`，没有删除历史证据来掩盖它。`verify-clean.ps1` 从指定 Git 提交导出源码，避免把这些诊断目录当成产品包。

## 验收与证据

完整记录见 [本地恢复快照](evidence/local-msvc-temp-20261019.json)。最终通过新选项验证的源码为提交 `c53a019`，使用本轮修改的验证驱动；运行前后驱动哈希一致，调用者环境与工作目录恢复。

- 69/69 主模块单测和完整 behavior：包括 21 组 Int64 探针、1,701 次缩减/预算执行及 36 次独立对照；既有正常、人工失败、缩减、重放、崩溃、超时和预算验收通过。
- 6/6 SDK 单测及独立消费者验收：768 条纯 oracle、128 个修整子集、32 条 native 单测 walk、8+32 个正确场景、失败缩减和修复后重放通过。
- 当时五项恢复/拒绝检查覆盖已有输出、项目外输出及默认路径；其中名为“原环境不存在”的准备代码实际生成了空字符串，因此不能证明真正缺失变量的恢复。原始证据保留；后续修正和九项控制见下文。

原始对照在 `results/toolchain-upgrade-20261019/msvc-probe`；最终主模块/SDK 验收在 `results/local-msvc-workspace-final-20261019`；新选项的独立 SDK 验收和控制分别在 `results/local-msvc-temp-option-sdk-20261019`、`results/local-msvc-temp-controls-20261019`。

后续 SQLite 接入发现 PowerShell 会将 `[Environment]::SetEnvironmentVariable(name, $null, 'Process')` 的 null 转为空字符串，导致缺失变量未被真正移除。现使用 `[NullString]::Value` 恢复缺失状态，保留显式空字符串。[官方环境变量说明](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5)描述了该差异。`scripts/verify-script-controls.ps1` 对 verify-clean 与 verify-sqlite 分别验证存在、真正缺失和空字符串，另检查归档哈希与已有输出，共九项通过。当前记录在 `results/script-controls-accepted-20261019` 和 [SQLite 快照](evidence/sqlite-external-20261019.json)；早期恢复记录不据此改写为当时已覆盖缺失状态。

首轮手动设置工作区临时目录的 behavior/SDK 验收也通过，保存在 `results/local-msvc-clean-recovery-20261019`。该轮运行期间驱动文件被加入新选项，原脚本在结束时读取到修改后的文件哈希，因此该字段不能证明其已执行新选项；最终验收单独固定前后哈希并通过真实选项调用，未用首轮记录替代。

本轮未重跑本机 ASan、benchmark 和 generation；这些范围的既有云端通过证据仍按各自提交与运行记录解释。本地离线源码复用不等于独立主机或全新 registry 下载。

修复提交 `b43aad6` 已推送，[Actions 39239977335](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39239977335) 五项全部通过并下载核对产物，见 [云端快照](evidence/github-ci-39239977335.json)。53 个关键文件逐任务匹配 Git 导出，五次驱动身份核对通过，默认 `temporary_directory=null`；此次云端是未开启选项的回归，不能替代前述本机新选项验收。704 场景、128 份历史输入及 189 次缩减与原基准一致，63/63 组重复、214 真子集及全部正确实现重放通过。
