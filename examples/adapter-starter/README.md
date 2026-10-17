# 外部适配器起步示例

这是独立模块 `moonffi-example/counter-lab`。它仅通过公开的 `core` 和 `runner` 包接入 MoonFFI Lab，没有引用 Buffer、Eigen 或引擎内部测试。上一级的 `moon.work` 将本模块与仓库源码关联；当前使用源码工作区接入，没有将 SDK 发布到 registry。

C 计数器接受 -100–100 的值，成功加法更新状态，越界加法承诺返回 -1 并保持原值。`--mode error` 是明确标注的人工缺陷：越界返回错误时把值清零。它用于教学与验收，不是发现的真实漏洞。

## 构建和演示

需要仓库 README 声明的 Windows x64、PowerShell 7、MoonBit 和 MSVC 工具链。在仓库根目录运行：

```powershell
Set-Location examples/adapter-starter
# 第一次允许恢复依赖；后续构建使用 frozen
moon check --target native --deny-warn counter cmd/main
moon test --target native --frozen --deny-warn -j 1 counter
moon build --target native --frozen --deny-warn cmd/main
$counter = '..\_build\native\debug\build\moonffi-example\counter-lab\cmd\main\main.exe'

& $counter run --generator walk --cases 10 --out results/walk
& $counter run --mode error --out results/broken
& $counter shrink results/broken/case-1/case.json --out results/small
& $counter replay results/small/reduced.json --out results/replay
& $counter replay results/small/reduced.json --mode correct --out results/fixed
```

输出目录必须尚不存在，重复演示请更换目录名。上述五条执行命令的预期退出码分别为 0、1、1、1、0。默认契约案例包含 32 步，在人工缺陷下可缩成两步：构造值 1 的计数器，进行越界加法；改用正确实现后通过。`--generator walk` 则按当前值和对象寿命选择合法操作，不保证观察人工缺陷。

一次性验收从仓库根目录运行：

```powershell
& .\scripts\verify-sdk.ps1
# 明确离线复用已安装的固定版本依赖源码
& .\scripts\verify-sdk.ps1 -OfflineDependencySource .\.mooncakes
```

脚本在新的结果目录准备独立工作区：只复制引擎的 core/runner 和此示例，不复制 fixtures/vendor/引擎命令或编译产物；核对依赖图后重新编译，再执行测试、重放、缩减与边界验收。原始证据保留，输出目录不能复用。

## 文件与替换点

| 文件 | 作用 |
|---|---|
| `moon.mod`、上级 `moon.work` | 模块依赖与本地源码解析 |
| `counter/moon.pkg`、`counter.c` | 外部 C 目标及 native stub 配置 |
| `counter/adapter.mbt` | 操作格式、纯校验/修整、FFI 执行、失败性质、teardown、参数候选 |
| `counter/generator.mbt` | 默认契约案例与额外 walk 生成器 |
| `counter/counter_wbtest.mbt` | 纯阶段调用审计、独立标量 oracle、128 个子集修整及原生检查 |
| `cmd/main` | 显式导入 async，调用公共 runner.cli 并返回退出码 |

接入自己的库时，先替换 C API 和操作含义，再实现纯模型与观测性质，最后修改模块名、导入路径和生成器。完整过程见 [SDK 指南](../../docs/SDK.md)，方法契约见 [Adapter 说明](../../docs/ADAPTERS.md)。

此示例只验收 behavior。主项目的 ASan profile 没有插桩本例 C 文件；`native_live()==0` 验证的是显式逻辑关闭，不是堆内存泄漏检测。删除最小性限于声明的策略和具体参数，不是任意输入的全局最短。
