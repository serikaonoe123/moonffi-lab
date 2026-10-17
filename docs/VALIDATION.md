# 缩减器验证记录

## Windows CI 与源码复验：2026-10-17

`92dd00f` 新增 Windows CI 三个独立 suite，以及 `verify-clean.ps1` 和工具版本闸门。使用 `git archive` 从该提交导出的源码，在 `results/clean-ci-offline-20261017` 完成全新项目构建；明确使用本地 async 0.22.5 源码缓存，没有复制项目构建产物。28/28 单测、完整 behavior 集成验收、ASan 三次 canary 与 Buffer/Eigen 正常对照及 Resize 控制、27 次策略对照和 111 个真子集核验全部通过。

补齐环境元数据后，又用同一源提交运行 behavior 验收，验证驱动脚本哈希和环境记录正确。完整本地结果及边界检查摘要保存在 [源码复验快照](evidence/clean-source-20261017.json)。

工具版本漂移测试会失败并保存报告；无效 commit 会保存失败阶段；复用输出目录会在启动构建前拒绝，原报告哈希不变。边界证据保存在 `results/ci-script-checks-20261017` 与 `results/clean-ci-invalid-ref-20261017`。CI 内嵌的两个 PowerShell 块已通过语法解析；完整 YAML 和云端执行仍需 GitHub 实际验证。

这次证明的是“从指定提交的新源码目录重新构建”，不是独立机器或全新依赖下载。官方安装脚本的本地下载先被套接字权限拒绝，经批准的沙箱外诊断请求又遇到传输 EOF；联网安装、registry 恢复和云端 CI 尚未验证。版本安装入口当前为 latest，但实际工具必须与 toolchain.json 完全匹配。配置和操作见 [复现指南](REPRODUCIBILITY.md)。

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

当前仍需补齐 CI 和独立干净环境复现。behavior 测试通过不代表已完成内存检测。
参数缩减目前要求 JSON 编码长度严格减少，未覆盖等长数值简化；搜索完成也不宣称任意适配器下的全局最小性。

## ASan stub profile：2026-10-16 22:01

`scripts/verify-asan.ps1 -Out results/asan-20261016-second` 已通过。三个独立工作进程的人工 canary 均产生 heap-buffer-overflow 检测报告，被控制器分类为 MemoryError；Buffer 与 Eigen 各十个正常场景通过。对 canary 请求缩减时明确返回 unsupported_outcome，不把内存错误类别当作同根因指纹。

仅 `fixtures/buffer/buffer.c` 和 `vendor/eigen-binding/eigen_shim.cpp`（含其 Eigen 模板实例）插桩。MoonBit 生成的 C、MoonBit runtime、async C stubs 及其他系统/预编译库未插桩。运行时、二进制哈希和具体范围见该目录 verification.json；所有 stderr 保留。ASan 副本使用本地固定版本依赖源码缓存，未复制已有构建产物，也不构成独立干净环境复现。

第一次 ASan 构建因并行 /Zi 编译争用 vc140.pdb 失败，诊断保存在 results/asan-20261016-first。随后改为保留 moon 默认 /Z7 调试信息、链接时启用 /DEBUG，第二次通过。主源码构建配置没有被临时改写。
