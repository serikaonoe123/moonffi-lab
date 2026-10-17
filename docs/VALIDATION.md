# 缩减器验证记录

## 外部 SDK 消费者：2026-10-17

新增独立模块 `moonffi-example/counter-lab`，仅依赖公开 core/runner 和 async。`verify-sdk.ps1` 在新目录中只复制这两个引擎包、模块清单与消费者，包图确认没有 fixtures/vendor/引擎命令，然后重新构建。显式离线依赖源码与默认工具缓存恢复两个路径均通过，证据为 `results/sdk-external-offline-20261017` 和 `results/sdk-external-cache-20261017`。

5/5 示例单测通过，覆盖 768 条独立标量 oracle 轨迹、七步轨迹全部 128 个子集的独立修整 oracle，以及 32 条 native walk。另有 8 条正确契约与 32 条正确 walk 的独立进程验收。人工 error 失败 32 → 2 步、26 次执行，稳定指纹保持，三个真子集核验及正确实现重放通过。纯阶段 C 调用审计、6 次预算、非法依赖预检、未知生成器、跨进程确定性及输出目录复用检查通过。

工作区、源码哈希和包图已保存；没有改动 core/runner 实现，也没有将主项目 ASan 范围扩展到计数器 C 文件。指南、范围与证据见 [SDK 接入](SDK.md) 和 [快照](evidence/sdk-20261017.json)。CI 增加 sdk suite，须按对应提交的实际运行确认云端结果。

## Eigen 探索版本的云端复现：2026-10-17

[Actions run 39002767161](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39002767161) 的四项任务全部通过，测试提交为 `46011be5ac260284acf78066756457089e742b25`。已核对四份产物：37/37 单测、Buffer 512 + Eigen 128 场景、16 条 Eigen ASan 轨迹、189 次缩减和 214 个真子集核验通过。128 个 Eigen 具体输入哈希及覆盖观测与本地逐项一致，固定示例重放通过。摘要见 [云端快照](evidence/github-ci-39002767161.json)；这是 SDK 接入示例之前的提交。

## Eigen 真实绑定的状态探索：2026-10-17

新增 `eigen-stateful-1`，按存活矩阵形状选择合法操作；构造、写入、转置及不兼容加法返回错误后检查全部存活矩阵。默认 `eigen-1` 与 vendored 源码保持原样。

37/37 单测和完整 behavior 集成验收通过。新增独立二维数组 oracle 验证 768 条纯轨迹及 32 条 64 步真实 native 轨迹；故意替换适配器句柄的单测确认全对象检查能发现意外共享。完整生成验收通过 Buffer 512 个场景及 Eigen 128 个场景，并验证保存案例哈希/重放、跨生成进程确定性及 CLI 拒绝边界。Eigen 的操作组合（含起点）由 14 扩至 37，矩阵形状由 10 扩至 16；这不是原生代码覆盖率或真实缺陷发现率。

ASan canary、原有正确场景及新增 16 条 Eigen stateful 正确轨迹通过；实际 ASan 源码清单与本阶段实现哈希一致。证据位于 `results/verify-eigen-stateful-20261017`、`results/generation-eigen-stateful-20261017`、`results/asan-eigen-stateful-20261017`，见 [实验报告](EIGEN-GENERATION.md) 与 [快照](evidence/generation-eigen-20261017.json)。原生内存检测范围、数值算法和 finalizer 限制仍保留。

## 重复缩减版本的云端验收：2026-10-17

[Actions run 38998166053](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38998166053) 的四项任务均通过，测试提交为 `166d86df8bbf9468c70e70d526b05183f43d5e4e`。已下载全部产物并核对 benchmark：189 次全部完成，63 组结果三轮一致，214 个真子集核验通过，189 个正确实现重放通过；具体缩减输入、候选数、指纹及停止状态与本地逐条一致。见 [云端快照](evidence/github-ci-38998166053.json)。这是新增 Eigen 生成器之前的提交，不能作为后续改动的云端验收。

## 扩展语料与三轮缩减：2026-10-17

