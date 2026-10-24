# 工具链归档内容锁定

**在线安装状态（2026-10-24）**：本轮 [Windows CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40052187741) 和 [Linux CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/40052187610) 在归档内容校验阶段被拒绝，均未接受或执行下载的工具包，尚未进入业务验收。现有官方滚动地址无法提供本锁要求的内容；该报错不证明下载内容的具体版本。已有完全匹配的自有归档可按下文离线入口安装。恢复云端验证需要取得原锁内容，或独立评估新工具链、建立新锁并完成兼容性验收。

2026-10-17 将 CI 的“下载并执行滚动安装器，再检查版本”改为项目内安装脚本：按 `toolchain.json` 的固定字节数与 SHA-256 核验 Windows x64 工具包和 core 归档，全部通过后才解包和运行工具。安装到新目录，不覆盖用户已有安装，不改全局 PATH 或执行策略；成功与失败都恢复调用进程的 PATH、MOON_HOME 和工作目录。

这是**内容锁定**。来源仍是官方 `latest` URL，不能保证未来继续提供这份内容；变化时安装会失败，不自动接受新版本。历史版本地址本轮没有取得成功响应，没有把猜测的日期或版本 URL 写入配置。保留的原始归档可以通过 `-ArchiveDirectory` 离线重装；仓库和 CI 诊断产物不包含这两个归档。

## 当前开发锁（2026-10-21）

状态契约提交 0eae789 的 [六项 CI 39587481441](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39587481441) 在下载包身份检查阶段全部拒绝，接受归档为零，业务测试未运行；见 [失败快照](evidence/github-ci-39587481441-failed-bootstrap.json)。再次从官方校验清单核对新归档与三个关键二进制，在新目录 results/toolchain-review-20261021/installed-windows 安装；旧安装、旧锁对应的提交和失败证据保留。原安装器和拒绝规则保持不变。

新包的 moon / moonrun 自报 0.1.20261020 (2284bd2)，moonc 仍为 v0.10.16+b1a0e846e。编译器二进制、core 版本和 1,211 份源码树身份与 10 月 19 日安装相同，core ZIP 字节因归档变化而不同；不将构建器升级误写成编译器 0.10.17。core 仍按官方 HTTPS 下载后的实测摘要锁定，没有独立官方 core 校验文件。

| 当前内容 | 字节数 / 文件数 | SHA-256 |
|---|---:|---|
| Windows x64 zip | 91,097,881 字节 | `50183A36DACDFB47919DFFA5F06B9340B343506236940832215604E277D3F001` |
| core zip | 2,606,935 字节 | `C9C1FA97797BDACCB51AC5632581DC76C5D03B1DCE8309323137F021982E5EAC` |
| core 源码树 | 1,211 文件 | `B26E8FD3F8F9E5CDA9FE2A352A5D795870E416F133B7A3ED4001DBF2B81AD915` |

隔离安装及 11 项拒绝边界、73 主模块 native 单测、7 SDK 单测与完整契约验收通过；见 [本地快照](evidence/toolchain-refresh-20261021.json)。新锁提交 7778f157 的 [六项 CI 39604001946](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39604001946) 全部成功且产物核对完成，见 [云端快照](evidence/github-ci-39604001946.json)。首次根模块检查因新安装没有 registry 索引而失败，按正常 moon update 恢复索引后重新验证，保留首次日志；依赖版本仍是 async 0.22.5。

## 先前已验收内容（2026-10-19，历史记录）

用户随后明确允许使用新工具链，当前锁定并已在云端验收 moon 0.1.20261016 (1af328f)、moonc v0.10.16+b1a0e846e，取代保留旧锁的决定。只在新的 `results/toolchain-upgrade-20261019/installed` 安装，保留原安装与旧失败证据。当前工具包和三个关键二进制已核对[官方归档清单](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip.sha256)及[二进制清单](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.sha256)；core 仍来自官方 HTTPS，摘要为下载后实测，版本与新编译器一致，不声称取得了 core 的独立官方校验文件。

这里的 0.10.16 来自实际编译器版本输出，不是从 moonbit-docs 仓库的标签推定，也不据此宣称最新正式发行版。项目版本 0.1.0、moon 构建版本 0.1.20261016 与 moonc 版本各自独立，复现以内容锁和实际回报为准。

