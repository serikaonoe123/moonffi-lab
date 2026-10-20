# MoonFFI Lab：十月黑客松项目说明草稿

截至 2026-10-20，尚未通过本文提交报名或获得赛事审核。参赛者与队伍信息由本人在官方表单确认。本页可作为一页项目说明的内容基础；实际表单与正式章程需参赛者复核。

**项目与问题。** MoonFFI Lab 是以 MoonBit 实现的原生绑定测试与反例缩减工具。C/C++ 绑定的生命周期、共享引用、错误后状态常需一串调用才会出错；仅保存随机 seed 或最后一条日志，难以交付可靠复现。

**本期工作。** core/runner 提供可复用适配协议、具体轨迹保存、独立工作进程、异常与超时分类、三种缩减策略、状态修整、参数缩减、预算与重复确认。独立 C 计数器演示如何接入；未经修改的社区 SQLite 绑定用于验证公共接口能够支持真实消费者。核心调度、模型和缩减逻辑可从 [core](../core) / [runner](../runner) 审阅。

**可验收成果。** [公开仓库](https://github.com/serikaonoe123/moonffi-lab)保留提交与失败修复记录；[rc.1 预发布](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1)固定代码提交 `23893d5bb3a231a21df10db506d8da821a7e984d`。该提交[六项 Windows CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39361478378)通过并核对产物，涵盖主模块、SDK、SQLite 测试，704 个 Buffer/Eigen 场景、96 个 SQLite 场景及 189 次固定缩减。按[复现入口](INDEPENDENT-REPRODUCTION.md)从 Git checkout 运行；环境为 Windows x64、MSVC、PowerShell 7.5+ 和内容锁定的 MoonBit 工具链。

**来源与贡献边界。** 自写代码为 MIT；Eigen 绑定/头文件和历史随机流保留原来源及许可，SQLite 使用固定的社区源码。既有 Eigen 材料不计为本期原创移植量，新增价值是通用测试、缩减引擎和接入验证，不能将同一工作重复或拆分申报。来源细节见[范围清单](RELEASE-PLAN.md)及[SQLite 记录](SQLITE-INTEGRATION.md)。

**限制与后续。** Buffer/计数器缺陷为人工示例，尚未发现未知上游缺陷；当前完整验证限 Windows native，ASan 仅覆盖记录中的 Buffer/Eigen C/C++ 单元。独立使用者反馈待完成，后续据反馈完善接入体验。开发使用 AI 辅助；参赛者需自行审阅并能说明设计、测试及这些限制。

报名依据：[官方十月赛事页面](https://moonbitlang.github.io/Hackathon2026/)及[官方页面源文案](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx)。截至查阅日，页面要求参赛信息、公开仓库及一页说明，报名与验收截止 2026-10-31。页面列出的语言、运行测试、实质工作、许可和 AI 理解要求已有项目材料可对照；队伍信息、报名次数、入群及实际审核状态未核实。正式章程与报名表的飞书内容本次未能读取，不能宣称已核对所有字段或已满足全部资格条件。
