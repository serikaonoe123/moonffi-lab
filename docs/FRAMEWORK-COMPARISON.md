# 与 Hypothesis、PropEr 的功能对照

核对日期：2026-10-22。Hypothesis 在线文档显示版本 6.170.5；PropEr 引用其官方 API 文档。对照用于说明设计取舍和本次交付范围，未执行三个框架之间的性能或缺陷发现率比较。

本项目的验收源码为 [`7d2716dd345224402437466f41ee9a34564749cf`](https://github.com/serikaonoe123/moonffi-lab/tree/7d2716dd345224402437466f41ee9a34564749cf)。下表中的“已实现”仅指该提交及[对应验收证据](evidence/main-acceptance-20261022.json)。

| 维度 | Hypothesis 官方文档中的机制 | PropEr 官方文档中的机制 | MoonFFI Lab 已实现及边界 |
|---|---|---|---|
| 状态与命令生成 | 规则可组成操作序列，状态由测试对象维护；见[状态测试](https://hypothesis.readthedocs.io/en/latest/stateful.html#rule-based-state-machines) | 回调提供初态和按状态生成的符号命令；见[状态机回调](https://proper-testing.github.io/apidocs/proper_statem.html#description) | ContractModel 显式提供 initial_state / commands；纯 JSON 模型、串行有界命令枚举，生成阶段不调用目标 |
| 前置条件与结果检查 | [前置条件](https://hypothesis.readthedocs.io/en/latest/stateful.html#preconditions)筛选规则，[不变量](https://hypothesis.readthedocs.io/en/latest/stateful.html#invariants)在步骤间检查；规则内部可断言结果 | [precondition、postcondition、next_state](https://proper-testing.github.io/apidocs/proper_statem.html#description)分别约束命令、检查结果和推进状态 | 提供 precondition / next_state / postcondition / invariant；后置条件失败时模型不推进，执行前后检查目标观察值。不是把 Hypothesis 的规则断言直接等同为同名回调 |
| 操作结果的复用 | [Bundle](https://hypothesis.readthedocs.io/en/latest/stateful.html#rule-based-state-machines)保存并复用规则产生的值 | [符号变量](https://proper-testing.github.io/apidocs/proper_statem.html#description)可引用前序调用结果，执行时求值 | 资源用逻辑 ID 及 defines / uses / releases 声明依赖；指针留在目标内部。未提供任意符号表达式求值。next_state 仅接收旧状态和命令，实际返回值由 postcondition 核对，不等同于 PropEr 含结果参数的状态转换 |
| 常见值域与组合 | [策略参考](https://hypothesis.readthedocs.io/en/latest/reference/strategies.html)提供标量、文本、字节、容器和组合策略 | [类型参考](https://proper-testing.github.io/apidocs/proper_types.html)提供基础类型、列表、联合及自定义生成/缩减组合 | ArgumentStrategy 提供十类有界域；32/64 位整数精确编码，Float64 保留位模式，文本/字节保留类型；序列及可空值可递归组合。长度、深度、候选数和总值预算均受限，不是任意对象图生成器 |
| 缩减和合法性 | [值策略](https://hypothesis.readthedocs.io/en/latest/reference/strategies.html)具有各自的缩减行为 | [状态序列缩减](https://proper-testing.github.io/apidocs/proper_statem.html#description)考虑前置条件，[类型组合](https://proper-testing.github.io/apidocs/proper_types.html#description)可定制缩减 | plain / dependency / state 交替执行删除与有限参数候选，生成/验证/修整共享模型；接受候选须保留结果和签名，基线及最终各三次确认。deletion_minimal 只对应声明的删除邻域，不承诺全局最短或参数最小 |
| 并行与表达能力 | 本次仅对照官方状态测试页中的规则式接口，不据此判断上游全部并发扩展 | [并行状态测试](https://proper-testing.github.io/apidocs/proper_statem.html#description)提供并发命令和序列化检查 | 本次范围为串行状态机；未实现并行命令调度或线性化检查 |

## 本次面向原生绑定的专项验证

此部分说明本项目的交付，不据上述状态/策略参考页断言两个上游框架是否具备相同的原生故障设施。

- 通过独立工作进程调用目标，保存具体输入、逐步事件、stdout/stderr、原始退出码及候选报告。
- 显式启用原生错误签名；崩溃须有支持的主程序位置记录，ASan 须有类别及两层可定位调用帧。每次执行前后核对工作进程二进制内容；弱证据不自动成为可缩减失败。
- Windows 和 Linux x86_64 分别验证自有 C 人工崩溃及 ASan 故障，三策略各从 32 步缩到 2 步；核对同位置重放、不同位置区分及正确实现对照。人工 fixture 不计为未知上游缺陷。
- 五项不稳定基线/最终、弱证据、预算和默认关闭控制只覆盖 crash 档；专项 ASan 只插桩 faults.c。一般 Windows ASan profile 另插桩 Buffer C 和 Eigen shim，未覆盖全部生成代码、运行时和依赖。

## 已交付范围与后续边界

本次四项补齐均有接口、接入实例、执行脚本和固定提交证据，见[逐项验收回应](REVIEW-RESPONSE.md)。接入新库仍需定义操作、模型和性质；现有示例不自动推广为任意外部库都能测试。没有性能优于 Hypothesis/PropEr、同根因判定、全局最小、任意指针生成或全程序内存安全的结论。独立使用者反馈及新版本发布不在本轮已验证成果中。
