import SwiftUI
import AppKit
import Contracts
import DesignSystem
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
        .sheet(isPresented: $model.isEditing) {
            if let entry = model.editor { EntryEditor(entry: entry, onSave: model.upsert) }
        }
        .sheet(isPresented: $model.showingSettings) { SettingsView(model: model) }
        .sheet(isPresented: $model.showingSetup) { setupSheet }
        .alert("提示", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
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
            Button { model.showingSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 18)).padding(10) }
                .buttonStyle(.plain).accessibilityLabel("系统设置")
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
                                .foregroundStyle(color(for: module.id)).frame(height: 37)
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
            } else { upcomingModule(module) }
        }
    }
    @ViewBuilder private func appGrid(module: ModuleDescriptor, columns: Int) -> some View {
        if model.currentEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(module.id == .games ? "把你的第一款游戏带到客厅" : "接入你喜欢的电视应用")
                    .font(.system(size: 21, weight: .medium))
                Text(module.id == .games ? "选择已安装的游戏或启动器。资源保留在原来的位置。" : "选择已安装的 .app。每款应用的电视交互与播放能力需要分别验证。")
                    .font(.system(size: 14)).foregroundStyle(TVTheme.muted)
            }.padding(.vertical, 15)
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: columns), spacing: 18) {
            ForEach(Array(model.currentEntries.enumerated()), id: \.element.id) { index, entry in
                let health = model.health(entry)
                TVCard(selected: model.focus.index == index, action: { model.focus.select(index, count: model.itemCount); model.launch(entry) }) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            AppIcon(path: entry.location, symbol: module.symbol)
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
                .id(index)
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
            TVCard(selected: model.focus.index == model.currentEntries.count, action: model.addEntry) {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "plus").font(.system(size: 30, weight: .light)).foregroundStyle(TVTheme.mint).frame(height: 44)
                    Text(module.id == .games ? "添加游戏" : "添加视频应用").font(.system(size: 22, weight: .medium))
                    Text("选择本机应用或启动器").font(.system(size: 12)).foregroundStyle(TVTheme.muted)
                }.frame(height: 140, alignment: .top)
            }.id(model.currentEntries.count)
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
        TVCard(selected: true, action: { model.showingSetup = true }) {
            HStack(alignment: .top, spacing: 24) {
                Image(systemName: module.symbol).font(.system(size: 40, weight: .ultraLight)).foregroundStyle(color(for: module.id)).frame(width: 60)
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
                Button(model.loadingProbe ? "正在请求授权…" : "验证系统授权") { model.performProbe() }.disabled(model.loadingProbe || (model.session.route == .music && !MusicModule.accountConnectionEnabled))
                if let result = model.probeResult { Text(result).font(.callout).foregroundStyle(TVTheme.mint) }
                Text(model.session.route == .music && !MusicModule.accountConnectionEnabled ? "此预览构建尚未启用 Apple Music 账户连接。需完成开发者签名配置后验证；完整播放器在 V0.3 接入。" : "授权由系统管理；当前版本只做权限验证，完整音乐播放器与影像馆将在 V0.3 接入。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack { Spacer(); Button("完成") { model.showingSetup = false }.keyboardShortcut(.cancelAction) }
        }.padding(32).frame(width: 560)
    }
    private var footer: some View {
        HStack(spacing: 22) {
            Label("方向键移动", systemImage: "arrow.up.arrow.down")
            Text("↵  进入")
            Text("esc  返回")
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
    private func color(for id: ModuleID) -> Color {
        switch id {
        case .games: TVTheme.amber
        case .video: Color(red: 0.55, green: 0.73, blue: 0.92)
        case .music: Color(red: 0.92, green: 0.57, blue: 0.60)
        case .photos: Color(red: 0.76, green: 0.67, blue: 0.92)
        default: TVTheme.mint
        }
    }
    private func setupDescription(_ id: ModuleID) -> String {
        switch id {
        case .music: "以 Apple Music 为内容与播放基础，提供适合电视的歌单、搜索和播放队列。此模块独立开发，账户授权在每台 Mac 上分别配置。"
        case .photos: "从系统照片图库或你选择的本地目录建立私人影像馆。Google Drive 的备份需要先同步到本机，或导入系统照片图库。"
        case .home: HomeModule.setupDescription
        case .assistant: AssistantModule.setupDescription
        case .remote: RemoteModule.setupDescription
        default: "在模块中添加你的应用。"
        }
    }
}
private struct AppIcon: View {
    let path: String
    let symbol: String
    var body: some View {
        if FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 48, height: 48)
        } else { Image(systemName: symbol).font(.system(size: 33)).frame(width: 48, height: 48).foregroundStyle(TVTheme.muted) }
    }
}
