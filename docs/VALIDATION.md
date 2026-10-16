# 缩减器验证记录

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

当前仍需补齐 ASan profile/canary、CI 和独立干净环境复现。behavior 测试通过不代表已完成内存检测。
参数缩减目前要求 JSON 编码长度严格减少，未覆盖等长数值简化；搜索完成也不宣称任意适配器下的全局最小性。