`scripts/benchmark-reduction.ps1` 默认扩展为原九例加十二个 stateful 场景，先冻结/筛选全部输入，再进行三轮轮换顺序的测量。21 个输入均出现性质失败；189 次缩减全部完成搜索和确认，63 个“案例 × 策略”组合的具体结果与结构计数在三轮一致。189 个结果的正确实现重放通过，实际独立核验 214 个真子集，相同输入/指纹的核验复用有来源记录。

seed 20 的 share 场景中 plain 为 6 步、dependency/state 为 4 步；全语料每轮工作进程次数为 555/587/600，无效候选为 333/14/0。这支持候选合法性和特定案例的缩短，不支持 state 全面更快或优于 dependency 的结论。完整协议、逐例中位数/范围及限制见 [缩减实验](REDUCTION-STUDY.md) 与 [快照](evidence/reduction-repeated-20261017.json)。原始记录在 `results/benchmark-repeated-final-20261017`，前一轮同协议结果保留于 `results/benchmark-repeated-20261017`。

预算为 6 的九例边界运行保留全部 27 个预算耗尽结果，没有误报最小性。新增 seed 26 的边界运行保留 12 个筛选输入，其中 nul 为 Pass，余下 11 例的 33 个缩减均保留预算耗尽状态。以上是实验驱动脚本验证；本阶段没有修改 MoonBit 引擎或原生 fixture。

## 状态探索版本的四项云端验收：2026-10-17

[Actions run 38997018833](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38997018833) 对提交 `ee6bb3a034d84500dbf34e33addbc7022a391e9b` 的 behavior、ASan、benchmark、generation 四项全部成功，最后一项于 **11:00:47（Asia/Shanghai）** 完成。四份产物均已下载并核对，源码归档哈希一致，严格工具链检查通过，registry 重新下载 async 0.22.5。

behavior 通过 32/32 单测与完整集成，ASan 额外 16 条 stateful 正确轨迹通过，generation 复现 512 个场景、三个固定案例及与本地相同的计数。该提交的 benchmark 仍是旧版九例单轮（27 次及 111 个真子集），不将它作为本页新增 189 次重复实验的云端验证。托管 runner 为 `win25-vs2026 / 20261007.264.1`、PowerShell 7.6.6；声明范围仍受文档中的安装器与 ASan 限制约束。见 [云端快照](evidence/github-ci-38997018833.json)，完整下载位于 `results/github-ci-38997018833/`。

## 状态探索生成器：2026-10-17

新增 Buffer `--generator stateful`，默认契约场景保持原生成版本。32/32 单测、原有完整集成验收与 ASan profile 验收通过；ASan 额外运行 16 条 64 步 stateful 正确轨迹，全部通过。

独立纯模型核验 768 条轨迹；两个生成器在四种 fixture 模式下各运行 64 个独立进程，共 512 场景。stateful 的 64 个正确场景全部通过，人工 nul/share/error 分别在 59/63/58 个场景被观察到。三个首次失败样本均稳定缩减并在正确实现上重放通过。完整方法、指标定义、证据路径和限制见 [生成实验](GENERATION-STUDY.md)，固定最小化输入见 [示例](../examples/stateful/README.md)。

## 云端与用户手动验收：2026-10-17

[GitHub Actions run 38994542498](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38994542498) 对提交 `4f46b0188fb2f355761e2c1389f5be5af3fca2c9` 的 behavior、ASan、benchmark 三个任务全部成功，最后一个任务于 **10:22:08（Asia/Shanghai）** 完成。下载并核对了三个任务的验收产物，而不只依据绿色状态。

三个任务使用 GitHub 托管的 Windows x64 runner，镜像 `win25-vs2026 / 20261007.264.1`，PowerShell 7.6.6。安装 MoonBit 后通过严格版本检查；依赖检查日志均记录重新下载 async 0.22.5，`dependency_mode=registry`；三个源码归档哈希一致。behavior 的 28/28 单测与完整集成检查、ASan 三次 canary 和正常对照、benchmark 的 27 次策略对照与 111 个真子集核验全部通过。

这是开发机之外的托管 runner 复现证据。脚本自身的 `independent_environment=false` 字段仍保留原义；独立运行来源由 Actions 任务、runner 信息、安装日志和产物共同补充。不能据此宣称任意 Windows 版本、整个程序的 ASan 覆盖或不可变工具链复现。结构化摘要见 [云端证据快照](evidence/github-ci-38994542498.json)，本地完整下载在 `results/github-ci-38994542498/`。

