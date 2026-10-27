# mmTV

代码仓库：[Chiuvenz/mmTV](https://github.com/Chiuvenz/mmTV)。

以 Mac mini 为家庭计算主机，提供遥控器优先的电视界面、游戏、第三方视频、Apple Music、私人影像馆、Home Assistant、Hermes AI 与手机/平板控制。

当前已有 macOS 原生开发预览版，阶段为 V0.2 MacBook 开发候选。真实电视、遥控器、具体游戏、账号与音频链路尚未在 Mac mini 验收，未宣告 V0.2 产品验收完成。

mmTV 是启动器与壳：Music / Photos / HA / Hermes 为壳内模块；第三方视频客户端（如 BiliTVMac）为独立 App，源码在 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)，由壳按 Bundle ID 打开。物理遥控器由 [mmTV Remote](https://github.com/Chiuvenz/mmTVRemote) 独占。mmTV 只消费其注入的标准按键与手柄输入，负责电视界面内的焦点、返回栈和业务动作。

## 运行

用 Xcode 打开 mmTV.xcodeproj 运行；或在项目根目录执行：

```sh
./Scripts/test.sh
./Scripts/build.sh
open dist/mmTV.app
```

build.sh 使用已安装的 XcodeGen 生成工程；所有 Swift 模块均为本地源码，无第三方 Swift 包依赖。输出为本机 ad-hoc 签名预览包，正式跨机分发需另做签名与公证。

## 已实现

- 原生客厅主页、方向键焦点、手柄导航、返回与全局 Home 快捷键。
- 游戏/视频应用目录，添加、编辑、启停模块、导入与导出配置。
- .app 或可执行文件启动、启动器 Bundle ID 跟踪、应用激活和退出后恢复。
- 路径与外置资源离线检查，参数数组传递，原子配置写入及上一份备份。
- `.app` 跨机器自动重定位、入口健康状态、运行事件记录与诊断报告导出。
- VacuumTube 安装检测与接入（官方 v2.0.1 因签名无效暂不自动安装）；BiliTVMac（`com.mmtv.bilitv`，仓外 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)）可由主壳自动检测并以 `--tv-fullscreen` 启动。
- 七个独立功能 target；音乐和照片有手动权限验证接口，HA/AI/多终端为待接入入口。
- mmTV Remote V0.3 已独立交付；未来手机/平板使用的 `Remote` 模块是另一项网络控制能力。

## 文档

- [技术架构方案](ARCHITECTURE.md)
- [版本节奏与验收](ROADMAP.md)
- [开发与运行](docs/DEVELOPMENT.md)
- [当前实现与验收记录](docs/STATUS.md)
- [视频客户端接入记录](docs/VIDEO-INTEGRATIONS.md)
- [第三方适配器仓库](https://github.com/Chiuvenz/mmTVAdapters) · [Integrations 说明](Integrations/README.md)

开发在 MacBook 进行；首个可运行包即可部署到 Mac mini 验证真实电视链路。Google Drive 照片同步、完整 MusicKit 播放器、影像馆、HA/Hermes 连接、网络控制与 TVCompat 仍按后续阶段推进。
