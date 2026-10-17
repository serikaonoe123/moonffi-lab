# 从随机状态轨迹缩减出的固定案例

这些案例来自 Buffer `buffer-stateful-1` 生成器 seed 17、64 步轨迹，均针对明确人工注入的 fixture 缺陷。完整原始实验见 [生成实验](../../docs/GENERATION-STUDY.md)。案例保存缩减后的具体输入和原有稳定步骤 ID，不依赖重新生成 seed。

先在仓库根目录运行 `moon build --target native`，再选一个案例：

```powershell
$buffer = '.\_build\native\debug\build\cmd\buffer-lab\buffer-lab.exe'
& $buffer replay examples/stateful/nul-case.json --out results/example-stateful-defect
& $buffer replay examples/stateful/nul-case.json --mode correct --out results/example-stateful-corrected
```

缺陷重放预期退出码 1，正确实现预期 0。每次使用新的结果目录。其余输入为 `share-case.json`、`error-case.json`，分别是 4 步共享资源提前失效、3 步错误返回后破坏状态；`nul-case.json` 是 2 步 Bytes 截断。相邻的 `*-report.json` 为最终确认进程的原始失败报告。`manifest.json` 保存输入和报告哈希以及对应缩减统计。

`deletion_minimal` 仅表示在该策略与观测范围内完成单步删除邻域检查，不表示任意参数的全局最小或同一原生根因。这里保留的是可重放的最小化案例；完整进程和候选日志位于本地 results 中，不随源码全部打包。
