# 原生崩溃与 ASan 错误缩减

原生错误签名是显式启用的观测协议。`Controller::new(..., native_errors=true)` 会在每次执行前后核对工作进程可执行文件的全部字节；CLI 接入方同时使用 `cli(..., native_errors=true)`，仅在独立工作进程内安装故障记录器。默认调用保持关闭。

崩溃记录须包含支持的异常/信号、细节和主可执行文件相对位置，且与进程实际退出码一致。退出码、最后一个步骤或任意模块地址不能单独成为签名。ASan 须有一个类别一致的诊断及前两层可定位调用帧；缺少这些证据时拒绝自动缩减。相同签名不等于同根因，签名不跨构建或控制器承诺稳定。

缩减共享现有的 plain/dependency/state 策略、预算及候选合法性检查；基线和最终各要求三次相同结果。超时、环境/协议错误和无签名异常不能成为可接受的替代失败。`deletion_minimal` 只表示完成已声明删除邻域的检查，不表示全局最短。

## Windows 复现

准备锁定工具链、MSVC x64 环境和 `moonbitlang/async@0.22.5` 源码后运行：

```powershell
& ./scripts/verify-native-errors.ps1
```

脚本在新结果目录分别创建普通与 ASan 源码副本，记录源码、工具链、运行时和二进制身份。普通副本运行专项单测。两个 profile 均对项目自有、明确标注的人工故障进行三策略缩减，并检查不同故障位置和正确实现对照。另有不稳定基线、最终确认不稳定、弱证据、预算和默认关闭五项控制，当前只在 crash 档运行；ASan 档尚未覆盖这些控制。ASan 仅插桩 `fixtures/native-errors/faults.c`，不覆盖 MoonBit 生成 C、运行时或 async stubs。

从指定 Git 提交导出并验收：

```powershell
& ./scripts/verify-clean.ps1 -Suite native-errors -WorkspaceTemp
```

成功报告在新目录的 `verification.json`，每个 profile 的 `checks/` 保留输入、原始 stderr、候选报告、缩减日志及重放。失败不会清理已有记录。该专项不替代六项既有行为/ASan/benchmark/generation/SDK/SQLite 回归。

## 已验证范围

早期本地专项结果见 [证据](evidence/native-errors-local-20261021.json)。Linux 和云端是否完成，以对应平台、提交的实际运行记录为准；不以配置文件存在作为成功证据。人工故障不计为未知第三方库缺陷。

统一验证脚本仍待指定提交的干净环境验收。首轮把 `pkg.generated.mbti` 自动生成文件误记为源码输入而在身份校验处失败；已修正复制与清单规则。2026-10-22 提供的 Windows 本地执行记录经只读核对，与原始源码清单、49 项单测日志、六次缩减、222 次候选执行及独立重放记录一致；本次核对未重新运行测试。五项控制仅覆盖 crash 档。

该次执行使用未提交工作区和手动准备的本地依赖缓存。仅有 async 源文件不保证干净工具链下的离线解析成功，`MOON_HOME` 绑定及缓存来源/就绪状态仍需形成完整的复现约定。已有结果不证明指定提交的干净导出、Linux 故障/ASan 或完整六项回归已通过；原有六项 Windows CI 尚未加入本专项。