| 当前内容 | 字节数 / 文件数 | SHA-256 |
|---|---:|---|
| Windows x64 zip | 90,915,394 字节 | `653EBF0A3B2683048FAA8AD79B7B7D0721BF78726BF1A7E58678E9740B0D430F` |
| core zip | 2,606,935 字节 | `D58CAF5EE6E2A95D8785ADF7D90FD68DD9366D174DF1DFAA36646DD6B47C5663` |
| core 源码树 | 1,211 文件 | `B26E8FD3F8F9E5CDA9FE2A352A5D795870E416F133B7A3ED4001DBF2B81AD915` |

隔离安装、bundle、静态检查及 11 项安装拒绝边界通过。最终提交 `4106122` 的 [Actions 39233803279](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39233803279) 五项全部成功，五次官方在线安装身份一致，产物已核对，见 [最终快照](evidence/github-ci-39233803279.json)。本机初期 C 编译的 D8050 后续通过 `verify-clean.ps1 -WorkspaceTemp` 解决，69+6 单测及完整 behavior/SDK 通过，详见 [解决记录](LOCAL-WINDOWS-TEMP.md)；保留[原升级快照](evidence/toolchain-upgrade-20261019.json)。现有安装器和执行前校验继续使用固定身份；本次临时目录修复没有修改工具链锁或二进制。

## 2026-10-19：旧锁因滚动下载内容变化而阻塞（历史记录）

Int64 实现提交 `e7dd774` 的 [Actions 39216392303](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39216392303) 五项均在 `verify-archives` 拒绝 Windows 工具包，接受归档数为零，未解包或执行下载工具，尚未开始云端业务验收。只读取得的当前[官方归档校验文件](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip.sha256)为 `653EBF0A3B2683048FAA8AD79B7B7D0721BF78726BF1A7E58678E9740B0D430F`，已与下表原锁不同；失败报告没有提供 CI 实际拒绝内容的摘要或字节数，不将其版本或身份视为已确认。

保留的原始本地归档仍匹配原锁，本轮本地验证使用原工具链。用户明确选择“保留当前锁，记录 CI 阻塞”：不修改锁定值、安装校验或 CI 配置，不升级。失败证据见 [快照](evidence/github-ci-39216392303.json)，此前通过的云端运行仅作为历史记录。

后续只读评估已整理为 [原版本 CI 恢复方案](TOOLCHAIN-CI-RECOVERY.md)：归档身份仍匹配，现有离线安装接口可复用；完整 Windows 工具包的再分发依据尚待确认。候选存储和接入步骤仅供审阅，没有上传归档或改变 CI。

## 初始锁定内容与来源（2026-10-17，历史记录）

| 内容 | 字节数 / 文件数 | SHA-256 |
|---|---:|---|
| Windows x64 zip | 91,640,641 字节 | `6E3EF6CB96AA5086D122183972687F79FC912F80652000907D96EE6AD967E3BF` |
| core zip | 2,529,648 字节 | `05556B27B156348950EA88AE6838032C8B478AE532B18B3929387D1DA4C18D55` |
| core 源码树 | 1,201 文件 | `6D80301068B8870D314E8AAFCC9ADCD439162E93AD9D59E150FF2DDDA890C49B` |

