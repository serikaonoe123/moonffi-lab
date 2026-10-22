# 显式状态契约

2026-10-21 的开发版本在原 Adapter / StateModel 之外增加可选 ContractModel、ContractTarget 和 ContractAdapter。旧适配器的接口及失败指纹保持原样。当前接口及实例已纳入固定提交验收，见[证据](evidence/main-acceptance-20261022.json)；rc.1 附件不包含新接口。

## 模型与目标

模型的状态和实际观察值以具体 JSON 表达；原生指针只能留在目标实现内部。

| 接口 | 输入与职责 |
|---|---|
| initial_state | 返回可重建的纯初态，不访问目标 |
| commands | 按当前模型、序号及确定性随机字返回有限命令候选，不执行目标 |
| precondition | 检查当前状态下能否执行命令，拒绝时不修改模型 |
| next_state | 由旧状态和命令计算预期新状态，不执行目标 |
| postcondition | 将操作前模型、具体命令和目标返回值进行核对 |
| invariant | 核对当前模型与整个目标的实际观察值 |

ContractTarget 提供纯构造、身份/配置验证，以及仅在工作进程调用的 invoke / observe / close；另提供参数候选。ContractAdapter 将两者接入原 runner：操作前不变量、前置条件、原生调用、后置条件、模型推进、操作后不变量。后置条件失败时不推进模型。worker 即使在失败后也调用 teardown；teardown 检查最终不变量并显式 close，空轨迹也会检查初态。

模型函数必须是确定且无副作用的；JSON 内部对象也不得由回调原地修改。框架不可能证明用户回调的纯性，接入者应通过测试验证。next_state 为预期状态转换，返回值与实际状态的关系由 postcondition / invariant 指定；当前没有 PropEr 式任意符号表达式求值或并行命令调度。

## 生成、验证与修整

generate_contract_trace 要求 0..4096 步，每步枚举 1..128 个命令；用固定 UInt 递推及循环枚举选择满足资源依赖和前置条件的命令。没有合法候选时返回 Err，不悄悄缩短轨迹。ID 为稳定 s0、s1 等；调用者的 generator_version 负责约定生成语义，具体输入才是重放依据。此接口是有限命令枚举，不宣称统计均匀或无偏。

validate_contract 从初态检查整个输入；repair_contract 只删除因依赖或前置条件失效的命令，并记录原因。两者均不访问原生目标。运行、生成和缩减共用同一前置条件及预期状态转换。后置条件和不变量仅在真实运行中检查。

## C 计数器示例

[契约模型与目标](../examples/adapter-starter/counter/contracts.mbt)复用既有 C 计数器。模型明确区分正常加法与越界拒绝，后置条件要求拒绝后值不变；模式 error 是人工错误路径示例。原生句柄位于目标内部，模型只保存逻辑句柄 ID 和值。

在 examples/adapter-starter 目录中构建并使用新的 cmd/contracts 命令：

```powershell
moon build --target native --deny-warn cmd/contracts
```

构建产物支持与原例相同的 run / generate / replay / shrink CLI；walk 生成器使用公共状态契约生成接口，默认生成器提供确定触发人工错误的较长轨迹。

完整自动验收由根目录 scripts/verify-sdk.ps1 执行。除旧 SDK 回归外，新入口验证 32 个正确场景、三策略缩减与独立失败重放、正确实现对照、无效依赖在工作进程前拒绝，以及跨进程输入一致性。控制台编译通过不代替完整验收记录；实际状态以本轮证据为准。

参考接口：[Hypothesis 状态测试](https://hypothesis.readthedocs.io/en/latest/stateful.html)、[PropEr 状态机回调](https://proper-testing.github.io/apidocs/proper_statem.html)。本项目是有边界的原生绑定工具，不声称已覆盖这些框架的全部功能。
