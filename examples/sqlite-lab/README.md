# 社区 SQLite 绑定的独立消费者

本例通过 MoonFFI Lab 公开的 `core` / `runner` 接入独立维护的 [moonbit-community/sqlite3](https://github.com/moonbit-community/sqlite3.mbt)，没有修改引擎或上游绑定。目标是检验真实库能否沿用同一适配协议；本例没有注入目标缺陷，也尚未发现未知缺陷。

## 固定来源

`upstream.json` 固定上游提交 `1405639063c52b1474b2622d4c5b5e36110aa74c`（模块 0.2.3）、源码 ZIP 的大小和 SHA-256；`upstream-files.json` 记录全部 49 个 Git blob。验证脚本先检查归档和路径，再解包，构建前后逐文件匹配 Git blob。上游 Apache-2.0 LICENSE 和 SQLite 3.49.1 源码保留在本地解包工作区；仓库不再分发它们的工具包或编译产物，也不执行上游脚本。

引擎使用 async 0.22.5，上游清单声明 0.22.4。本例使用 `moon.work` 将明确提供的 0.22.5 源码作为共同工作区成员；上游清单不改写，验证报告同时记录声明版本与实际来源。这不代表已经验证所有 async 版本组合。

## 运行

使用仓库锁定的工具链，在仓库根目录先恢复 async 源码，再执行：

```powershell
& .\scripts\assert-toolchain.ps1
# .mooncakes 中应已有 async 0.22.5；没有时先运行 moon update / moon check。
& .\scripts\verify-sqlite.ps1 -OfflineDependencySource .\.mooncakes
```

默认从上游固定提交下载源码。已有相同 ZIP 时可指定 `-UpstreamArchive <zip>`，校验保持不变。`-Out` 必须是新目录。脚本在该目录建立隔离工作区及临时目录，结束或失败后恢复调用进程的 TEMP/TMP、文件描述符检查设置和工作目录，不改变系统权限或安全配置。

工作区只有引擎公开包、消费者、固定上游源码和明确的 async 来源。包图必须证明引擎接入范围恰为 core/runner。验证包含上游原生单测、本例八项单测、32 个契约场景、64 个状态探索场景、具体输入重放、跨进程确定性及输入/输出拒绝边界。

上游原有持久化单测打开相对路径 `_build/sqlite3-persistence-test.db`；脚本先在上游模块目录创建空 `_build` 目录作为测试前提。这与 workspace 的集中构建目录不同，不修改上游测试或源码。该持久化单测通过不代表本适配器生成了磁盘场景。

## 操作与模型

只创建 `:memory:` 数据库，SQL 固定为 `SELECT ?1 AS value`；生成的字符串和整数通过绑定参数传入，不作为 SQL 或文件名执行。

| 操作 | 验证内容 |
|---|---|
| Open / Prepare | 连接与语句的依赖，最多两个连接、四个存活语句 |
| BindText / BindInt | 有界参数、中文、嵌入 NUL、emoji 和十进制整数往返 |
| Step / Read | 单行结果、耗尽状态、NULL、类型转换后的动态存储类型 |
| Reset | 保留或清除参数，失效当前行，再执行语句 |
| BusyClose | 仍有语句时返回 Busy，并保持连接和语句可继续使用 |
| Finalize / Close | 正常结束与失败后显式清理，语句先于连接 |

纯状态修整只删除步骤，不改写参数。测试用独立索引状态机枚举十步输入的全部 1,024 个子集；另有 256 条纯生成轨迹、32 条 native 单测 walk，以及固定文本/整数语料。

由于当前上游在本例场景中应当通过，脚本也验证对 Pass 输入请求 shrink 会报告 `unsupported_outcome`，不宣称找到或缩减了缺陷。历史上游变更只作为后续回归调查线索，没有将功能差异包装为新发现。

## 范围

当前为 Windows native behavior 验收。状态探索使用同步 SQLite API；未覆盖事务、并发、任意 SQL、磁盘持久性、堆泄漏或 SQLite 的 ASan 插桩。显式关闭成功不等于证明原生内存分配平衡。保存的具体步骤用于重放，seed 不代替输入。
