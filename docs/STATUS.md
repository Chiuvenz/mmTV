# 实现与验收记录

日期：2026-10-26。当前为开发预览构建，版本号 0.2.0-dev；版本号不代表 ROADMAP.md 中的产品验收门槛已经全部通过。

## 当前自主开发边界

先推进到 V0.2 的 MacBook 开发候选：可运行主应用、独立模块、游戏/视频接入框架和可安装构建。账号登录、开发者授权、真实遥控器与 Mac mini 电视链路需要目标设备配置后验收。

## 已实现并有自动化证据

- Swift 6 模块化 package 与 Xcode 应用工程，部署目标 macOS 15，arm64。
- Contracts/Core/Input/DesignSystem/MacHost/Games/TVApps/Music/PhotoGallery/Home/Assistant/Remote 编译边界。
- 主页、方向焦点、独立模块入口、应用入口编辑、设置、导入导出与全屏选项。
- 原子配置、上一份备份、拒绝高版本与无效入口；加载失败后阻止无意覆盖。
- 应用启动与激活；直接传递可执行文件参数；启动器与真正游戏 Bundle ID 分开跟踪。
- `.app` Bundle ID 元数据、跨 Mac 自动重定位与路径修复；旧版配置无需迁移即可继续读取。
- 入口健康检查、最近 50 条运行事件和可导出的本机诊断报告。
- VacuumTube 安装检测与一键接入目录；BiliTVMac 以独立 Bundle ID 自动检测并带电视全屏参数接入。
- BiliTV v2.5.1 官方发布包的固定版本下载、SHA-256 校验、解包与独立 Electron 适配器；上游二进制保持在忽略目录，不混入仓库。
- BiliTVMac 已实现隔离 PalmServiceBridge、本机服务宿主、独立状态目录和仅回环媒体代理；禁用上游 LAN 投屏监听并限制网页权限、导航和服务命名空间。
- BiliTVMac 自动烟测已在 MacBook 跑通真实匿名接口、20 张内容卡、方向焦点、公开视频开始播放（媒体时间推进）以及返回列表；烟测静音且不使用账号。
- M4 Mac mini（macOS 27.0.1）已安装 mmTV 与 BiliTVMac；远端成品烟测同样通过 20 张内容卡、方向焦点、真实起播和返回，mmTV 已加载 BiliTVMac 全屏入口且无启动错误。
- 全局 Control + Option + H 注册；手柄只在应用前台路由；外部游戏退出时恢复主页的状态管理。
- MacBook 已连接并识别小米 RC003（VID `0x2717`、PID `0x32B8`、固件 `2671`）；实测确认方向、确认、返回 `0xF1`、Home、音量与语音键 usage。Input 已增加目标设备 IOHID 适配、键盘事件去重、长按导航与全局 Home，设置和诊断中分别显示设备连接与输入监控状态。稳定 Apple Development 签名、输入监控授权、设备连接和实体返回键从模块页回到主页的完整链路已在 MacBook 通过。
- 输入路由已扩展到设置、模块弹窗、提示弹窗、编辑页和系统文件面板；设置和模块弹窗已用键盘等价遥控事件完成焦点高亮、移动、确认与返回实测。
- 已增加 CoreAudio 系统音量读取/加减、设置页音量显示和主界面音量 HUD；当前输出设备不支持软件音量时会显式提示使用电视/音响。
- 三横线菜单键已重新采样确认为 Keyboard usage `0x65`；实体遥控器已完成“按一次打开右上角菜单、再按一次关闭”验收。

自动化验证命令：`./Scripts/test.sh`。17 项 Swift 测试通过，包含焦点边界、配置往返与备份、旧配置兼容、拒绝未来配置、入口健康分级、参数校验、重复启动去重、连续确认防重入、禁用模块、失败恢复、当前应用退出恢复、真实子进程与参数不被 shell 展开、缺失资源拒绝、重复 ID 不覆盖已有配置、BiliTVMac 候选接入约束，以及 RC003 导航/辅助键映射。适配器另有 3 项 Node 测试，依赖审计为 0 个已知漏洞。

Xcode Debug 与 Release 构建均已成功。Release 应用通过 codesign --verify --deep --strict，ZIP 完整性检查通过；当前 MacBook 使用本机 Apple Development 身份和 Hardened Runtime，构建脚本在无可用身份时回退到 ad-hoc。测试与构建日志留在本地 build-tests.log、build/xcode-debug.log、build/release.log，不加入 Git。

## 仍待验证

| 项目 | 状态与原因 |
|---|---|
| 原生界面视觉 | 主壳在 Mac mini 正常启动；外接 Mi Monitor 调试时处于休眠，尚未完成电视画面人工验收 |
| 键盘、手柄与全局快捷键 | 键盘与实体遥控器在真实界面已验证；手柄与从其他前台应用触发全局 Home 仍待实测 |
| 真正 .app 启动后返 | Apple Development 签名的 Release app 已完成窗口激活、进入模块和实体返回键回主页实测；尚待 Mac mini 复验 |
| 小米遥控器、语音、HDMI | RC003 的 MacBook 本机界面闭环已通过：原始 HID 连接、输入监控授权和返回键从模块页回主页均已实测；仍需 Mac mini/电视复验、ATVV 语音和 HDMI/DisplayPort 音频验收 |
| 塞尔达 | 未访问 Mac mini 的游戏路径和启动器，待在目标机器配置 |
| YouTube | VacuumTube v2.0.1 官方 ZIP 和 DMG 中的 App 均缺少有效资源签名，严格 codesign/Gatekeeper 校验失败，因此未安装或绕过系统安全 |
| Bilibili | MacBook 与 Mac mini 均完成匿名浏览和静音播放烟测；二维码登录、账号持久化、可听音频、电视画面与实体遥控器待验收 |
| Apple Music | 预览包尚未配置 MusicKit 开发者签名，账户连接默认禁用；真实授权和播放未验收 |
| 系统照片图库 | 手动权限接口已编译；未擅自请求权限或读取用户图库 |
| HA / Hermes / Remote | 模块与说明入口已建立；服务连接与网络监听尚未实现 |

V0.0 的正式签名、音乐和照片仍有待验收项；Mac mini 最小安装实验已通过。V0.1 的实体输入与切换仍待验收；V0.2 已达到 Mac mini 软件链路候选，尚缺电视、音频、账号与实体遥控器验收。当前交付不应当作已完成的家用稳定版本。

## 部署说明

当前 MacBook 个人开发包优先使用 Apple Development 签名，用于稳定保留本机权限；这仍不是 Developer ID 公证发行包。目标 Mac 初次安装需正常系统信任与授权流程；正式直接分发采用 Developer ID 与公证，或在目标 Mac 本机构建。无需关闭系统安全保护。

配置可通过界面导出，换机器后重新选应用、资源路径和系统权限。工程源码与配置模板均不含私人账户令牌或媒体资源。
