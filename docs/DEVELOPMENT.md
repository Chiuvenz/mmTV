# 开发与运行

开发工具：Xcode 27.1 / Swift 6.4 已构建验证；应用部署目标 macOS 15.0，arm64。Mac mini 最低系统仍需实机核对。

## 打开工程

直接用 Xcode 打开根目录 mmTV.xcodeproj。Swift package 位于 Packages/mmTV；各功能 target 独立编译。照片 target 使用 PhotoGallery，避免遮蔽 Apple 的 Photos 框架。

project.yml 是工程声明源，安装 XcodeGen 后执行 `xcodegen generate` 可重新生成工程。新增应用源文件后需要重新生成；修改已有文件不需要。

## 命令

在项目根目录运行：

```sh
./Scripts/test.sh
./Scripts/build.sh
open dist/mmTV.app
```

build.sh 生成 Release 应用与 ZIP。如果钥匙串中存在 Apple Development 身份，脚本会自动用它稳定签名，便于 macOS 持续识别输入监控等本机权限；也可通过 `MMTV_CODE_SIGN_IDENTITY` 显式指定。没有可用身份时回退到 ad-hoc 签名。开发签名不等同于 Developer ID 公证，不承诺复制到另一台 Mac 后直接通过 Gatekeeper。正式分发需配置 Developer ID 与公证，或在目标 Mac 本机构建。无需关闭 Gatekeeper。

`./Scripts/build-all.sh` 目前与 `build.sh` 相同，只产出 mmTV 主壳。第三方适配器（BiliTVMac）已迁至 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)：

```sh
cd ~/vibeCoding/mmTVAdapters
./Scripts/build-bilitv.sh
# 无图形会话时可：MMTV_SKIP_BILITV_SMOKE=1 ./Scripts/build-bilitv.sh
```

将 `BiliTVMac.app` 装到 Applications 后，mmTV 视频模块按 Bundle ID `com.mmtv.bilitv` 自动检测并以 `--tv-fullscreen` 启动。

## 单模块和隔离配置

```sh
open -n dist/mmTV.app --args --module games
open -n dist/mmTV.app --args --module video --config /tmp/mmtv-video.json
```

模块 id 为 games、video、music、photos、home、assistant、remote。--config 指向单独配置文件，避免测试覆盖日常配置。不存在的配置文件从空目录开始；损坏或高版本配置会报错并阻止写入，允许通过设置重新导入有效配置恢复。

默认配置在当前用户的 Library/Application Support/mmTV/configuration.json。每次写入使用原子替换并保存一个 .previous 备份。--module 只显示指定模块；退出 App 后全局快捷键随进程释放。

## 操作

- 方向键移动，Enter 进入或启动，Escape 返回，Home 返回主页。
- Control + Option + H 是注册到系统的全局主页快捷键，可从外部应用切回。
- 手柄十字键导航、A 确认、B 返回；仅在客厅应用为前台时消费输入。
- 生产方案安装独立的 [mmTV Remote](https://github.com/Chiuvenz/mmTVRemote)。它负责小米蓝牙语音遥控器 RC003（VID `0x2717` / PID `0x32B8`）的 HID、权限、去重、手势、前台 App Profile、系统音量、TV 键启动 mmTV，以及 Typeless/macOS 系统听写。输入监控与辅助功能授权只授予 mmTV Remote。
- mmTV Profile 注入：方向键、回车、Esc、Home、F2（菜单开关设置）；音量由 Remote 调整。若本机有覆盖 `com.mmtv.mac` 的用户 Profile，验收前请在 Remote 控制台恢复默认。
- mmTV 内的主页、模块页、设置、弹窗、编辑页和系统文件面板都保留遥控输入；返回键关闭最上层，Home 直接回主页。文本录入仍属于键盘/维护操作。
- Command + Control + F 切换全屏；设置可选择下次启动直接全屏。
- 入口卡片的右键菜单可以编辑、移除、在 Finder 显示或请求应用正常退出。
- 需要键盘鼠标的首次配置集中在系统设置，日常启动导航不需要打开 Finder。

## 游戏与启动器

优先选择实际 .app。对于可执行文件或脚本，每行一个启动参数；程序直接传递参数数组，不把输入拼成 shell 命令。脚本须具有可执行权限。

若启动器另开游戏后退出，应填写真正游戏的 Bundle ID。启动后最多等待 18 秒查找对应运行应用；未找到则报告跟踪失败，不虚构运行状态。未填写 Bundle ID 时只能跟踪启动器本身。Home 切回主页不会自动结束游戏；请求退出保留应用自身的保存提示。

选择 `.app` 时会保存它的应用 Bundle ID。配置从 MacBook 导入 Mac mini 后，如果绝对路径已经变化，mmTV 会通过 Launch Services 查找同一 Bundle ID，并在启动前把找到的新路径写回配置。可执行文件不会猜测或搜索路径，避免启动同名错误文件。

资源目录用于启动前检查和脚本工作目录；选择外置盘资源后，盘未挂载会拒绝启动。它暂未实现架构计划中的卷标识自动重新定位，换机器需要重新选择目录。

设置页显示入口健康状态和本次运行期间最近 50 条启动、切回、退出或失败事件。诊断报告可从设置页导出；它包含本机路径和 Bundle ID，便于目标机排障，但不包含启动参数或账号口令。

## 系统权限与外部服务

PhotoGallery 提供手动权限探针，只有点击验证按钮才请求系统图库权限；不会自动浏览私人照片。完整影像馆尚未实现。

Music 的账户连接在当前 ad-hoc 预览构建中禁用。后续完成 MusicKit capability、签名和账号实验后，由宿主 Info.plist 的 mmTVMusicKitEnabled 显式启用；该开关本身不能替代开发者授权与 entitlement。完整播放器尚未实现。

Home 优先原生 SwiftUI **快捷控件**（灯/场景，遥控友好）。`configuration.json` 的 `homeAssistant` 含 `baseURL`、`uiMode`（默认 `controls`；`lovelace` 才显示可选仪表盘卡片）、`dashboardPath`、long-lived `token`（仅 REST）、`useMock`、`controls`（entity ID）。Lovelace WKWebView 已降级为可选。用户需自建并可访问的 HA URL。

视频优先 **Jellyfin**：`mediaLibrary`（`provider`、`baseURL`、`embedInShell`、`libraryRoots`）。本机库根为 `/Volumes/mmTV Media/Media/Movies` 与 `…/TV`（需先 `brew install --cask jellyfin`）。IINA/QuickTime 为兜底。

示例见 `Config/configuration.example.json`；`./Scripts/seed-demo-config.sh` 合并塞尔达 / Jellyfin / 原生 HA 快捷控件（保留已有 Bili 等入口）。Assistant、Remote（多终端网关）仍为说明入口。各模块可在设置中独立启停。

Music / Photos：完整播放器与影像馆仍属 V0.3，工作面大（约 5—8 集中工作日量级），今晚演示刻意暂缓，仅保留授权探针。

## 生成界面预览

Debug 构建可把自有 SwiftUI 视图渲染成文件，不捕获桌面：

```sh
build/Build/Products/Debug/mmTV.app/Contents/MacOS/mmTV --render-preview docs/screenshots/home.png
```

这是布局预览，不是实际遥控或系统窗口交互验收。Release 构建不包含此导出入口。
