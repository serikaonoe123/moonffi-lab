# MoonFFI Lab v0.1.0 发布说明草稿

状态：实验性源码候选，未发布。具体候选提交、文件清单和 SHA-256 以本地 `candidate.json` 为准；以下不是已完成的发布公告。

MoonFFI Lab 用 MoonBit 为原生绑定生成有状态调用序列，在独立进程中保存执行证据，并把可稳定重放的性质失败缩减为更小的具体输入。

本候选包含 core/runner 的源码接入协议，三种删除策略、参数候选、预算及重复确认，正常/崩溃/超时/协议错误分类，以及可审计的候选与邻域记录。Buffer 的行为缺陷和计数器 error 是人工教学目标；Eigen 使用有来源清单的既有绑定。新增社区 SQLite 示例用同一公开协议检查参数绑定、查询状态与连接/语句生命周期，没有修改上游绑定，也未发现未知上游缺陷。

已有运行基线是 [提交 1f065527 的六项 Windows CI](https://github.com/serikaonoe123/moonffi-lab/actions/runs/39248905440)：69 主模块、6 SDK、48 上游 SQLite、8 SQLite 适配测试，96 SQLite 隔离场景，704 Buffer/Eigen 生成场景及 189 次固定缩减验证通过，产物已核对。该记录只覆盖其自身提交；新候选的 CI 须另行记录。

运行需要 Windows x64、MSVC C++ 工作负载和 Windows SDK。完整复现入口使用 PowerShell 7.5+。工具链按归档/二进制/core 源码摘要锁定，编译器实际自报 `v0.10.16+b1a0e846e (2026-10-16)`；这是验收所用官方 latest 包的身份，不据此声称对应最新正式发行标签。

范围限制：仅 Windows native 完整验收；公开 API 属实验性源码接口，未发布 registry SDK。确认失败不等于全局最短或同底层根因，删除最小不等于参数最小；仅符合指纹要求的性质失败自动缩减。ASan 只覆盖记录中的 C/C++ 单元，不覆盖 SQLite、整个运行时或全部原生分配，显式关闭不等于堆泄漏证明。

开始复现请参阅 [独立复现入口](INDEPENDENT-REPRODUCTION.md)、[适配器指南](ADAPTERS.md) 和 [SDK 示例](SDK.md)。项目自写代码使用 MIT；历史随机流、Eigen 及外部 SQLite 的许可和来源分别保留，见 [冻结范围与来源要求](RELEASE-PLAN.md)。
