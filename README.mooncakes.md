# MoonFFI Lab

MoonBit 原生 C/C++ 绑定的串行、有界状态测试引擎：生成调用序列，在独立进程执行，保存具体失败输入，再按相同结果类别和稳定指纹进行缩减与重放。

## 环境

本模块仅支持 native。已验证 Windows x64/MSVC 与 Ubuntu 24.04 x86_64/GCC；两平台的测试范围不同。项目使用固定内容的 moonc/core `0.10.17+d971670cd` 和 async 0.22.5，满足竞赛要求的 moonc >=0.10.16；不承诺任意新旧工具链组合。Windows C FFI 需要 MSVC C++ 工作负载与 Windows SDK。

## 安装与最小调用

在你自己的 MoonBit 模块中运行：

```sh
moon add serikaonoe123/moonffi-lab@0.1.0
```

在 `cmd/main/moon.pkg` 中导入：

```moonbit
import {
  "serikaonoe123/moonffi-lab/core" @lab,
}
pkgtype(kind: "executable")
```

`cmd/main/main.mbt`：

```moonbit
fn main {
  println(@lab.shrink_int(100))
}
```

运行 `moon run --target native cmd/main`。此最小例只演示参数候选接口；完整状态模型、C 目标及独立工作进程示例见 [计数器消费者](https://github.com/serikaonoe123/moonffi-lab/tree/main/examples/adapter-starter)和 [SDK 指南](https://github.com/serikaonoe123/moonffi-lab/blob/main/docs/SDK.md)。使用完整执行器时还需导入 `serikaonoe123/moonffi-lab/runner` 和 async，并定义适配器、模型及待检性质。

## 包含范围

- `core`：轨迹协议、显式状态契约、十类有界 FFI 值策略、参数候选与删除/状态修整逻辑。
- `runner`：独立进程控制、失败保存、plain/dependency/state 缩减、稳定性确认和具体输入重放。
- `runner/native_guard.c`：公开 native runner 所需的自有 C stub。

Buffer/Eigen/SQLite 示例、人工故障 fixture、测试驱动脚本、历史证据、工具包和依赖缓存不随此库包上传；可从 GitHub 查看带来源和许可的完整工程。完整验证入口和既有结果见 [复现指南](https://github.com/serikaonoe123/moonffi-lab/blob/main/docs/INDEPENDENT-REPRODUCTION.md)。

## 限制与许可

0.x 源码 API 仍属实验性。接入者负责定义操作、资源依赖、模型和性质；不提供任意外部库自动建模。删除邻域最小不等于参数最小、全局最短或同根因证明。原生错误缩减必须显式启用、验证同一工作程序的完整字节身份并保留稳定指纹；ASan 必须由消费者自行插桩，不覆盖所有代码或分配。

本库包自写代码使用 [MIT](https://github.com/serikaonoe123/moonffi-lab/blob/main/LICENSE)。GitHub 完整工程另含原样保留许可的第三方来源，未纳入本库包。人工故障验证不计为未知上游缺陷。
