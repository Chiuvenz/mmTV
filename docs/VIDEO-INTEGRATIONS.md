# 视频应用接入记录

状态：候选路线已核实，通用本机应用/启动器适配已实现，以下两个客户端的完整播放链路尚未验收。

## YouTube

候选：[VacuumTube](https://github.com/shy1132/VacuumTube)，开源 YouTube Leanback 桌面客户端。

本次通过仓库发布 API 核实 v2.0.1 包含 VacuumTube-arm64.dmg / VacuumTube-arm64.zip 等 macOS 构建，应用 Bundle ID 为 `rocks.shy.VacuumTube`。该版本号为 2026-10-26 的查询记录，后续安装以官方发布页为准。

接入：用户安装官方 macOS 版本后，mmTV 会自动检测并显示“接入”；也可以在“看点什么 → 添加视频应用”手动选择实际 `.app`。首次安装、启动与系统信任提示按正常 macOS 流程处理；本项目未自动下载安装或修改系统信任设置。

待验收：匿名浏览、账号登录、视频播放、声音、方向键、全屏、Home 返回、退出恢复。不能将入口可启动视为这些项目全部通过。

## Bilibili

候选：[BiliTV for webOS](https://github.com/asdf17128/bili-webos)，React/Vite 电视客户端，具有独立 webOS 服务端能力。

本次核实其应用目录与构建定义。2026-10-26 的上游最新发布为 v2.5.1，产物是 `com.biliwebos.app_2.5.1_all.ipk`，依赖 webOS 的 Luna service 与本机媒体代理，不能直接当作 macOS `.app` 安装。源码下载尝试未取得可用 checkout，未进入移植构建和真实播放验证。

已新增可复现的 `Scripts/fetch-bilitv.sh`：固定下载官方 v2.5.1 `.ipk`，校验 GitHub 发布的 SHA-256 后解包到不入库的 `External/BiliTV/`。发布包审计确认前端依赖 `PalmServiceBridge`，Node 服务依赖 `webos-service`、`/media/internal` 状态目录和 `127.0.0.1:7654` 媒体代理。适配边界记录在 `Integrations/BiliTV/adapter-manifest.json`。

下一步：实现 PalmServiceBridge 到本地 IPC 的 shim、macOS 状态目录和 sidecar 生命周期，再验证匿名列表、二维码登录、媒体请求与实际解码，最后打包独立 `BiliTVMac.app` 接入。TV Web Runtime 先服务这一款应用，确认复用需求后才公共化。

当前 UI 清楚标注“需要移植打包”，不会自动打开普通 B 站桌面网页来声称完成电视版集成。

## 所有第三方应用共用的能力边界

当前实现：添加/编辑入口、路径与资源检查、跨 Mac 应用重定位、参数数组启动、已有进程激活、可观测的退出恢复、运行诊断、全局 Home、人工记录 TV 交互已验证状态。

当前未实现：第三方应用内部按键注入、强制全屏、登录代理、媒体进度读取和统一播放控制。因此不展示第三方播放进度或续播能力。遥控器按键映射由实际客户端支持和外围遥控组件配置决定。
