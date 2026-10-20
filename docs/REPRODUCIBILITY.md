# Windows 自动验收与源码复现

仓库提供 `.github/workflows/windows-native.yml`。push 到 main、pull request 和手动触发分别运行 behavior、ASan、benchmark、generation、sdk、sqlite 六个任务。generation 验证 Buffer 的 512 个人工 fixture 场景，以及真实 Eigen 绑定的 192 个正确场景、保存输入重放、旧输入哈希和 CLI 边界；benchmark 默认筛选 21 个固定输入，运行三轮、三种策略的缩减。sdk 在另一个工作区中用公开 core/runner 编译教学消费者；sqlite 以原样社区绑定源码验收 48+8 单测、96 场景和九项脚本控制。任务只申请读取仓库权限，使用新 runner，不复用项目构建或依赖缓存；失败时仍上传 JSON、候选、原始日志和源码清单，不上传工作目录或二进制。首次使用请先看 [独立复现入口](INDEPENDENT-REPRODUCTION.md)。

当前已核对的运行代码基线为 `1f065527` 的 [Actions 39248905440](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440)：六项通过，68 个关键文件逐任务匹配提交归档，96 份 SQLite 输入与本地字节一致，189 次缩减与旧基准一致，见 [快照](evidence/github-ci-39248905440.json)。后续候选仍须按自身提交核对 CI。sdk 任务新增 [本地源码准备控制](RELEASE-PLAN.md)，只上传清单/日志，不上传源码 ZIP；冻结清单与发布说明不表示已发布。

工具链升级提交 `4106122` 使用固定内容的官方 0.10.16 工具链，在 [Actions run 39233803279](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39233803279) 通过五项，全部产物已下载核对。五次在线安装、11 项工具链边界、69 主模块/6 SDK 单测、704 场景、128 份历史 Eigen 输入、189 次完整缩减和 214 个真子集通过；44 个关键源文件逐任务匹配 Git 导出，189 行输入/结果哈希及结构计数与旧 Int64 本地基准一致。见 [云端快照](evidence/github-ci-39233803279.json)。本机后续通过工作区临时目录恢复 native behavior/SDK 验收，原 D8050 失败仍保留，见 [解决记录](LOCAL-WINDOWS-TEMP.md)。

## 版本与安装

`toolchain.json` 记录待验收或已验证的 moon、moonc、moonrun 版本、三个二进制摘要、core 版本及源码树身份，以及 Windows 工具包/core 归档的固定大小和 SHA-256。具体通过状态见 [验证记录](VALIDATION.md)。`scripts/assert-toolchain.ps1` 先核对二进制，再查询版本并按锁核对 core 源码文件数和整体摘要；漂移时保存诊断并失败。

CI 调用仓库内 `scripts/install-toolchain.ps1`，全部归档校验通过后才在新目录解包、查询版本并 bundle core，不执行滚动的上游安装脚本。来源仍是官方 latest URL，内容由仓库中的固定摘要锁定；地址变化后会失败，未声称已取得不可变历史下载地址。保留归档可用 `-ArchiveDirectory` 离线重装。来源确认、安装及范围见 [工具链内容锁定](TOOLCHAIN-LOCK.md)。升级时须一起更新内容身份并重新验收。

Windows runner 自带的 MSVC、Windows SDK 和全局环境不由本仓库锁定；ASan 报告保存实际运行时路径与哈希。只有查看实际云端任务、runner 镜像和验收产物后，才能记录独立环境验收成功。

## 指定提交的源码复现

先提交待验证代码，使用 PowerShell 7，在仓库根目录运行：

```powershell
& .\scripts\assert-toolchain.ps1
& .\scripts\verify-clean.ps1 -Suite behavior,asan,benchmark,generation,sdk,sqlite
```

该脚本默认导出 HEAD，可用 `-Ref <commit>` 指定另一个包含复现工具的提交。未提交修改不进入导出的源码。脚本使用 `git archive` 导出，在新目录解包，并要求没有 `.git`、`.mooncakes`、`_build` 或旧 `results`。它记录 commit、归档哈希和逐文件源码哈希，再更新 registry、恢复声明的依赖并构建。每个 suite 的输出在源码目录外，便于保留完整诊断。

已有同版本依赖源码且需要离线复验时，可明确指定来源：

```powershell
& .\scripts\verify-clean.ps1 -Suite behavior,asan,benchmark,generation,sdk,sqlite `
  -OfflineDependencySource .\.mooncakes
