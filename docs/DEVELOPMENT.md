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

build.sh 生成 Release 应用与 ZIP，当前使用本机 ad-hoc 签名，供本地开发验收。该签名不等同于 Developer ID 公证，不承诺复制到另一台 Mac 后直接通过 Gatekeeper。正式分发需在 Xcode 中配置开发团队、Developer ID 与公证，或在目标 Mac 本机构建。无需关闭 Gatekeeper。

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
- Command + Control + F 切换全屏；设置可选择下次启动直接全屏。
- 入口卡片的右键菜单可以编辑、移除、在 Finder 显示或请求应用正常退出。
- 需要键盘鼠标的首次配置集中在系统设置，日常启动导航不需要打开 Finder。

## 游戏与启动器

优先选择实际 .app。对于可执行文件或脚本，每行一个启动参数；程序直接传递参数数组，不把输入拼成 shell 命令。脚本须具有可执行权限。

若启动器另开游戏后退出，应填写真正游戏的 Bundle ID。启动后最多等待 18 秒查找对应运行应用；未找到则报告跟踪失败，不虚构运行状态。未填写 Bundle ID 时只能跟踪启动器本身。Home 切回主页不会自动结束游戏；请求退出保留应用自身的保存提示。

资源目录用于启动前检查和脚本工作目录；选择外置盘资源后，盘未挂载会拒绝启动。它暂未实现架构计划中的卷标识自动重新定位，换机器需要重新选择目录。

## 系统权限与外部服务

PhotoGallery 提供手动权限探针，只有点击验证按钮才请求系统图库权限；不会自动浏览私人照片。完整影像馆尚未实现。

Music 的账户连接在当前 ad-hoc 预览构建中禁用。后续完成 MusicKit capability、签名和账号实验后，由宿主 Info.plist 的 mmTVMusicKitEnabled 显式启用；该开关本身不能替代开发者授权与 entitlement。完整播放器尚未实现。

Home、Assistant、Remote 目前为独立模块与说明入口，不连接 HA/Hermes，不监听网络端口。各模块可以在设置中独立启停。

## 生成界面预览

Debug 构建可把自有 SwiftUI 视图渲染成文件，不捕获桌面：

```sh
build/Build/Products/Debug/mmTV.app/Contents/MacOS/mmTV --render-preview docs/screenshots/home.png
```

这是布局预览，不是实际遥控或系统窗口交互验收。Release 构建不包含此导出入口。
