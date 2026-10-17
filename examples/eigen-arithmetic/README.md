# 有符号非方阵算术对照

`case.json` 是 16 步手写的正确案例，`generator_version=eigen-arithmetic-control-1`；seed 0 只是元数据，不表示算术生成器的随机输出。manifest 保存具体输入的 SHA-256，生成验收会校验并重放；ASan 验收也运行该输入。

输入矩阵按行展开为 `A(2×3)=[1,-2,3,4,5,-6]`、`B(3×2)=[7,8,-9,10,11,-12]`。期望结果：

- `A×B(2×2)=[58,-48,-83,154]`。
- `B×A(3×3)=[39,26,-27,31,68,-87,-37,-82,105]`。
- `(A×B)+(A×B)=[116,-96,-166,308]`。

随后转置第一个产品，分别修改产品、和及两个源矩阵，最后释放源引用并检查所有结果。每次变更都核对全部存活矩阵，确保源、结果和转置具有独立存储。根模块单测另有上述字面期望值与独立二维 oracle 对照。

```powershell
moon build --target native --frozen
& .\_build\native\debug\build\cmd\eigen-lab\eigen-lab.exe replay examples/eigen-arithmetic/case.json --out results/eigen-arithmetic-example
```

预期退出码 0，Pass。输出目录必须尚不存在。真实绑定来源与许可见 [快照](../../vendor/eigen-binding/SNAPSHOT.md)，数值域和范围见 [算术实验](../../docs/EIGEN-ARITHMETIC.md)。该对照不包含人工缺陷，也不表示发现真实库缺陷。
