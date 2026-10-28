# 实现与验收记录

日期：2026-10-28。当前为开发预览构建，版本号 0.2.0-dev；版本号不代表 ROADMAP.md 中的产品验收门槛已经全部通过。

Mac mini 已从 `main`（适配器拆分后）重建并安装 ad-hoc `mmTV.app`；本机钥匙串暂无 Apple Development 身份，故 mmTV Remote **未**在本轮重建（仍用既有 Development 签名的 0.3.1）。HDMI 保持 1920×1080。电视画面／账号／实体遥控仍待人工（见仓库外 next-steps／feature-roadmap）。

## 当前自主开发边界

先推进到 V0.2 的 MacBook 开发候选：可运行主应用、独立模块、游戏/视频接入框架和可安装构建。物理遥控器已经拆分为独立产品 mmTV Remote；mmTV 后续只维护应用内焦点与事件语义。账号登录、开发者授权和 Mac mini 电视链路仍需要目标设备配置后验收。

## 已实现并有自动化证据

- Swift 6 模块化 package 与 Xcode 应用工程，部署目标 macOS 15，arm64。
- Contracts/Core/Input/DesignSystem/MacHost/Games/TVApps/Music/PhotoGallery/Home/Assistant/Remote 编译边界。
- 主页、方向焦点、独立模块入口、应用入口编辑、设置、导入导出与全屏选项。
- 原子配置、上一份备份、拒绝高版本与无效入口；加载失败后阻止无意覆盖。
- 应用启动与激活；直接传递可执行文件参数；启动器与真正游戏 Bundle ID 分开跟踪。
- `.app` Bundle ID 元数据、跨 Mac 自动重定位与路径修复；旧版配置无需迁移即可继续读取。
- 入口健康检查、最近 50 条运行事件和可导出的本机诊断报告。
- VacuumTube 安装检测与一键接入目录；BiliTVMac 以独立 Bundle ID `com.mmtv.bilitv` 自动检测并带 `--tv-fullscreen` 接入。
- BiliTVMac 适配器（上游拉取、Electron 运行时、烟测）已迁至独立仓库 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)；本仓仅保留启动器契约与 `Integrations/README.md` 指针。
- 迁出前证据：BiliTVMac 在 MacBook / M4 Mac mini 跑通匿名接口、方向焦点、公开视频起播与返回；mmTV 加载全屏入口无启动错误。
- 全局 Control + Option + H 注册；手柄只在应用前台路由；外部游戏退出时恢复主页的状态管理。
- 输入路由已扩展到设置、模块弹窗、提示弹窗、编辑页和系统文件面板；设置和模块弹窗已用键盘等价遥控事件完成焦点高亮、移动、确认与返回实测。
- 设置页保留本机系统音量读取/加减与主界面音量 HUD；遥控器音量键改由 mmTV Remote 调整。当前输出设备不支持软件音量时会显式提示使用电视/音响。
- 独立仓库 [mmTVRemote](https://github.com/Chiuvenz/mmTVRemote) 已完成 V0.3，并完成 mmTV Profile 键盘注入：方向／确认／返回／Home／F2 菜单、系统音量；语音走全局提供商。mmTV 已删除 `XiaomiRemoteHID` 直连、输入监控授权 UI 与 Info.plist 输入监控说明。
- mmTV Remote 自动化测试通过；MacBook 已验证 RC003 连接和 Finder 前台 Profile 自动切换。mmTV Profile 实体回归、逐 App 手感、Typeless F20 以及 Mac mini HDMI 音量仍待人工验收。

自动化验证命令：`./Scripts/test.sh`。Swift 测试覆盖焦点边界、配置往返与备份、旧配置兼容、全屏配置键兼容、拒绝未来配置、异步入口可用性快照、参数校验、重复启动去重、连续确认防重入、禁用模块、失败恢复、当前应用退出恢复、真实子进程与参数不被 shell 展开、缺失资源拒绝、重复 ID 不覆盖已有配置、BiliTVMac 候选接入约束（Bundle ID / 全屏参数），以及键盘遥控映射（含 F2 菜单）。适配器 Node 测试改在 mmTVAdapters 仓库运行。

Xcode Debug 与 Release 构建均已成功。Release 应用通过 codesign --verify --deep --strict，ZIP 完整性检查通过；当前 MacBook 使用本机 Apple Development 身份和 Hardened Runtime，构建脚本在无可用身份时回退到 ad-hoc。测试与构建日志留在本地 build-tests.log、build/xcode-debug.log、build/release.log，不加入 Git。

## 仍待验证

| 项目 | 状态与原因 |
|---|---|
| 原生界面视觉 | 主壳在 Mac mini 正常启动；外接 Mi Monitor 调试时处于休眠，尚未完成电视画面人工验收 |
| 键盘、手柄与全局快捷键 | 键盘与注入映射已有自动化覆盖；手柄、mmTV Remote 的 TV/Home 全局切回和从第三方全屏应用返回仍待组合实测 |
| 真正 .app 启动后返 | Apple Development 签名的 Release app 已完成窗口激活、进入模块和返回键回主页实测；尚待 Mac mini 在 Remote 注入路径下复验 |
| 小米遥控器、语音、HDMI | 代码侧所有权已切换到 mmTV Remote；仍需完成 mmTV Profile 实体回归（不双触发）、Typeless F20、Mac mini/电视和 HDMI/DisplayPort 音量降级验收 |
| 塞尔达 | 未访问 Mac mini 的游戏路径和启动器，待在目标机器配置 |
| YouTube | VacuumTube v2.0.1 官方 ZIP 和 DMG 中的 App 均缺少有效资源签名，严格 codesign/Gatekeeper 校验失败，因此未安装或绕过系统安全 |
| Bilibili | MacBook 与 Mac mini 均完成匿名浏览和静音播放烟测；二维码登录、账号持久化、可听音频、电视画面与实体遥控器待验收 |
| Apple Music | 预览包尚未配置 MusicKit 开发者签名，账户连接默认禁用；真实授权和播放未验收 |
| 系统照片图库 | 手动权限接口已编译；未擅自请求权限或读取用户图库 |
| HA / Hermes / 多终端 Remote | **HA**：Lovelace WKWebView + 快捷控件（mock/REST）；可选 WallPanel。Hermes / 多终端网关未实现 |
| Jellyfin 媒体库 | 配置与壳入口已接线；**本机需用户安装** `brew install --cask jellyfin` 并挂库到 `…/Media/Movies`·`TV` |
| Music / Photos | 今晚演示暂缓完整能力；权限探针保留；工作量见模块 `effortEstimate` / ROADMAP V0.3 |

## 遥控器迁移状态

目标架构由 mmTV Remote 独占物理 RC003、输入监控/辅助功能权限、设备去重、手势、跨 App Profile、系统音量和全局语音提供商；mmTV 只处理标准按键、手柄、页面焦点以及菜单/Home 等应用内语义。

代码侧所有权切换已完成：mmTV Remote 内置 mmTV Profile 注入键盘事件；mmTV 已移除 HID 直连与输入监控授权 UI。设置页仍可用本机音量按钮微调。回家后请在 Mac mini 上同时安装/更新两应用，确认 Remote 对 `com.mmtv.mac` 使用默认 Profile，再做实体回归（方向、确认、返回、菜单、Home、音量，且每键只触发一次）。

V0.0 的正式签名、音乐和照片仍有待验收项；Mac mini 最小安装实验已通过。V0.1 的实体输入与切换仍待验收；V0.2 已达到 Mac mini 软件链路候选，尚缺电视、音频、账号与实体遥控器验收。当前交付不应当作已完成的家用稳定版本。

## 部署说明

当前 MacBook 个人开发包优先使用 Apple Development 签名，用于稳定保留本机权限；这仍不是 Developer ID 公证发行包。目标 Mac 初次安装需正常系统信任与授权流程；正式直接分发采用 Developer ID 与公证，或在目标 Mac 本机构建。无需关闭系统安全保护。

配置可通过界面导出，换机器后重新选应用、资源路径和系统权限。工程源码与配置模板均不含私人账户令牌或媒体资源。
