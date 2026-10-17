# 编译期适配器

一个运行器由 `core`、`runner` 和适配器编译而成。两个实际入口分别见 `cmd/buffer-lab` 与 `cmd/eigen-lab`；`cmd/reducer-probe` 是用于验证缩减边界的合成测试程序。

实现 `core.Adapter` 的以下职责：

| 方法 | 约定 |
|---|---|
| identity / version | 稳定身份和适配器格式版本 |
| validate | 从初始纯模型校验完整轨迹及参数，不执行原生调用，不改变工作状态 |
| execute | 在工作进程执行一步，更新实际状态和参考模型，返回可观察的性质失败 |
| teardown | 清理仍保留的对象，完成适配器有能力观察的检查 |
| shrink_arguments | 返回有限的、更简单的参数候选，保持步骤 ID、操作和对象依赖不变 |
| repair | 对删除后的候选运行新的纯模型，只删除无效步骤，并返回每步的删除原因 |

构造适配器时也不能触发受测调用，模块初始化同样需要保持纯逻辑。父进程只创建适配器、校验轨迹和生成候选。新工作进程会创建新的适配器实例。

每个 `Step` 有稳定 ID、操作名称、JSON 参数及 defines/uses/releases 三组逻辑对象 ID。引擎检查对象构造和使用顺序；适配器必须进一步检查声明与实际操作相符、尺寸与索引合法、错误输入属于 API 承诺处理的范围。稳定对象 ID 不能释放后再复用。

失败包含稳定 property ID、当前 step ID 和可读说明。缩减匹配 `property:<property ID>:<step ID>`，消息文本不参加指纹。指纹表示同一已声明性质在同一步骤失败，不是同一底层根因的证明。teardown 失败使用保留名称 `teardown`。

生成器是 `(UInt64, String, Int) -> Trace`；CLI 的三个参数对应 seed、fixture 模式和最大步数。使用确定性随机状态并限制对象、步数和数据大小；原始具体数据必须能无损序列化。当前两个生成器的长度上限都不会超过 CLI 的 `--steps`。

`runner.cli` 还接受可选 `generators` 映射，将名称关联到同类型的纯生成器；`--generator NAME` 在 run/generate 时选择，默认名称 `default` 使用原回调。Buffer 和 Eigen 均注册了 `stateful`，分别标记 `generator_version=buffer-stateful-1`、`eigen-stateful-1`；后者依当前矩阵形状选择合法索引及不兼容加法。新增该映射不要求修改 Adapter 或核心类型；名称不可替代保存在轨迹中的具体步骤。replay/shrink 拒绝 `--generator`，防止把保存输入重新解释成另一套生成结果。

运行入口调用 `runner.cli(args, make_adapter, generate)`，捕获顶层错误后用退出码 2 结束。不要在工厂函数或父进程读取/修改目标原生资源。`--worker` 是内部调用入口，用户通常使用 run/generate/replay/shrink。

适配器验证版本不匹配时应明确拒绝。核心 schema 当前为 1；重放读取保存的具体轨迹，不重新解释 seed。`environment` 保存 fixture 模式和检测 profile；Eigen 还记录绑定和头文件版本。完整工具链与二进制哈希由验收脚本的 `verification.json` 记录，直接单次 CLI 输出尚不自动补全这些环境信息。

参数缩减采用严格的 JSON 编码长度下降，避免适配器返回循环或等价候选导致停不下来；这是当前实现的限制。数组长度、尺寸等变化还须通过完整纯模型验证。缩减器当前只自动处理可识别的行为性质失败，其他结果保留证据而不接受为等价反例。

## 状态修整约定

2026-10-17 的开发版本新增必需的 repair 方法。简单适配器可直接调用 `core.repair_dependencies(trace)`，只处理对象可用性。Eigen 及合成边界探针使用该实现，并继续通过自己的 validate 校验语义。

需要语义修整时，实现 `core.StateModel.apply(step) -> String?`，再调用 `core.repair_with_model(fresh_model, trace)`。apply 接受一步时更新纯状态；拒绝时返回原因，必须保持状态不变。每次调用 repair 都使用全新模型，不能复用工作进程模型。

Buffer 示例将多个逻辑句柄映射到同一 BufferState。Resize 改变该资源的长度与数据，因此经其他别名进行的 Write 也按新的长度检查。若删除 Resize 使后续 Write 不合法，修整会删除该 Write；后续步骤仍按保留下来的状态演进。拒绝写入不改变正确参考模型。

引擎独立检查 repair 结果是原候选的子序列、顺序和具体输入不变、metadata 不变、每个删除恰有一条非空说明，并再次完整 validate。修整不得凭空补步骤、修正数值、重命名对象或替换失败类型。参数候选还必须保留被修改的步骤。错误修整器不能获得 deletion_minimal=true。

当前通用实现为便于核验而对每个前缀重新检查依赖，最坏为二次复杂度；输入受 4096 步上限约束，CLI 生成最多 256 步。尚未将复杂模型视为不可信代码，也不能强制阻止适配器违反“拒绝不得变更状态”的契约；需要适配器测试验证此约定。
