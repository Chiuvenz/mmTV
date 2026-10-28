# 视频应用接入记录

状态：客厅演示优先 **开源 Jellyfin 媒体库**（壳内 Web UI / 系统浏览器）；IINA / QuickTime 降为单文件兜底；BiliTVMac 仍在 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)。Infuse 非免费可积；本机 Emby/Plex 未装，不作为默认路径。

## Jellyfin 媒体库（首选）

| 项 | 值 |
|---|---|
| 服务端 | [Jellyfin](https://jellyfin.org) macOS：`brew install --cask jellyfin`（本机已装 12.4；若 Gatekeeper 卡住可从 `~/Applications/Jellyfin.app` 启动） |
| Web UI | `http://127.0.0.1:8096` |
| mmTV 配置 | `mediaLibrary`：`provider=jellyfin`、`baseURL`、`embedInShell`、`libraryRoots` |
| 真实库根（本机盘） | `/Volumes/mmTV Media/Media/Movies` · `/Volumes/mmTV Media/Media/TV` |

卷名 **`mmTV Media`**（USB SSD ~2TB，`RTL9210B-CG`）。既有 `Games/`、`Backups/` 未移动。第二块外置盘未挂载时勿臆造路径。

壳行为：视频模块首卡「Jellyfin 媒体库」→ WKWebView（或 `embedInShell=false` 时 `open` URL）。另种子入口「Jellyfin Web」用 `/usr/bin/open`。可选安装 Jellyfin Media Player 桌面客户端。

## 本机播放（兜底）

| 候选 | Bundle ID | 说明 |
|---|---|---|
| IINA | `com.colliderli.iina` | 单文件打开；非媒体库体验 |
| QuickTime Player | `com.apple.QuickTimePlayerX` | 系统兜底 |

## YouTube

候选：[VacuumTube](https://github.com/shy1132/VacuumTube)。上游 v2.0.1 缺有效签名，不自动安装。

## Bilibili

macOS 适配器 **BiliTVMac**（`com.mmtv.bilitv`）在 [mmTVAdapters](https://github.com/Chiuvenz/mmTVAdapters)。mmTV 检测后带 `--tv-fullscreen` 启动。

## 能力边界

添加/编辑入口、健康检查、外部启动、诊断导出。第三方按键映射归 [mmTV Remote](https://github.com/Chiuvenz/mmTVRemote)。Jellyfin Web 内焦点与全屏播放依赖 Web UI / 浏览器 Profile，需客厅实测。