用户随后手动运行 `verify.ps1` 也通过：`results/verify-0fe000bac8dc42f0b3dfd7aabb7b3470`，完成时间 10:34:55（Asia/Shanghai），已核对 28/28 单测及 verification.json。后文保留早期本地验证与限制记录，其中当时的“云端待验证”状态已由上述运行更新。

## Windows CI 与源码复验：2026-10-17

`92dd00f` 新增 Windows CI 三个独立 suite，以及 `verify-clean.ps1` 和工具版本闸门。使用 `git archive` 从该提交导出的源码，在 `results/clean-ci-offline-20261017` 完成全新项目构建；明确使用本地 async 0.22.5 源码缓存，没有复制项目构建产物。28/28 单测、完整 behavior 集成验收、ASan 三次 canary 与 Buffer/Eigen 正常对照及 Resize 控制、27 次策略对照和 111 个真子集核验全部通过。

补齐环境元数据后，又用同一源提交运行 behavior 验收，验证驱动脚本哈希和环境记录正确。完整本地结果及边界检查摘要保存在 [源码复验快照](evidence/clean-source-20261017.json)。

工具版本漂移测试会失败并保存报告；无效 commit 会保存失败阶段；复用输出目录会在启动构建前拒绝，原报告哈希不变。边界证据保存在 `results/ci-script-checks-20261017` 与 `results/clean-ci-invalid-ref-20261017`。本地先完成了两个 CI 内嵌 PowerShell 块的语法解析，随后完整 YAML 与云端执行也已通过上述 Actions 运行验证。

这次本地离线运行证明的是“从指定提交的新源码目录重新构建”，不是独立机器或全新依赖下载。官方安装脚本的早期本地下载先被套接字权限拒绝，经批准的沙箱外诊断请求又遇到传输 EOF；后续云端运行已成功安装并恢复 registry 依赖。版本安装入口当前为 latest，但实际工具必须与 toolchain.json 完全匹配。配置和操作见 [复现指南](REPRODUCIBILITY.md)。

## 最新状态：2026-10-17 10:00（Asia/Shanghai）

状态感知缩减版本已完成 **28/28 单测**、完整 behavior 集成验收和 ASan stub profile 验收。证据分别保存在 `results/verify-state-final-20261017` 和 `results/asan-state-final-20261017`。后者额外检查通过别名扩容、关闭原句柄、缩到零和重新扩容，结果为 Pass。

新增验证包括纯状态修整、共享别名索引约束、七步轨迹全部 128 个子集的独立模型校验，以及最终删除邻域审计。预算耗尽和错误修整器不能报告 `deletion_minimal=true`。错误修整器可以稳定重放原失败，也可以走完邻域遍历，但未决邻居使其证据不足以判定删除最小性。

9 个案例、27 次策略对照与 state 结果 111 个真子集的独立重放已通过。具体数据、方法和结论限制见 [对照实验](REDUCTION-STUDY.md)；历史验证记录保留如下。

本次上下文接续后重新运行完整验收，28/28 单测及集成检查通过，证据位于 `results/verify-context-continuation-20261017`。带语义修整覆盖断言的三策略对照也已重新通过，证据位于 `results/benchmark-context-continuation-20261017`。ASan 源清单核对仅发现 `core/repair.mbt` 的注释变化；原生及适配器实现与前述 ASan 验收一致。

验证时间：2026-10-16 21:55（Asia/Shanghai）。平台：Windows x64 / MSVC，native debug，behavior profile。
工具链：moon 0.1.20261012、moonc 0.10.15，async 0.22.5。

## 本次执行

```powershell
moon test --target native --deny-warn -j 1
& .\scripts\verify.ps1 -Out results/verify-reducer-retry-20261016
```

单测 **20/20 通过**；完整集成验收退出码 0。
原始证据位于 `results/verify-reducer-retry-20261016/`：
`verification.json` 保存工具链、二进制 SHA-256 和验证事实；各命令日志、案例输入和子进程证据分别保留。
该目录被 Git 忽略，重新运行脚本会产生一份新的本地证据。

## 真实 FFI 场景

