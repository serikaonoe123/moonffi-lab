# Eigen 状态探索的保存输入

`case.json` 是 `eigen-stateful-1`、seed 17 生成的 64 步合法轨迹，包含构造、写入、检查、转置、不兼容加法和释放引用。它在真实的 vendored Eigen 绑定上预期为 Pass；没有注入缺陷，也不作为发现真实漏洞的证据。

在仓库根目录构建并直接重放具体输入：

```powershell
moon build --target native --frozen
& .\_build\native\debug\build\cmd\eigen-lab\eigen-lab.exe replay examples/eigen-stateful/case.json --out results/eigen-saved-demo
```

输出目录必须尚不存在；退出码应为 0。重放读取保存步骤，不重新运行 seed。`manifest.json` 记录输入 SHA-256，JSON 使用 LF 行尾；`scripts/verify-eigen-generation.ps1` 核对哈希后重放。

输入记录绑定和 Eigen 源码版本；源码来源与许可见 [快照记录](../../vendor/eigen-binding/SNAPSHOT.md)。轨迹的 `Drop` 只移除 MoonBit 引用，不验证 finalizer 的精确运行时刻或原生分配平衡。
