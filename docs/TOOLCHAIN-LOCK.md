# 工具链归档内容锁定

2026-10-17 将 CI 的“下载并执行滚动安装器，再检查版本”改为项目内安装脚本：按 `toolchain.json` 的固定字节数与 SHA-256 核验 Windows x64 工具包和 core 归档，全部通过后才解包和运行工具。安装到新目录，不覆盖用户已有安装，不改全局 PATH 或执行策略；成功与失败都恢复调用进程的 PATH、MOON_HOME 和工作目录。

这是**内容锁定**。来源仍是官方 `latest` URL，不能保证未来继续提供这份内容；变化时安装会失败，不自动接受新版本。历史版本地址本轮没有取得成功响应，没有把猜测的日期或版本 URL 写入配置。保留的原始归档可以通过 `-ArchiveDirectory` 离线重装；仓库和 CI 诊断产物不包含这两个归档。

## 固定内容与来源

| 内容 | 字节数 / 文件数 | SHA-256 |
|---|---:|---|
| Windows x64 zip | 91,640,641 字节 | `6E3EF6CB96AA5086D122183972687F79FC912F80652000907D96EE6AD967E3BF` |
| core zip | 2,529,648 字节 | `05556B27B156348950EA88AE6838032C8B478AE532B18B3929387D1DA4C18D55` |
| core 源码树 | 1,201 文件 | `6D80301068B8870D314E8AAFCC9ADCD439162E93AD9D59E150FF2DDDA890C49B` |

Windows zip 的摘要已与[官方归档校验文件](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.zip.sha256)核对。三个工具的摘要与[官方二进制清单](https://cli.moonbitlang.com/binaries/latest/moonbit-windows-x86_64.sha256)及原有安装均一致。core 地址来自[官方安装脚本](https://cli.moonbitlang.com/install/powershell.ps1)；本轮未取得 core 的单独官方校验文件，配置采用 HTTPS 下载后实测的归档摘要。core 版本 `0.10.15+943464bfa`、全部源码的整体摘要也与原有安装一致。官方校验方法见[下载说明](https://www.moonbitlang.com/download/#verifying-binaries)。

源码树摘要按相对路径作 ordinal 排序，将每个文件的“路径 + TAB + 大写 SHA256 + LF”以 UTF-8 编码后再取 SHA256；包括隐藏源码文件，排除 core 根目录的 `_build/` 与 `.mooncakes/`。先核对工具二进制，再执行版本查询；解包后和 bundle 后均核对版本、三个工具及 core 源码身份。生成的 core bundle 从这些输入重新构建，不承诺其逐字节相同。

## 安装和使用

使用 PowerShell 7。目标安装目录和证据目录都必须不存在：

```powershell
$locked = 'D:\moonbit\toolchains\moonffi-20261012'
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

CI 五项 suite 均先创建内容锁定的独立工具链，behavior 任务额外运行上述边界检查；诊断只上传 JSON 和日志，不上传下载归档、工具目录或边界测试的复制二进制。整体工程、原生内存及 SDK 验收仍按 [复现指南](REPRODUCIBILITY.md) 执行。

本轮不锁定 Windows runner 镜像、MSVC、Windows SDK、GitHub Actions 的版本标签或 registry 内容，也不声明完整的密闭构建、供应商签名验证或任意时间均可从上游恢复历史工具链。来源 URL 和摘要同时变更时，需要人工核对来源并重新运行五项验收。
