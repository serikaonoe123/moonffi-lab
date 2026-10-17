# 从外部模块接入 MoonFFI Lab

本轮提供可编译的独立模块 [adapter-starter](../examples/adapter-starter/README.md)，用一个小型 C 计数器展示 SDK 的完整流程。示例只导入公开 `core`/`runner`，不需要修改引擎。当前交付形式是源码工作区，没有发布 Mooncakes 包，也没有将 0.1.0 的接口声明为长期稳定 API。

## 1. 建立模块与工作区

仓库中的 `examples/moon.work` 把引擎目录 `..` 和示例 `adapter-starter` 作为成员。示例 `moon.mod` 声明 `serikaonoe123/moonffi-lab@0.1.0` 和 `moonbitlang/async@0.22.5`。本地引擎从工作区源码解析，async 从 registry 或已有工具缓存恢复。[MoonBit 模块文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html)说明了通过 `moon.work` 关联本地模块的方式；本例已用仓库锁定的工具链实际编译验证。

复制到仓库外时，可以使用如下目录结构：

```text
dev/
  moon.work
  moonffi-lab/       # 已授权访问的本仓库源码
  my-counter/        # 复制 adapter-starter，修改模块名和包导入
```

对应的 `dev/moon.work`：

```moonbit
members = ["moonffi-lab", "my-counter"]
```

不要只改 `moon.mod` 的名称而忘记入口中的 counter 包导入路径。保持 async 版本与本仓库一致；工作区会使用成员源码，因此具体来源必须同时看依赖图和源码哈希。

## 2. 定义操作及依赖

在 `counter/adapter.mbt` 中定义五种操作：New、Add、RejectAdd、Check、Close。`operation_step` 是 JSON 参数与 `defines/uses/releases` 的唯一转换点；validate 会重新计算声明并逐项核对，防止伪造依赖。

稳定的步骤 ID 用于失败指纹，对象 ID 在关闭后不复用。保存输入包含具体参数、生成器版本、模式和 seed；重放读取步骤，seed 只是来源记录。

计数器值限制在 -100–100，delta 限制在 -200–200。Add 只允许结果仍在范围内；RejectAdd 只允许越界结果，并要求错误返回后状态保持原值。C 层先用 int64 计算，避免求和本身发生有符号溢出。该约束是本教学目标的契约，不是通用数值缩减规则。

## 3. 实现纯模型与 Adapter

`core.Adapter` 的全部方法约定见 [适配器说明](ADAPTERS.md)。本例的实现对应如下：

| 入口 | 必须保持的性质 |
|---|---|
| `CounterAdapter::new(trace)` | 只分配 MoonBit 模型与容器，不创建原生计数器 |
| `validate` | 从新模型检查完整轨迹、模式、参数及声明；不复用执行状态 |
| `repair` | 使用新 `Model` 调用 `repair_with_model`，只删除失去前提的操作 |
| `execute` | 仅在工作进程调用 C，检查返回值及模型观测，返回稳定 property/step ID |
| `teardown` | 在失败后也关闭未关闭的原生句柄，再检查逻辑存活数 |
| `shrink_arguments` | 仅返回候选；完整校验及 JSON 长度下降由引擎执行 |

`StateModel.apply` 拒绝一步时必须保持状态不变。本例删除某次负增量后，后续正增量可能越界；状态修整会删除它，并记录 `add precondition violated`，而不会重写 delta。

示例测试独立枚举七步轨迹的全部 128 个子集，以布尔存活状态和标量值计算预期保留步骤。另有 C 调用计数审计，验证构造器、生成、校验、修整及参数候选阶段没有调用目标操作。审计是本例的检查手段，不是引擎对任意适配器的沙箱保证。

## 4. 注册 CLI 与生成器

`cmd/main` 显式导入 `moonbitlang/async`、`runner`、counter 包和 env；`async fn main` 需要 async 包导入。入口调用公共 `runner.cli(args, factory, generator, generators~)`，捕获顶层错误并以 2 退出。

默认 `counter-contract-1` 在 CLI 的步数预算内生成固定契约场景，确保人工 error 模式被观察。可选 `walk` 对应 `counter-walk-1`：最多一个存活计数器，按状态选择合法操作，不附加固定触发后缀。生成结果在两个模式下步骤相同；未知模式由适配器拒绝。生成器回调没有 FFI。

运行、保存失败、缩减、重放及切换正确实现的完整命令见 [可执行示例](../examples/adapter-starter/README.md)。缺陷执行、确认失败的缩减和缺陷重放退出 1，正确实现退出 0；参数/无效输入退出 2。`confirmed` 与 `deletion_minimal` 含义不同，不能仅凭退出 1 宣称最小。

## 5. 验收外部消费方式

在仓库根目录运行：

```powershell
& .\scripts\verify-sdk.ps1
# 需要离线复验时，明确给出固定版本依赖源码
& .\scripts\verify-sdk.ps1 -OfflineDependencySource .\.mooncakes
```

脚本在新工作区中只复制引擎的 core、runner、模块清单和独立消费者；不会复制引擎 fixtures、vendor、cmd、构建产物或 Git 数据。它核对 `moon tree` 的模块路径，并要求引擎包图恰为 core/runner；随后使用 warning 作为错误的检查、6 项单测及全新 native 构建。第六项从独立模块消费公开的 `core.shrink_int`，核对元数据、正负错误边界及纯候选阶段没有原生调用。下面的五项单测和执行计数是早期验收记录；本轮整数候选结果见 [缩减器验证记录](VALIDATION.md)。

本地显式依赖源码复用验收在 `results/sdk-external-offline-20261017`：

| 验收项 | 结果 |
|---|---|
| 示例单测 | 5/5 |
| 独立纯 walk oracle | 768 条轨迹 |
| 独立修整子集 oracle | 128 个子集 |
| 单测中的 native walk | 32 条，每条 64 步 |
| 独立进程正确场景 | 契约 8 + walk 32，全部通过 |
| 人工 error 缩减 | 32 → 2 步，26 次执行，指纹保持 |
| 最终真子集独立重放 | 3 个，没有保持原指纹 |
| 切换正确实现重放 | Pass |
| 6 次预算 | execution_budget；confirmed=true，deletion_minimal=false |
| 非法依赖与未知生成器 | 预检拒绝；没有工作进程步骤证据 |
| 跨进程确定性、输出目录复用拒绝 | 通过，已有报告哈希不变 |

默认依赖恢复路径另保留在 `results/sdk-external-cache-20261017`，标记为 `registry-or-tool-cache`，不把工具缓存命中写成全新下载。显式离线路径使用 `explicit-local-source-cache`，依赖源码作为工作区成员并记录文件哈希。两种方式都是当前主机的新项目目录构建，不能据此宣称独立机器验证。机器可读摘要见 [SDK 验收快照](evidence/sdk-20261017.json)。

CI 增加独立 sdk suite，通过 `verify-clean.ps1 -Suite sdk` 从提交归档验证。云端成功与否需按对应提交的实际任务和产物确认。

## 6. 替换成自己的绑定

先修改 C 目标和 `Operation`，再实现参数前置条件、纯状态转换和有意义的观测性质；将错误返回与状态保持分开检查。随后补独立模型测试，注册确定性生成器，最后重跑保存、缩减及修复后重放流程。

计数器 error 是人工行为缺陷；本例没有发现未知真实缺陷。C 文件只经过 behavior 验收，既有 Buffer/Eigen ASan profile 不覆盖它。逻辑关闭计数不是堆泄漏检测；最终两步结果的删除证据也不代表任意参数或任意输入的全局最短。
