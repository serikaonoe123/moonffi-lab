# 有界 FFI 参数策略

本轮新增接口及真实 C 消费者已纳入[固定提交验收](evidence/main-acceptance-20261022.json)；rc.1 源码不包含新增功能。ArgumentStrategy 负责生成、域检查与有限缩减，目标调用及性质判断由状态契约/适配器完成。

| 策略 | 具体输入与边界 |
|---|---|
| Boolean | JSON 布尔，true 缩到 false |
| Signed32 / Signed64 | 带上下界的精确十进制数字，完整支持 Int64 两端；不能先经 Double 转换 |
| Unsigned32 / Unsigned64 | 带上下界的无符号数字，含 UInt64 最大值 |
| Float64 | `$ffi_f64` 标签内保存 UInt64 位模式的十进制字符串，保留负零、非规格化数、无穷及 NaN payload；NaN/无穷分别显式启用 |
| Text | `$ffi_text` 标签内保存 Unicode 文本；长度按标量计数，包含 NUL、中文、组合字符和非 BMP；不接受孤立代理码元 |
| ByteBuffer | `$ffi_bytes` 标签内保存 0..255 的数组，不以 C 字符串终止规则解释 NUL |
| Sequence | 递归元素策略、最小/最大长度；缩减结构与元素 |
| Optional | null 或元素编码组成的可空联合，不区分多层 Option 的构造器层级 |

构造域支持最长 256 的文本/字节/数组、最大四层递归以及 4096 值预算。反向数值边界、错误长度和超预算域返回 Err。generate(seed) 为确定性生成，混入边界值；不宣称边界混合后的总体均匀分布。生成算法依赖当前锁定 core 的随机流，接入者应记录 generator_version 并保存具体输入。

shrink(value) 拒绝域外值，最多给出 128 个域内、唯一且严格下降的候选。只枚举有限候选，不能据此声称参数全局最小。整数向零方向缩减并保持边界；文本按 Unicode 字符删除及向 NUL 简化；字节/数组支持块删除及元素候选；浮点按位模式的绝对编码、符号顺序下降，候选仍受 NaN/无穷配置约束。

runner 对新类型使用 ffi_arguments_simpler，先比较类型语义而非 JSON 拼写长度。例如 false 虽然比 true 多一个字符，仍可接受且不允许反向。组合值逐分量检查，禁止用一个分量的下降抵消另一个的上升。原有不含新类型的数值适配器继续使用旧顺序；Step 的精确相等语义不变。

轨迹解码现在保留数字原文，以拒绝被误当成精确整数的小数/指数输入；这可能使原先经 JSON 规范化后被接受的非规范数字输入被整数适配器拒绝。生成并保存的标准十进制整数继续兼容。Float64 必须使用位标签，普通 JSON 数字无法提供上述浮点位模式保证。

## 真实 C 消费者

[ParameterContract / ParameterTarget](../examples/adapter-starter/counter/parameters.mbt)通过公开 core/runner 接口接入 C。bool、32/64 位有/无符号整数、Double、UTF-8 文本、字节、数组和可空值共十类操作接受实际 native 调用。数组通过数据与长度的加权校验核对 ABI；可空标量由 C 包装函数映射为 NULL/本地有效指针，不生成任意地址或代替原生资源模型。

cmd/parameters 的 walk 生成器使用公共命令/值策略。默认输入含有长噪声前缀与带 NUL 的文本；error 模式在 C 中有意截断 NUL，正确模式按长度拷贝。这是教学缺陷，不能作为未知上游缺陷发现。

scripts/verify-sdk.ps1 自动验证十类覆盖、16 个场景合计 1024 次 C 操作、23 个显式 C ABI 边界，以及三策略将 32 步输入缩为单步 NUL 文本、独立失败重放和正确实现对照。纯测试覆盖精确宽整数、IEEE 位往返、域边界、确定性、候选下降、反向边拒绝和配置预算。实际通过范围以本轮证据为准。
