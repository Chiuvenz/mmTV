# 视频应用接入记录

状态：通用本机应用/启动器适配已实现；BiliTVMac 适配器源码在 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)，VacuumTube 与两者的账号/目标设备链路仍待验收。

## YouTube

候选：[VacuumTube](https://github.com/shy1132/VacuumTube)，开源 YouTube Leanback 桌面客户端。

本次通过仓库发布 API 核实 v2.0.1 包含 VacuumTube-arm64.dmg / VacuumTube-arm64.zip 等 macOS 构建，应用 Bundle ID 为 `rocks.shy.VacuumTube`。在 M4 Mac mini 上分别检查官方 ZIP 与 DMG，两者内部 App 都没有 `_CodeSignature` 资源封印，`codesign --verify --deep --strict` 与 Gatekeeper 均失败。因此当前不自动安装、不重签，也不建议绕过系统安全运行；等待上游提供有效 Developer ID 签名，或另行审计源码后自行构建。

接入：用户安装可信的 macOS 构建后，mmTV 会自动检测并显示“接入”；也可以在“看点什么 → 添加视频应用”手动选择实际 `.app`。本项目不会自动下载安装、重签第三方 App 或修改系统信任设置。

待验收：匿名浏览、账号登录、视频播放、声音、方向键、全屏、Home 返回、退出恢复。不能将入口可启动视为这些项目全部通过。

## Bilibili

候选：[BiliTV for webOS](https://github.com/asdf17128/bili-webos)，React/Vite 电视客户端，具有独立 webOS 服务端能力。

macOS 适配器 **BiliTVMac**（Bundle ID `com.mmtv.bilitv`）维护在独立仓库 [Chiuvenz/mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)（本地 `~/vibeCoding/mmTVAdapters`），不嵌入 mmTV 进程或本仓 `Integrations/`。

mmTV 侧契约：

1. 检测已安装的 `com.mmtv.bilitv`
2. 以 Launch Services / `NSWorkspace` 打开，并传入 `--tv-fullscreen`
3. 未安装时引导至适配器仓库构建说明，不退回普通 B 站桌面网页

构建与烟测、上游 v2.5.1 拉取与 SHA-256、Electron 运行时细节见适配器仓库 README。

## 所有第三方应用共用的能力边界

当前实现：添加/编辑入口、路径与资源检查、跨 Mac 应用重定位、参数数组启动、已有进程激活、可观测的退出恢复、运行诊断、全局 Home、人工记录 TV 交互已验证状态。

第三方应用的通用按键映射由独立的 [mmTV Remote](https://github.com/Chiuvenz/mmTVRemote) 按 Bundle Identifier Profile 负责；普通快捷键不能覆盖的复杂流程才评估受控 App Adapter。mmTV 仍未实现登录代理、媒体进度读取和统一播放控制，因此不展示第三方播放进度或续播能力。BiliTVMac 自身支持方向键并由 mmTV 传入全屏启动参数；其他客户端的全屏和实际按键效果仍逐 App 验收。
