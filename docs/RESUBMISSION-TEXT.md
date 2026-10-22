# 复审表单填写材料

更新：2026-10-22。以下是项目技术说明及补充材料，不假设实际报名表的字段名称、长度或附件格式。申报者/队伍信息由本人填写；本文件不表示已修改报名表或已重新获批。

## 可复制的项目补充说明

MoonFFI Lab 是以 MoonBit 实现的原生 C/C++ 绑定有状态测试、失败重放和轨迹缩减工具。本轮依据反馈补齐四项能力：

1. 显式状态契约：提供初态、命令候选、前置条件、状态推进、后置条件和不变量接口，生成、验证与修整共享纯模型，并通过真实 C 目标核对结果和错误后的状态。
2. 常见 FFI 参数策略：支持布尔、32/64 位有/无符号整数、精确位模式浮点、Unicode 文本、字节、数组和可空值的有界生成与缩减；实际 C 消费者通过 1024 次参数操作及 23 项显式 ABI 边界。
3. 原生错误自动缩减：显式启用稳定崩溃位置或 ASan 调用帧签名，要求基线/最终各三次一致确认；Windows/Linux 的自有 crash/ASan 人工故障均通过三策略 32→2 步缩减、同位置重放、不同位置区分和正确实现对照。
4. Linux native：增加独立内容锁定的安装、构建、单测、SDK 和故障专项；Windows 七项与 Linux 验收均已在提交 7d2716dd345224402437466f41ee9a34564749cf 通过，原始产物和源码身份已核对。

已参考 Hypothesis 与 PropEr 官方接口文档整理功能对照。项目交付串行、有界的原生绑定测试设施，接入者仍需编写适配器及性质；不承诺成熟框架全面等价、任意库自动建模、同根因或全局最小。故障实证为自有人工示例，ASan 仅插桩列明的 C/C++ 单元，五项稳定性等控制只覆盖 crash 档；未声称发现未知上游缺陷。来源许可保留，开发使用 AI 辅助，参赛者需能说明设计与测试。独立使用者反馈及新版发布尚未计为已完成成果。

## 可附上的链接

- 仓库：https://github.com/serikaonoe123/moonffi-lab
- 固定验收源码：https://github.com/serikaonoe123/moonffi-lab/tree/7d2716dd345224402437466f41ee9a34564749cf
- Windows 七项 CI：https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586714
- Linux CI：https://github.com/serikaonoe123/moonffi-lab/actions/runs/39720586758
- [项目说明](HACKATHON-SUBMISSION.md)、[逐项回应](REVIEW-RESPONSE.md)、[框架功能对照](FRAMEWORK-COMPARISON.md)、[固定提交证据](evidence/main-acceptance-20261022.json)、[独立复现入口](INDEPENDENT-REPRODUCTION.md)。

## 提交前核对

核对申报人/队伍信息及实际表单要求，使用上述固定提交和对应 CI，不把旧 rc.1 附件描述成含有本轮新增功能。按实际字段粘贴说明、填写链接或上传所需材料；本文件不虚构已经获得独立用户反馈或审核通过。

组委会通知及 2026-10-22 核对的[官方页面源文案](https://github.com/moonbitlang/Hackathon2026/blob/a879c208b261ca500f65707d42504d06572fa9b0/src/App.tsx)均给出 2026-10-31 截止；实际表单字段和完整资格仍由申报者按正式章程核对。本文不代提交，也不自动联系组委会。
