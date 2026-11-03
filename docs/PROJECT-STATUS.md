# 项目状态

核对日期：2026-11-03。最近完成验收的源码基线为 [`666ddb4`](https://github.com/serikaonoe123/moonffi-lab/tree/666ddb4bb0cbf7c999b325730f115ca446bb6470)。本页整理已有发布与执行记录，不表示文档更新后重新运行了测试。

## 发布与使用

- [Mooncakes `serikaonoe123/moonffi-lab@0.1.0`](https://mooncakes.io/docs/serikaonoe123/moonffi-lab) 已于 2026-10-30 发布；属于实验性 native 库包，不承诺稳定 API。发布源码为 `ab41b68`，仅含公开 core/runner 等 32 份文件，见 [发布验收](evidence/mooncakes-0.1.0-20261030.json)。
- GitHub 已发布 [rc.1](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.1) 和 [rc.2](https://github.com/serikaonoe123/moonffi-lab/releases/tag/v0.1.0-rc.2) 源码预发布。它们与 Mooncakes 库包的提交、文件集合和用途不同；没有将预发布改称稳定版。
- 安装、源码接入及 registry 消费方式见 [SDK 指南](SDK.md)和 [发布与复现](MOONCAKES-PUBLISHING.md)。Windows 和 Linux x86_64 均已有真实 registry 下载与消费者验证，见 [Windows 证据](evidence/mooncakes-0.1.0-20261030.json)和 [Linux 证据](evidence/linux-registry-consumer-20261031.json)。

## 验收与范围

上述源码基线的 [Windows 七项](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479198)、[Linux native](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479152)及 [Mooncakes 包与 Linux registry 检查](https://github.com/serikaonoe123/moonffi-lab/actions/runs/41181479150)均成功，共 10 个任务。复现时固定提交并记录实际结果，入口见 [独立复现指南](INDEPENDENT-REPRODUCTION.md)。

状态契约、十类有界 FFI 参数策略、原生崩溃/ASan 缩减及 Linux native 已实现并有对应执行记录。crash/ASan 两档的五项控制均已有 Windows/Linux 验收；ASan 弱证据控制使用明确标注的合成诊断，其余 ASan 控制运行插桩后的自有故障，见 [协议与限制](NATIVE-ERRORS.md)。

Linux 不声明与 Windows 全部 suite 等价；ASan 只覆盖列明的 C/C++ 单元，不覆盖全部生成代码、运行时或依赖。人工故障不计为未知上游缺陷，稳定签名不证明同根因或全局最小。开发工具链锁为 moonc/core `0.10.17+d971670cd`、moon/moonrun `0.1.20261023`、async `0.22.5`。

## 后续维护

独立使用者反馈仍待收集，自动化 CI 不替代真实使用者反馈；该反馈不属于已提供验收指南的硬性条件。参赛者已确认通过初审，无需继续把重新提交报名表作为待办。项目转入维护，后续代码变更须验证对应提交，后续版本发布另行确认。

带日期或固定提交的旧验收、发布草案与说明保留当时范围。文中的“尚未发布”“仅 crash 控制”等历史描述不代表当前状态；也不能把后来的成果算进旧提交、旧标签或旧附件。