```

离线模式仅复制指定 async 模块的源码，排除构建目录和编译产物，校验版本并生成依赖文件哈希。源码检查使用 `--frozen`。结果标记 `dependency_mode=explicit-local-source-cache`，不能把这种运行写成从 registry 重新下载、全新安装工具链或独立机器验证。

工作区内工具以低完整性运行、不能写系统临时目录时，在上述命令中加入 `-WorkspaceTemp`。它创建 `<Out>/temp` 并只为本轮设置进程 `TEMP/TMP`，结束或失败后恢复原值；输出目录必须在项目内。验证 JSON 的 `temporary_directory` 记录实际路径，未开启时为 null。该选项不更改完整性标签、ACL、身份或系统配置，详细对照和验收见 [本机临时目录说明](LOCAL-WINDOWS-TEMP.md)。

该修复提交 `b43aad6` 的 [Actions 39239977335](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39239977335) 已通过五项默认流程，全部产物核对完成，五次 `temporary_directory=null`、驱动身份及 53 个关键文件逐任务匹配。69+6 单测、704 场景、128 历史输入、189 次缩减、63/63 重复和 214 真子集通过，见 [云端快照](evidence/github-ci-39239977335.json)。本机新选项另外通过完整 behavior/SDK 与五项恢复/拒绝控制，不将云端默认配置成功当作该选项已在云端执行。

## 输出与验证边界

`results/clean-<随机ID>/` 保存：

- `source.tar`、`source-manifest.json`：实际测试的提交及文件内容。
- `toolchain.json`、`dependency-manifest.json`：实际工具版本、二进制与依赖哈希。
- `behavior/`、`asan/`、`benchmark/`、`generation/`、`sdk/`、`sqlite/`：所选 suite 的完整证据。
- `verification.json`：只有全部所选任务成功才产生；出错则保存 `failure.json` 和阶段，保留已有文件。

CI 另保存 `bootstrap` 的归档摘要、前后工具链检查和 core bundle 日志；behavior 任务保存 11 项工具链边界检查；sqlite 任务保存九项环境/源码拒绝控制；sdk 任务保存源码候选准备控制。下载的归档、工具链目录、源码 ZIP 及故意损坏的测试二进制不上传到诊断产物。

`fresh_project_build=true` 只说明没有复制项目构建产物。脚本的 `independent_environment=false` 始终表示它自身不能证明主机、标准库或 registry 全局缓存是全新的；CI runner 的独立性须由云端执行记录补充。输出目录不可复用，不自动删除任何证据。

`host_environment` 保存操作系统、PowerShell、进程架构与可用的 GitHub runner 镜像信息；`driver_sha256` 标识实际执行复现脚本的版本。当脚本从一个仓库验证较早提交时，该脚本可能与导出源码中的脚本不同，不能仅凭 source_commit 推断驱动脚本内容。

sdk suite 的内部工作区仅包含引擎的 core/runner 与外部消费者。默认依赖恢复标记 `registry-or-tool-cache`，明确离线复验时将固定版本 async 源码作为工作区成员，标记 `explicit-local-source-cache`。包图、源码哈希、测试日志和逐次重放保存在 sdk 目录；这不等于已发布 registry 包或完成本例 C 文件的 ASan 验收。

本地实际验收使用提交 `92dd00f` 和显式依赖源码缓存，三套 suite 全部通过；结果摘要见 [验证记录](VALIDATION.md)。该结果保留了离线来源和环境边界。

2026-10-17 的 [Actions run 38994542498](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38994542498) 已在三个托管 runner 任务中完成提交 `4f46b01` 的安装、registry 依赖恢复及 behavior、ASan、benchmark 验收，全部成功。镜像为 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6，三个任务的依赖日志均记录下载 async 0.22.5。安装器 SHA-256 为 `A5101E91FFA9905FB25CD009B9A4AA942971A294BD055C89836E3AF89B710C64`。产物已下载核对，结构化摘要见 [云端证据快照](evidence/github-ci-38994542498.json)。

随后 [Actions run 38997018833](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38997018833) 在相同镜像和 PowerShell 版本上通过提交 `ee6bb3a` 的四项验收，新增 generation，32 单测与 512 场景均通过；四份产物的源码归档哈希一致，依赖恢复与版本闸门通过。见 [状态探索版本云端快照](evidence/github-ci-38997018833.json)。该提交的 benchmark 为九例单轮，后续 21 例三轮版本需按其自身提交的运行记录判断。

早期本地安装器下载曾被套接字权限拒绝，经批准的诊断请求又遇到传输 EOF；这些历史失败保留，云端安装成功不改变其记录。本轮下载在保持 TLS 校验的 Git/OpenSSL curl 下成功，固定内容已核对；latest 地址本身仍非不可变来源。已验证范围须按实际提交和运行判断。
