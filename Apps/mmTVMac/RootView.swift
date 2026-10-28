import SwiftUI
import AppKit
import Contracts
import DesignSystem
import MacHost
import Music
import PhotoGallery
import Home
import Assistant
import Remote
import TVApps

struct RootView: View {
    @Bindable var model: AppModel
    var body: some View {
        GeometryReader { geometry in
            let columns = geometry.size.width < 1100 ? 2 : 3
            VStack(spacing: 0) {
                header
                if model.isPreview {
                    pageContent(columns: columns).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView { pageContent(columns: columns) }
                        .onChange(of: model.focus.index) { _, value in
                            withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(value, anchor: .center) }
                        }
                    }
                }
                footer
            }
            .background(TVTheme.background)
            .foregroundStyle(TVTheme.ink)
            .onAppear { model.columns = columns }
            .onChange(of: columns) { _, value in model.columns = value }
        }
        .sheet(item: $model.presentation) { presentation in
            switch presentation {
            case .settings:
                SettingsView(model: model)
            case .setup:
                setupSheet
            case .editor(let entry):
                EntryEditor(entry: entry, onSave: model.upsert)
            case .embeddedWeb(let title, let url, let footnote):
                EmbeddedWebChrome(
                    title: title,
                    url: url,
                    footnote: footnote,
                    onClose: model.dismissPresentation,
                    onOpenExternally: model.openPresentedURLExternally
                )
                .frame(minWidth: 1100, minHeight: 700)
            }
        }
        .alert("提示", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .overlay(alignment: .top) {
            if model.showingVolumeHUD, let percent = model.volumePercent {
                VolumeHUD(percent: percent).padding(.top, 28).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.showingVolumeHUD)
    }
    private func pageContent(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 27) {
            if let error = model.loadError { errorBanner("配置读取失败：\(error)") }
            if model.session.route == nil { homeContent(columns: columns) }
            else { moduleContent(columns: columns) }
        }.padding(.horizontal, 48).padding(.top, 22).padding(.bottom, 36)
    }
    private var header: some View {
        HStack(spacing: 14) {
            if model.session.route != nil {
                Button { model.returnHome() } label: { Image(systemName: "arrow.left").font(.title3).padding(10) }
                    .buttonStyle(.plain).accessibilityLabel("返回主页")
            }
            HStack(spacing: 10) {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(TVTheme.mint)
                Text("mmTV").font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(3)
            }
            if let module = model.currentModule { Text("/").foregroundStyle(TVTheme.muted); Text(module.title).font(.system(size: 13)) }
            Spacer()
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date, format: .dateTime.hour().minute()).font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundStyle(TVTheme.muted)
            }
            Button { model.openSettings() } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 18)).padding(10) }
                .buttonStyle(.plain).accessibilityLabel("菜单与设置")
        }
        .padding(.horizontal, 42).padding(.top, 26).padding(.bottom, 16)
    }
    @ViewBuilder private func homeContent(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(TVTheme.mint).tracking(1)
            Text("家里的另一块屏幕").font(.system(size: 37, weight: .medium))
            Text("挑一件喜欢的事，让时间慢下来。")
                .font(.system(size: 15)).foregroundStyle(TVTheme.muted)
        }.padding(.vertical, 15)
        if let id = model.session.lastLaunched, let entry = model.runningEntries.first(where: { $0.id == id }) {
            HStack(spacing: 18) {
                Image(systemName: entry.module == .games ? "gamecontroller.fill" : "play.rectangle.fill").font(.system(size: 25)).foregroundStyle(TVTheme.amber)
                VStack(alignment: .leading, spacing: 5) {
                    Text("仍在运行").font(.system(size: 11)).foregroundStyle(TVTheme.muted)
                    Text(entry.title).font(.system(size: 20, weight: .medium))
                }
                Spacer()
                Button("切回应用") { model.launch(entry) }.buttonStyle(.bordered)
            }.padding(22).background(TVTheme.panel, in: RoundedRectangle(cornerRadius: 18))
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: columns), spacing: 18) {
            ForEach(Array(model.visibleModules.enumerated()), id: \.element.id) { index, module in
                TVCard(selected: model.focus.index == index, action: { model.focus.select(index, count: model.itemCount); model.open(module.id) }) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: module.symbol).font(.system(size: 29, weight: .light))
                                .foregroundStyle(TVTheme.accent(for: module.id)).frame(height: 37)
                            Spacer()
                            StatusPill(module.status.title, ready: module.status == .ready)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(module.title).font(.system(size: 21, weight: .medium))
                            Text(module.subtitle).font(.system(size: 12)).foregroundStyle(TVTheme.muted).lineLimit(1)
                        }
                    }.frame(height: 130, alignment: .top)
                }.id(index)
            }
        }
        if model.visibleModules.isEmpty {
            Text("所有模块已停用。可在右上角设置中重新启用。 ")
                .foregroundStyle(TVTheme.muted).padding(.vertical, 40)
        }
    }
    @ViewBuilder private func moduleContent(columns: Int) -> some View {
        if let module = model.currentModule {
            VStack(alignment: .leading, spacing: 10) {
                Text(module.title).font(.system(size: 34, weight: .medium))
                Text(module.subtitle).font(.system(size: 14)).foregroundStyle(TVTheme.muted)
            }.padding(.vertical, 15)
            if module.id == .games || module.id == .video {
                appGrid(module: module, columns: columns)
            } else if module.id == .home {
                homeControlsGrid(columns: columns)
            } else { upcomingModule(module) }
        }
    }
    @ViewBuilder private func homeControlsGrid(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(model.homeUsingMock ? "模拟家居 · 原生快捷控件" : "Home Assistant · 快捷控件")
                    .font(.system(size: 21, weight: .medium))
                if model.homeLoading { ProgressView().controlSize(.small) }
                Spacer()
                Button("刷新") { model.refreshHome() }.font(.system(size: 13))
            }
            if let note = model.homeMessage {
                Text(note).font(.system(size: 13)).foregroundStyle(TVTheme.muted)
            }
            Text("方向键移动焦点，确认切换灯/场景。配置保留 HA URL、令牌与 entity ID。Lovelace 仅在 uiMode=lovelace 时显示为末位可选卡片。")
                .font(.system(size: 12)).foregroundStyle(TVTheme.muted)
        }.padding(.vertical, 8)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: columns), spacing: 18) {
            if model.homeStates.isEmpty {
                let emptyIndex = model.homeControlsFocusOffset
                TVCard(selected: model.focus.index == emptyIndex, action: model.refreshHome) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("尚未加载快捷控件").font(.system(size: 22, weight: .medium))
                        Text("确认后刷新；或跑 Scripts/seed-demo-config.sh。")
                            .font(.system(size: 13)).foregroundStyle(TVTheme.muted)
                    }.frame(height: 120, alignment: .top)
                }.id(emptyIndex)
            } else {
                ForEach(Array(model.homeStates.enumerated()), id: \.element.id) { index, state in
                    let focusIndex = index + model.homeControlsFocusOffset
                    let focused = model.focus.index == focusIndex
                    TVCard(selected: focused, action: {
                        model.focus.select(focusIndex, count: model.itemCount)
                        model.activateFocusedHomeControl()
                    }) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: homeSymbol(state))
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(focused ? TVTheme.mint : TVTheme.mint.opacity(0.85))
                                    .scaleEffect(focused ? 1.08 : 1)
                                Spacer()
                                StatusPill(homePill(state), ready: state.isOn == true || state.kind == .scene)
                            }
                            Text(state.title)
                                .font(.system(size: focused ? 24 : 22, weight: .semibold))
                                .lineLimit(1)
                            Text(state.detail.isEmpty ? state.id : state.detail)
                                .font(.system(size: 13)).foregroundStyle(TVTheme.muted).lineLimit(1)
                            if focused {
                                Text(state.kind == .scene ? "确认 · 激活场景" : "确认 · 开/关")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TVTheme.mint)
                            }
                        }.frame(height: 148, alignment: .top)
                    }.id(focusIndex)
                }
            }
            if let dashIndex = model.homeDashboardFocusIndex {
                TVCard(selected: model.focus.index == dashIndex, action: {
                    model.focus.select(dashIndex, count: model.itemCount)
                    model.openHomeDashboard()
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(TVTheme.muted)
                            Spacer()
                            StatusPill("可选", ready: false)
                        }
                        Text("打开 HA 仪表盘").font(.system(size: 20, weight: .medium)).lineLimit(1)
                        Text(model.homeConfiguration.dashboardURL?.absoluteString ?? model.homeConfiguration.baseURL)
                            .font(.system(size: 12)).foregroundStyle(TVTheme.muted).lineLimit(1)
                    }.frame(height: 130, alignment: .top)
                }.id(dashIndex)
            }
        }
    }
    private func homeSymbol(_ state: HomeControlState) -> String {
        switch state.kind {
        case .light: return state.isOn == true ? "lightbulb.fill" : "lightbulb"
        case .switch: return state.isOn == true ? "power.circle.fill" : "power.circle"
        case .scene: return "sparkles.tv"
        }
    }
    private func homePill(_ state: HomeControlState) -> String {
        switch state.kind {
        case .scene: return "场景"
        case .light, .switch:
            if let on = state.isOn { return on ? "开" : "关" }
            return "—"
        }
    }
    @ViewBuilder private func appGrid(module: ModuleDescriptor, columns: Int) -> some View {
        let libraryOffset = (module.id == .video && model.mediaLibrary?.libraryURL != nil) ? 1 : 0
        if module.id == .video, let library = model.mediaLibrary {
            VStack(alignment: .leading, spacing: 8) {
                Text("媒体库（优先）").font(.system(size: 21, weight: .medium))
                Text("外置盘库根：\(library.libraryRoots.joined(separator: " · "))。需本机安装并启动 Jellyfin 后打开。")
                    .font(.system(size: 13)).foregroundStyle(TVTheme.muted)
            }.padding(.vertical, 8)
        } else if model.currentEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(module.id == .games ? "把你的第一款游戏带到客厅" : "接入你喜欢的电视应用")
                    .font(.system(size: 21, weight: .medium))
                Text(module.id == .games ? "选择已安装的游戏或启动器。资源保留在原来的位置。" : "优先 Jellyfin 媒体库；IINA 仅作单文件兜底。")
                    .font(.system(size: 14)).foregroundStyle(TVTheme.muted)
            }.padding(.vertical, 15)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: columns), spacing: 18) {
            if module.id == .video, let library = model.mediaLibrary, library.libraryURL != nil {
                TVCard(selected: model.focus.index == 0, action: {
                    model.focus.select(0, count: model.itemCount)
                    model.openMediaLibrary()
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "film.stack")
                                .font(.system(size: 33))
                                .foregroundStyle(TVTheme.amber)
                                .frame(width: 48, height: 48)
                            Spacer()
                            StatusPill(library.provider.rawValue, ready: true)
                        }
                        Text(library.displayTitle).font(.system(size: 22, weight: .medium)).lineLimit(1)
                        Text(library.baseURL).font(.system(size: 12)).foregroundStyle(TVTheme.muted).lineLimit(1)
                    }.frame(height: 140, alignment: .top)
                }.id(0)
            }
            ForEach(Array(model.currentEntries.enumerated()), id: \.element.id) { index, entry in
                let focusIndex = index + libraryOffset
                let health = model.health(entry)
                TVCard(selected: model.focus.index == focusIndex, action: {
                    model.focus.select(focusIndex, count: model.itemCount)
                    model.launch(entry)
                }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            AppIcon(
                                path: model.resolvedLocation(entry) ?? entry.location,
                                symbol: module.symbol
                            )
                            Spacer()
                            if model.session.launching == entry.id { ProgressView().controlSize(.small) }
                            else if model.session.running[entry.id] != nil { StatusPill("运行中", ready: true) }
                            else { StatusPill(health.title, ready: health.isLaunchable) }
                        }
                        Text(entry.title).font(.system(size: 22, weight: .medium)).lineLimit(1)
                        Text(entry.tvInteractionVerified ? "电视交互已由你确认" : "电视交互待验证")
                            .font(.system(size: 12)).foregroundStyle(TVTheme.muted)
                    }.frame(height: 140, alignment: .top)
                }
                .id(focusIndex)
                .contextMenu {
                    Button("编辑入口") { model.edit(entry) }
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.selectFile(model.resolvedLocation(entry) ?? entry.location, inFileViewerRootedAtPath: "")
                    }
                    if model.session.running[entry.id] != nil {
                        Button("请求应用退出") {
                            if !model.session.requestTermination(entry.id) { model.message = "应用未响应退出请求。请检查应用是否有未保存内容。" }
                        }
                    }
                    Button("移除入口", role: .destructive) { model.remove(entry) }
                }
            }
            let addIndex = model.currentEntries.count + libraryOffset
            TVCard(selected: model.focus.index == addIndex, action: model.addEntry) {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "plus").font(.system(size: 30, weight: .light)).foregroundStyle(TVTheme.mint).frame(height: 44)
                    Text(module.id == .games ? "添加游戏" : "添加视频应用").font(.system(size: 22, weight: .medium))
                    Text("选择本机应用或启动器").font(.system(size: 12)).foregroundStyle(TVTheme.muted)
                }.frame(height: 140, alignment: .top)
            }.id(addIndex)
        }
        if module.id == .video {
            VStack(alignment: .leading, spacing: 14) {
                Text("接入参考").font(.system(size: 15, weight: .medium))
                ForEach(TVAppsModule.candidates) { candidate in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.title).font(.system(size: 14))
                            Text(candidate.detail).font(.system(size: 12)).foregroundStyle(TVTheme.muted)
                        }
                        Spacer()
                        if model.candidateIsConnected(candidate) {
                            Text("已接入").font(.system(size: 12, weight: .medium)).foregroundStyle(TVTheme.mint)
                        } else if model.candidateLocation(candidate) != nil {
                            Button("接入") { model.connect(candidate) }.font(.system(size: 12))
                        } else {
                            Link(candidate.macBundleID == nil ? "查看进展 ↗" : "获取客户端 ↗", destination: candidate.download)
                                .font(.system(size: 12))
                        }
                        Link("源码 ↗", destination: candidate.source).font(.system(size: 12))
                    }
                }
            }.padding(24).background(TVTheme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
        }
        Text("按 ⌃⌥H 可从其他应用回到主页。编辑入口可通过右键菜单或系统设置完成。")
            .font(.system(size: 12)).foregroundStyle(TVTheme.muted)
    }
    private func upcomingModule(_ module: ModuleDescriptor) -> some View {
        TVCard(selected: true, action: model.openSetup) {
            HStack(alignment: .top, spacing: 24) {
                Image(systemName: module.symbol).font(.system(size: 40, weight: .ultraLight)).foregroundStyle(TVTheme.accent(for: module.id)).frame(width: 60)
                VStack(alignment: .leading, spacing: 12) {
                    Text("为下一段体验做好准备").font(.system(size: 24, weight: .medium))
                    Text(setupDescription(module.id)).font(.system(size: 15)).foregroundStyle(TVTheme.muted).lineSpacing(7)
                    Text("查看模块设置 →").font(.system(size: 13, weight: .medium)).foregroundStyle(TVTheme.mint).padding(.top, 8)
                }
                Spacer()
            }.padding(.vertical, 15)
        }.id(0)
    }
    private var setupSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(model.currentModule?.title ?? "模块设置").font(.title2)
            Text(setupDescription(model.session.route ?? .remote)).foregroundStyle(.secondary).lineSpacing(6)
            if model.session.route == .music || model.session.route == .photos {
                Text(model.session.route == .music ? MusicModule.authorizationDescription : PhotosModule.authorizationDescription).font(.callout)
                let canProbe = model.session.route == .photos || (model.session.route == .music && MusicModule.accountConnectionEnabled)
                Button(model.loadingProbe ? "正在请求授权…" : "验证系统授权") { model.performProbe() }
                    .disabled(model.loadingProbe || !canProbe)
                    .remoteSelected(canProbe && model.setupFocus == 0)
                if let result = model.probeResult { Text(result).font(.callout).foregroundStyle(TVTheme.mint) }
                Text(model.session.route == .music ? MusicModule.effortEstimate : PhotosModule.effortEstimate)
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                let canProbe = model.session.route == .photos || (model.session.route == .music && MusicModule.accountConnectionEnabled)
                Button("完成") { model.dismissPresentation() }
                    .keyboardShortcut(.cancelAction)
                    .remoteSelected(!canProbe || model.setupFocus == 1)
            }
        }.padding(32).frame(width: 560)
    }
    private var footer: some View {
        HStack(spacing: 22) {
            Label("方向键移动", systemImage: "arrow.up.arrow.down")
            Text("↵  进入")
            Text("esc  返回")
            Text("☰  菜单")
            Text("⌃⌥H  主页")
            Spacer()
            Circle().fill(TVTheme.mint).frame(width: 5, height: 5)
            Text("本机模式 · \(model.version)")
        }.font(.system(size: 11)).foregroundStyle(TVTheme.muted)
            .padding(.horizontal, 48).padding(.vertical, 18)
            .background(TVTheme.background)
    }
    private func errorBanner(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(TVTheme.amber).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(TVTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    private func setupDescription(_ id: ModuleID) -> String {
        switch id {
        case .music: "今晚演示暂缓完整播放器。" + MusicModule.effortEstimate
        case .photos: "今晚演示暂缓完整影像馆。" + PhotosModule.effortEstimate
        case .home: HomeModule.setupDescription
        case .assistant: AssistantModule.setupDescription
        case .remote: RemoteModule.setupDescription
        default: "在模块中添加你的应用。"
        }
    }
}
private struct VolumeHUD: View {
    let percent: Int
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: percent == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
            ProgressView(value: Double(percent), total: 100).frame(width: 160)
            Text("\(percent)%").font(.system(.body, design: .monospaced)).frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 20).padding(.vertical, 13)
        .background(.ultraThickMaterial, in: Capsule())
        .shadow(radius: 18)
    }
}
private struct AppIcon: View {
    let path: String
    let symbol: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 33))
                    .foregroundStyle(TVTheme.muted)
            }
        }
        .frame(width: 48, height: 48)
        .task(id: path) {
            image = nil
            guard let data = await ApplicationIconLoader.shared.iconData(for: path),
                  !Task.isCancelled else { return }
            image = NSImage(data: data)
        }
    }
}