2026-10-17 锁定时，Windows zip 的摘要已与[官方归档校验文件](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip.sha256)核对。三个工具的摘要与当时的[官方二进制清单](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.sha256)及原有安装均一致。core 地址来自[官方安装脚本](https://cli.moonbitlang.com/install/powershell.ps1)；锁定时未取得 core 的单独官方校验文件，配置采用 HTTPS 下载后实测的归档摘要。core 版本 `0.10.15+943464bfa`、全部源码的整体摘要也与原有安装一致。官方校验方法见[下载说明](https://www.moonbitlang.com/download/#verifying-binaries)。

源码树摘要按相对路径作 ordinal 排序，将每个文件的“路径 + TAB + 大写 SHA256 + LF”以 UTF-8 编码后再取 SHA256；包括隐藏源码文件，排除 core 根目录的 `_build/` 与 `.mooncakes/`。先核对工具二进制，再执行版本查询；解包后和 bundle 后均核对版本、三个工具及 core 源码身份。生成的 core bundle 从这些输入重新构建，不承诺其逐字节相同。

## 安装和使用

使用 PowerShell 7。目标安装目录和证据目录都必须不存在：

```powershell
$locked = 'D:\moonbit\toolchains\moonffi-20261016'
& .\scripts\install-toolchain.ps1 -Destination $locked
# 仅当前终端使用它
$env:MOON_HOME = $locked
$env:PATH = (Join-Path $locked 'bin') + ';' + $env:PATH
& .\scripts\assert-toolchain.ps1
moon update
& .\scripts\verify.ps1
```

新的 MOON_HOME 没有旧注册表，需要先 `moon update`。该索引及 async 依赖不属于两个工具链归档；不能将恢复依赖与安装工具链混为一项成功。

离线安装要求目录中有完整的 `moonbit-windows-x86_64.zip` 和 `core-latest.zip`，二者都必须与锁定摘要匹配。缺失时立即失败，不转为网络下载：

```powershell
& .\scripts\install-toolchain.ps1 -Destination D:\moonbit\toolchains\moonffi-offline `
  -ArchiveDirectory D:\moonbit\saved-toolchain-archives
```

默认证据目录为新的 `results/bootstrap-<ID>`。可用 `-Out` 明确指定；其中保存接受的归档身份、bundle 日志、前后检查报告及成功/失败阶段。网络模式将归档保存在其 `downloads/` 下；离线模式不会改动源归档。没有自动清理失败目录。

## 验证与范围

`scripts/verify-toolchain.ps1` 在给定安装和本地归档上进行 11 项检查：正确安装、第二份归档损坏后仍不解包、离线缺失不回退网络、越界归档路径、不安全 URL、缺失二进制摘要、版本漂移、执行前发现二进制漂移、版本不变的 core 源码漂移、已有安装及已有证据保留。探针仅在新结果目录中制造错误输入，最后检查进程环境恢复。

CI 当前六项 suite 均先创建内容锁定的独立工具链，behavior 任务额外运行上述边界检查；诊断只上传 JSON 和日志，不上传下载归档、工具目录或边界测试的复制二进制。整体工程、原生内存及 SDK 验收仍按 [复现指南](REPRODUCIBILITY.md) 执行。

[Actions run 39014758043](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39014758043) 对 `00712a7` 的五项验收通过；五份产物已下载核对，均从官方在线取得同一份锁定内容，bundle 前后 core 身份一致。11 边界、43 主模块/5 SDK 单测、704 场景、189 次完整缩减、63 组重复一致和 214 个真子集通过，见 [云端快照](evidence/github-ci-39014758043.json)。

核对旧实验时发现六个合成输入的 environment 字段顺序未固定，导致 54 行记录的输入/结果字节哈希不同；全部 21 个输入和 189 个缩减轨迹在仅规范化该对象的键顺序后相等，结构计数与指纹均相同。后续将合成 environment 改为 ordered；单独的[字节确定性验证](evidence/benchmark-json-order-20261017.json)记录了两个独立进程生成相同输入的检查。原始差异及预算终止记录均保留。

修正提交 `2b7f92c3272e154b2d3c9d488d6f20418259e6e0` 的 [Actions run 39015558264](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39015558264) 五项再次通过。全部产物已核对：五次在线安装身份一致，11 边界与 43+5 单测、704 场景通过；189 次缩减全部完成，63 组重复一致，214 个真子集通过。全部 189 行输入/结果字节哈希和结构指标与旧基准一致，不再需要规范化 JSON 键顺序才能比较。见 [最终云端快照](evidence/github-ci-39015558264.json)，完整下载在 `results/github-ci-39015558264`。

本轮不锁定 Windows runner 镜像、MSVC、Windows SDK、GitHub Actions 的版本标签或 registry 内容，也不声明完整的密闭构建、供应商签名验证或任意时间均可从上游恢复历史工具链。来源 URL 和摘要同时变更时，需要重新核对来源并运行当前六项验收。
