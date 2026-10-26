# mmTV

代码仓库：[Chiuvenz/mmTV](https://github.com/Chiuvenz/mmTV)。

以 Mac mini 为家庭计算主机，提供遥控器优先的电视界面、游戏、第三方视频、Apple Music、私人影像馆、Home Assistant、Hermes AI 与手机/平板控制。

当前已有 macOS 原生开发预览版，阶段为 V0.1 内核 + V0.2 通用游戏/视频应用接入。真实电视、遥控器、具体游戏与两款视频客户端的完整链路尚未验收，未宣告 V0.2 产品验收完成。

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
- 七个独立功能 target；音乐和照片有手动权限验证接口，HA/AI/多终端为待接入入口。

## 文档

- [技术架构方案](ARCHITECTURE.md)
- [版本节奏与验收](ROADMAP.md)
- [开发与运行](docs/DEVELOPMENT.md)
- [当前实现与验收记录](docs/STATUS.md)
- [视频客户端接入记录](docs/VIDEO-INTEGRATIONS.md)

开发在 MacBook 进行；首个可运行包即可部署到 Mac mini 验证真实电视链路。Google Drive 照片同步、完整 MusicKit 播放器、影像馆、HA/Hermes 连接、网络控制与 TVCompat 仍按后续阶段推进。
