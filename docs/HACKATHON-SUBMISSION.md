# MoonFFI Lab 项目说明

状态核对：2026-11-03。最近验收源码基线为 [`666ddb4`](https://github.com/serikaonoe123/moonffi-lab/tree/666ddb4bb0cbf7c999b325730f115ca446bb6470)；Mooncakes 0.1.0 实验性库包及 GitHub rc.2 源码预发布已发布，参赛者已确认通过初审。发布身份与验收索引见 [项目状态](PROJECT-STATUS.md)。

**项目与问题。** MoonFFI Lab 以 MoonBit 实现原生 C/C++ 绑定的有状态测试、失败重放和轨迹缩减。绑定中的生命周期、共享引用和错误后状态，常需一串调用才能触发问题。工具保存具体操作及参数，在独立工作进程调用目标，再缩减为可交付的复现输入。核心模型与缩减调度由 MoonBit 实现；C/C++ 用于目标绑定及明确标注的测试 fixture。

**针对反馈完成的工作。** 新增显式初态、命令候选、前置条件、状态推进、后置条件及不变量接口，生成、验证、修整共享纯模型，实际返回值和目标观察值在执行阶段核对。参数策略覆盖布尔、32/64 位有/无符号整数、精确位模式浮点、Unicode 文本、字节、数组和可空值，并经真实 C ABI 消费者验证。原生错误缩减采用显式启用的崩溃位置或 ASan 调用帧签名，要求基线/最终各三次确认及相同失败；另补充 Linux x86_64 的独立安装、构建、单测、SDK 和原生故障专项。[逐项回应](REVIEW-RESPONSE.md)与[成熟框架功能对照](FRAMEWORK-COMPARISON.md)说明对应实现和边界。

**可核对成果。** 上述源码基线的 [Windows 七项 CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479198)、[Linux native CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479152)及[包与 Linux registry 验证](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479150)均通过。两个平台已有原生 crash/ASan 三策略 32→2 步缩减、独立重放和正确实现对照；Windows/Linux 均完成真实 Mooncakes 消费者验证。各轮计数和执行范围见[逐项回应](REVIEW-RESPONSE.md)、[原生错误记录](NATIVE-ERRORS.md)与[包发布记录](MOONCAKES-PUBLISHING.md)；从 Git checkout 按[独立复现入口](INDEPENDENT-REPRODUCTION.md)运行。

**定位与范围。** 本项目参考 Hypothesis、PropEr 的状态建模与值策略设计，交付面向原生绑定的串行、有界测试工具。接入者仍需编写适配器、模型及性质；不承诺任意库自动建模、完整符号返回值模型、并行状态机或与成熟框架全面等价。错误签名描述同一未变二进制中的观测位置，不证明同根因或全局最小。故障缩减的实证使用自有人工故障；未声称发现未知上游缺陷。ASan 仅插桩文档列出的 C/C++ 单元，crash/ASan 两档均已有五项控制验收，其中 ASan 弱证据控制使用合成诊断；Linux 不声称与 Windows 七项 suite 全面等价。

**来源、贡献与后续。** 自写代码为 MIT；既有 Eigen 绑定、头文件及历史随机流保留来源与许可，社区 SQLite 固定源码保持原样。上述旧材料不计为本期原创移植量，本期新增为通用协议、策略、错误缩减及跨平台接入验证。开发使用 AI 辅助，参赛者需理解并能说明设计与测试。独立使用者反馈仍待收集，不宣称最终赛事验收已通过。初审通过后无需再提交报名表，继续开发并维护 GitHub 即可；后续版本发布另行确认。历史草稿可从 [rc.1 阶段记录](https://github.com/serikaonoe123/moonffi-lab/blob/7d2716dd345224402437466f41ee9a34564749cf/docs/HACKATHON-SUBMISSION.md)查阅。
