# 视频应用接入记录

状态：通用本机应用/启动器适配已实现；BiliTVMac 达到 MacBook 开发候选，VacuumTube 与两者的账号/目标设备链路仍待验收。

## YouTube

候选：[VacuumTube](https://github.com/shy1132/VacuumTube)，开源 YouTube Leanback 桌面客户端。

本次通过仓库发布 API 核实 v2.0.1 包含 VacuumTube-arm64.dmg / VacuumTube-arm64.zip 等 macOS 构建，应用 Bundle ID 为 `rocks.shy.VacuumTube`。在 M4 Mac mini 上分别检查官方 ZIP 与 DMG，两者内部 App 都没有 `_CodeSignature` 资源封印，`codesign --verify --deep --strict` 与 Gatekeeper 均失败。因此当前不自动安装、不重签，也不建议绕过系统安全运行；等待上游提供有效 Developer ID 签名，或另行审计源码后自行构建。

接入：用户安装可信的 macOS 构建后，mmTV 会自动检测并显示“接入”；也可以在“看点什么 → 添加视频应用”手动选择实际 `.app`。本项目不会自动下载安装、重签第三方 App 或修改系统信任设置。

待验收：匿名浏览、账号登录、视频播放、声音、方向键、全屏、Home 返回、退出恢复。不能将入口可启动视为这些项目全部通过。

## Bilibili

候选：[BiliTV for webOS](https://github.com/asdf17128/bili-webos)，React/Vite 电视客户端，具有独立 webOS 服务端能力。

本次核实其应用目录与构建定义。2026-10-26 的上游最新发布为 v2.5.1，产物是 `com.biliwebos.app_2.5.1_all.ipk`，依赖 webOS 的 Luna service 与本机媒体代理，不能直接当作 macOS `.app` 安装，因此由 mmTV 提供独立适配器。

`Scripts/fetch-bilitv.sh` 固定下载官方 v2.5.1 `.ipk`，校验 GitHub 发布的 SHA-256 后解包到不入库的 `External/BiliTV/`。发布包审计确认前端依赖 `PalmServiceBridge`，Node 服务依赖 `webos-service`、`/media/internal` 状态目录和 `127.0.0.1:7654` 媒体代理。适配边界记录在 `Integrations/BiliTV/adapter-manifest.json`。

`Integrations/BiliTVMac/` 已实现独立 Electron 运行时、PalmServiceBridge 到本地 IPC 的 shim、macOS 状态目录和服务生命周期，并打包为 Bundle ID `com.mmtv.bilitv`。MacBook 自动烟测已验证匿名列表、方向焦点、真实媒体解码起播和返回；二维码登录、账号状态、可听音频与目标电视链路留到实机验收。运行时保持本应用私有，确认第二个复用需求后才公共化。

当前 UI 会检测 `com.mmtv.bilitv` 并提供接入；未安装时链接到适配器构建说明，不会退回普通 B 站桌面网页来声称完成电视版集成。

## 所有第三方应用共用的能力边界

当前实现：添加/编辑入口、路径与资源检查、跨 Mac 应用重定位、参数数组启动、已有进程激活、可观测的退出恢复、运行诊断、全局 Home、人工记录 TV 交互已验证状态。

第三方应用的通用按键映射由独立的 [mmTV Remote](https://github.com/Chiuvenz/mmTVRemote) 按 Bundle Identifier Profile 负责；普通快捷键不能覆盖的复杂流程才评估受控 App Adapter。mmTV 仍未实现登录代理、媒体进度读取和统一播放控制，因此不展示第三方播放进度或续播能力。BiliTVMac 自身支持方向键并由 mmTV 传入全屏启动参数；其他客户端的全屏和实际按键效果仍逐 App 验收。