Buffer 与 Eigen 各运行 10 个独立进程的正确场景，全部通过。
专用崩溃探针得到 Crash，原始退出码 -1073740286；超时探针得到 Timeout。

| 人工缺陷 | 原始步数 | 缩减后步数 | 缩减执行次数 | 独立核验的真子集 |
|---|---:|---:|---:|---:|
| NUL 字节截断 | 32 | 2 | 19 | 3 |
| 提前关闭共享资源 | 32 | 4 | 23 | 15 |
| 返回错误后破坏状态 | 32 | 3 | 23 | 7 |

三类失败都先连续执行三次确认基线，缩减后再连续执行三次确认相同指纹；独立重放仍失败，改用正确 fixture 重放全部通过。
子集核验通过枚举最终轨迹的全部真子集实现，不调用被测 delete_block 算法。非法依赖子集须被拒绝；合法子集均未保持原失败指纹。
这验证了这些具体案例在保留参数、仅删除步骤的范围内没有更短子集，不表示任意输入或任意参数下全局最短。

## 缩减器边界

独立的 `cmd/reducer-probe` 合成程序通过同一子进程协议运行，以 case-N 启动序号构造可控的稳定性变化，不调用受测原生库。

| 场景 | 实测结果 |
|---|---|
| 稳定合成失败，预算 100 | 32 → 2 步，27 次执行，search_complete，confirmed=true |
| 只有 6 次执行预算 | 正好 6 次，保留 32 步，execution_budget；仅确认失败，不宣称已经缩短 |
| 基线第二次通过 | 2 次后停止，unstable_baseline，confirmed=false |
| 基线第二次换指纹 | 2 次后停止，unstable_baseline，confirmed=false |
| 基线后失败消失 | 98 次，unstable_final，confirmed=false |
| 原始案例通过 | 1 次，unsupported_outcome，confirmed=false |
| 挂起案例，wall-ms=100 | 114 ms，wall_budget，基线 Timeout，confirmed=false |

参数候选改变操作类型或依赖声明时，会在启动工作进程前拒绝；同操作但参数类型不合法时也会拒绝。稳定合成案例记录了这三种无效候选。
逐候选诊断位于各缩减目录的 `reduction-events.jsonl`，已执行候选对应 `case-N` 完整证据；合成验收同时核对日志中的执行记录数与报告执行次数一致。
输出目录复用会返回错误，已有报告哈希保持不变。

## 历史限制和剩余工作

上次原生测试在启动 `buffer.whitebox_test.exe` 时返回“拒绝访问（os error 5）”，当时已停止，没有用其他方式绕过限制。
诊断保留在 `results/verify-reducer-boundaries-20261016/tests.log`；本次按用户要求正常重试后通过，没有修改权限或安全设置。

当时仍需补齐 CI 和独立干净环境复现；2026-10-17 的后续结果见本文开头。behavior 测试通过不代表已完成内存检测。
参数缩减目前要求 JSON 编码长度严格减少，未覆盖等长数值简化；搜索完成也不宣称任意适配器下的全局最小性。

## ASan stub profile：2026-10-16 22:01

`scripts/verify-asan.ps1 -Out results/asan-20261016-second` 已通过。三个独立工作进程的人工 canary 均产生 heap-buffer-overflow 检测报告，被控制器分类为 MemoryError；Buffer 与 Eigen 各十个正常场景通过。对 canary 请求缩减时明确返回 unsupported_outcome，不把内存错误类别当作同根因指纹。

仅 `fixtures/buffer/buffer.c` 和 `vendor/eigen-binding/eigen_shim.cpp`（含其 Eigen 模板实例）插桩。MoonBit 生成的 C、MoonBit runtime、async C stubs 及其他系统/预编译库未插桩。运行时、二进制哈希和具体范围见该目录 verification.json；所有 stderr 保留。ASan 副本使用本地固定版本依赖源码缓存，未复制已有构建产物，也不构成独立干净环境复现。

第一次 ASan 构建因并行 /Zi 编译争用 vc140.pdb 失败，诊断保存在 results/asan-20261016-first。随后改为保留 moon 默认 /Z7 调试信息、链接时启用 /DEBUG，第二次通过。主源码构建配置没有被临时改写。
