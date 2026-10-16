# 编译期适配器

一个运行器由 `core`、`runner` 和适配器编译而成。两个实际入口分别见 `cmd/buffer-lab` 与 `cmd/eigen-lab`；`cmd/reducer-probe` 是用于验证缩减边界的合成测试程序。

实现 `core.Adapter` 的六项职责：

| 方法 | 约定 |
|---|---|
| identity / version | 稳定身份和适配器格式版本 |
| validate | 从初始纯模型校验完整轨迹及参数，不执行原生调用，不改变工作状态 |
| execute | 在工作进程执行一步，更新实际状态和参考模型，返回可观察的性质失败 |
| teardown | 清理仍保留的对象，完成适配器有能力观察的检查 |
| shrink_arguments | 返回有限的、更简单的参数候选，保持步骤 ID、操作和对象依赖不变 |

构造适配器时也不能触发受测调用，模块初始化同样需要保持纯逻辑。父进程只创建适配器、校验轨迹和生成候选。新工作进程会创建新的适配器实例。

每个 `Step` 有稳定 ID、操作名称、JSON 参数及 defines/uses/releases 三组逻辑对象 ID。引擎检查对象构造和使用顺序；适配器必须进一步检查声明与实际操作相符、尺寸与索引合法、错误输入属于 API 承诺处理的范围。稳定对象 ID 不能释放后再复用。

失败包含稳定 property ID、当前 step ID 和可读说明。缩减匹配 `property:<property ID>:<step ID>`，消息文本不参加指纹。指纹表示同一已声明性质在同一步骤失败，不是同一底层根因的证明。teardown 失败使用保留名称 `teardown`。

生成器是 `(UInt64, String, Int) -> Trace`；CLI 的三个参数对应 seed、fixture 模式和最大步数。使用确定性随机状态并限制对象、步数和数据大小；原始具体数据必须能无损序列化。当前两个生成器的长度上限都不会超过 CLI 的 `--steps`。

运行入口调用 `runner.cli(args, make_adapter, generate)`，捕获顶层错误后用退出码 2 结束。不要在工厂函数或父进程读取/修改目标原生资源。`--worker` 是内部调用入口，用户通常使用 run/generate/replay/shrink。

适配器验证版本不匹配时应明确拒绝。核心 schema 当前为 1；重放读取保存的具体轨迹，不重新解释 seed。`environment` 保存 fixture 模式和检测 profile；Eigen 还记录绑定和头文件版本。完整工具链与二进制哈希由验收脚本的 `verification.json` 记录，直接单次 CLI 输出尚不自动补全这些环境信息。

参数缩减采用严格的 JSON 编码长度下降，避免适配器返回循环或等价候选导致停不下来；这是当前实现的限制。数组长度、尺寸等变化还须通过完整纯模型验证。缩减器当前只自动处理可识别的行为性质失败，其他结果保留证据而不接受为等价反例。
