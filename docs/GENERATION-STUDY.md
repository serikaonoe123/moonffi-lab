# 按状态探索的 Buffer 生成器

2026-10-17 新增 `--generator stateful`，版本标识 `buffer-stateful-1`。它从当前状态允许的操作中随机选择，操作顺序不依赖原生 fixture 模式，也不附加固定的缺陷触发序列。默认生成器 `buffer-1` 仍用于固定契约回归，已有保存案例继续按具体步骤重放。

## 操作选择与边界

生成器维护有序的活句柄数组，共享句柄引用同一个长度对象。无活句柄时只能构造；有活句柄时允许读取、关闭、拒绝写入和扩缩容；活句柄少于 8 时允许继续构造和共享；存在非空资源时才允许合法写入。它先选择允许的操作，再选择满足前置条件的对象与参数，不通过修整器事后补救非法输入。

长度覆盖 0、1、2、15、16、255、256 及区间内随机值；数据覆盖 NUL、高位字节和随机字节。写入覆盖首尾与随机合法索引；拒绝写入覆盖负索引、末端索引及更远索引。扩缩容覆盖零、最大值、原长度附近和随机长度。句柄 ID 单调递增，关闭后不会复用。最多 8 个活句柄、256 字节资源；公共函数将步数限制在 0–256，CLI 接受 8–256 步。

生成时只使用纯状态和确定性随机数，不调用 FFI。对象选择基于数组顺序，避免 hash-map 遍历顺序影响 seed 的重现。实际重放仍读取保存的具体轨迹，不能以 seed 代替输入。

```powershell
$buffer = '.\_build\native\debug\build\cmd\buffer-lab\buffer-lab.exe'
& $buffer run --generator stateful --seed 17 --cases 64 --steps 64 --out results/exploration-demo
& .\scripts\verify-generation.ps1
```

目录必须尚不存在。`--generator` 仅供 run/generate 使用，replay/shrink 使用保存的步骤；未知生成器返回退出码 2，且不启动工作进程。Eigen 目前继续使用原默认生成器。

## 本轮实测

`scripts/verify-generation.ps1 -Out results/generation-stateful-20261017` 使用 seed 17–80、每例 64 步，分别对 default/stateful 和 correct/nul/share/error 运行 64 个独立工作进程，共 512 个场景。以下覆盖指标只统计在 correct 实现上完整执行的轨迹。

| 观测指标 | 默认契约生成器 | stateful |
|---|---:|---:|
| 正确场景通过数 | 64/64 | 64/64 |
| 不同操作顺序 | 64 | 64 |
| 相邻操作组合（包含 start→new） | 14 | 50 |
| 不同已标记状态特征 | 3 | 11 |
| Resize 操作数 | 0 | 639 |
| 最大活句柄数 | 11 | 8 |

组合计数包含一次虚拟起点类型；排除起点后分别是 13 和 49 种相邻操作对。它是操作轨迹观测，不是原生代码覆盖率，也不保证更长状态历史已被充分探索。状态特征包括空/最大长度构造、增长/缩小、缩到零、零长度重新增长、通过另一别名调整长度后写入，以及关闭一个别名后读取剩余别名。

| 人工缺陷模式 | default 失败场景 | stateful 失败场景 | stateful 首个失败缩减后步数 |
|---|---:|---:|---:|
| nul | 64/64 | 59/64 | 2 |
| share | 64/64 | 63/64 | 4 |
| error | 64/64 | 58/64 | 3 |

默认生成器自带固定契约触发过程，stateful 则可能没有触发或观察某个缺陷；失败数不能直接作为生成器优劣排名。两者活句柄上限与数据分布也不相同。本轮仅是确定性本地语料观测，没有外部库发现率或统计性能结论。

三个 stateful 首个失败都来自 seed 17；各自完成基线和最终三次指纹确认、最终单步删除审计，且切换正确 fixture 后通过。固定输入与原始失败报告已保存为 [可重放示例](../examples/stateful/README.md)。它们均是明确标注的人工缺陷，不代表发现未知真实缺陷。

补齐固定案例后，`results/generation-stateful-final-20261017` 又完整复跑了上述 512 场景，结果一致，并核对三个固定输入/报告的哈希、原缺陷重放与正确实现重放。样例 JSON 使用 LF 行尾，以便 Windows checkout 后仍能检查文件哈希。

## 正确性与回归验证

- 32/32 单测通过。新增独立 oracle 使用句柄→资源编号和标量长度，枚举 128 个 seed × 6 种步数，共 768 条轨迹；不调用生成器资源对象、BufferModel、修整器或 FFI 来计算预期合法性。
- oracle 同时核对依赖声明、对象可用性、共享别名长度、索引范围、活句柄上限和句柄 ID 不复用；生成结果通过适配器校验及序列化往返。
- 32 条 64 步随机轨迹直接执行正确 native fixture，teardown 全部保持资源平衡；外部进程实验又完整运行了 64 条 stateful 正确轨迹。
- 同 seed 进程内与跨独立生成进程均产生相同具体输入；人工缺陷模式不改变操作序列。
- 原有完整集成验收通过，证据在 `results/verify-stateful-generator-20261017`。ASan canary 与正常对照通过，额外 16 条 stateful 正确场景通过，证据在 `results/asan-stateful-generator-20261017`。

机器可读摘要见 [生成实验快照](evidence/generation-stateful-20261017.json)。原始输入、逐候选日志、缩减和修复后重放记录保留在各 results 目录。[Actions run 38997018833](https://github.com/serikaonoe123/moonffi-lab/actions/runs/38997018833) 已在托管 Windows runner 上验证提交 `ee6bb3a`，behavior、ASan、benchmark、generation 四项全部通过。已下载核对产物：32/32 单测、512 场景的失败计数与操作/状态特征观测、三个固定案例重放均与本地一致，见 [云端快照](evidence/github-ci-38997018833.json)。

新增的 seed 17–20 × 三种模式现已纳入 [三轮缩减对照](REDUCTION-STUDY.md)，所有筛选输入及未完成结果均保留。真实 Eigen 绑定现也支持 [按矩阵状态探索](EIGEN-GENERATION.md)，完整生成验收在原 Buffer 512 个场景之外增加 128 个 Eigen 场景。后续重点是扩充更长依赖历史、更多失败根因和真实库语料。当前没有覆盖率引导、状态空间穷尽或全局最小性声明。
