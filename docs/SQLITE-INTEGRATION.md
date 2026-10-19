# 真实社区 SQLite 绑定接入

2026-10-19，独立消费者 `moonffi-example/sqlite-lab` 通过公开 core/runner 接入 [moonbit-community/sqlite3.mbt](https://github.com/moonbit-community/sqlite3.mbt)，引擎没有增加 SQLite 专用逻辑。固定提交、归档 SHA-256、49 个 Git blob 和使用方式见 [例子](../examples/sqlite-lab/README.md)。来源按 Apache-2.0 保留，仓库只新增适配代码和来源元数据；没有上传第三方工具包、联系上游或发布版本。

## 已通过的本地验证

全新源码工作区 `results/sqlite-external-accepted-20261019` 使用已锁定工具链，以及明确提供的 async 0.22.5 源码。报告见 [快照](evidence/sqlite-external-20261019.json)。

- 原样上游 native 单测 48/48；适配器单测 8/8。
- 纯模型独立 oracle 枚举 1,024 个删除子集，256 条纯状态探索轨迹及 32 条 native 单测 walk。
- 32 个固定契约场景和 64 个状态探索场景，在独立进程运行，覆盖全部十种操作。
- 两份具体输入重放、跨进程同 seed 输入字节一致；Pass 请求缩减返回 unsupported_outcome，未声称发现反例。
- 伪造依赖声明在执行前拒绝，未知模式/生成器拒绝，已有证据不覆盖。
- 全部 49 个上游 Git blob 在构建前后相同；包图证明引擎接入范围恰为 core/runner。
- 九项脚本拒绝/环境恢复控制通过。成功验收的驱动哈希在运行前后相同，调用者环境和目录恢复。

上述本地记录来自同一台主机。最终提交 `1f065527f9fa584dc52a79399f0a36e40ed3c321` 的 [Actions 39248905440](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440) 六项全部通过，且已下载核对全部诊断产物；这是托管 runner 的另一环境验证，仍不等于独立维护者使用验收。见 [云端快照](evidence/github-ci-39248905440.json)。

六次官方锁定工具链安装通过；每个任务的 68 个关键导出文件匹配同一 Git 提交，驱动身份按 LF/CRLF 核对。SQLite 的 48+8 单测、96 场景、两份重放和九项环境/拒绝控制通过；96 份输入与本地逐字节相同，49 个上游 blob 构建前后一致。既有 69+6 单测、704 生成场景、128 份历史输入、189 次缩减、63 组重复与 214 真子集通过；189 行输入/结果字节、结构计数及正确实现重放均与旧基准一致。六份下载 ZIP 的大小与 SHA-256 匹配 GitHub 元数据，诊断包不含工具归档或二进制。

## 发现并处理的问题

首次完整运行 47/48 上游测试通过，持久化测试失败。上游测试依赖其模块目录的 `_build`，而 workspace 使用集中构建目录。只在模块目录创建空目录后原单测通过；验证脚本包含该准备步骤，不跳过测试、不修改源码。首次失败及单独复测日志保存在 `results/sqlite-external-final-20261019`。

负向控制发现脚本把缺失环境变量恢复成了空字符串。verify-clean 和 verify-sqlite 现使用 NullString 恢复真正缺失状态，并分别覆盖存在/缺失/空值。早期名为 absent 的控制本身准备错误，其结论仅覆盖空值；旧日志保留。详见 [临时目录记录](LOCAL-WINDOWS-TEMP.md)。

首两轮 CI（[39247453969](evidence/github-ci-39247453969-failed-sqlite.json)、[39247655451](evidence/github-ci-39247655451-failed-sqlite.json)）的 SQLite 验证断言通过，但末尾预期拒绝命令留下非零 LASTEXITCODE，使外层 PowerShell 任务失败，九项控制步骤因此未执行。这两轮不能写成完整验收成功。现只在全部验证断言通过后清零脚本最终 native 状态，失败仍抛错；`results/sqlite-ci-exit-accepted-20261019` 与 `results/script-controls-ci-exit-20261019` 按 GitHub 的退出包装复验通过。另从提交 5e5347c 导出源码，TEMP/TMP 真正缺失时完整 SDK 成功后仍保持缺失，记录 `results/sqlite-clean-sdk-absent-success-20261019`。

第三轮 [39248320859](evidence/github-ci-39248320859-failed-sqlite.json) 的 SQLite 主验收成功，九项控制启动后因默认读取 checkout 根目录 `.mooncakes` 而失败；CI 依赖实际由 verify-clean 放在 `results/ci/workspace/.mooncakes`。控制脚本新增显式 `-OfflineDependencySource`，workflow 指向真实依赖路径。没有根缓存的新目录回归九项通过且 CI 包装退出 0，记录 `results/script-controls-fresh-checkout-fixed-20261019`；第一次新目录准备漏复制来源清单的失败另保留在 `results/script-controls-fresh-checkout-20261019`。最终六项成功与以上三次失败分开保存，没有覆盖失败证据。

## 贡献与未完成项

本轮新增真实绑定的可复现接入范例、资源/语义模型与验证脚本，减少后续作者从零实现协议的工作。尚未发现未知上游缺陷；现有历史修复线索不算新发现，也没有制造上游缺陷作为成绩。

适配器只覆盖同步内存库、固定 SELECT、绑定值和显式生命周期，未验证任意 SQL、事务、并发、磁盘生成场景、SQLite ASan 或堆泄漏。上游单测的磁盘/异步覆盖不归入本适配器生成能力。下一阶段仍需独立使用者按文档复现、整理 v0.1 范围及发布流程，当前没有发布包或版本。
