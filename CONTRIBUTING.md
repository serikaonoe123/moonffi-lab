# 贡献与复现反馈

欢迎第一次使用、运行失败或文档卡点的反馈。先按 [独立复现入口](docs/INDEPENDENT-REPRODUCTION.md) 选择明确的提交；不要求先完成全部测试才能报告问题。

可以使用 [GitHub 复现反馈表单](https://github.com/serikaonoe123/moonffi-lab/issues/new?template=independent-reproduction.yml)，也可以在本地填写 [反馈模板](docs/templates/INDEPENDENT-REPRODUCTION.md)，由你决定是否提交。表单不会预选“独立使用者”或“全部通过”，也不会自动指定其他人。

请记录实际提交、安装/依赖来源、执行命令、各项结果及第一个卡住的步骤。未运行的项目写“未执行”；权限拒绝时保留原文并停止对应操作。第一次失败的日志应保留，重试使用新输出目录。

如果参与过对应代码的开发或验证，请注明；开发者、本机自动化和托管 CI 的结果仍有价值，但不能代替独立使用者反馈。报告成功也不等于发现了未知上游缺陷。

代码变更先说明具体触发条件、修复后的行为和验证范围。涉及资源/状态模型时补能区分旧行为和新行为的验证；生成规则、编码或语义变化须审视 adapter_version / generator_version 及历史输入重放。运行入口见 [复现指南](docs/REPRODUCIBILITY.md)。

当前源码的 Windows/Linux 已验证范围见[复审说明](docs/HACKATHON-SUBMISSION.md)与[固定提交证据](docs/evidence/main-acceptance-20261022.json)；[历史 v0.1 候选范围](docs/RELEASE-PLAN.md)仍按其冻结记录解释。公开发布、registry 包和向上游发送消息由维护者另行决定，提交反馈不会自动触发这些动作。
