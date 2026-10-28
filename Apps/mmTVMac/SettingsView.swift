import SwiftUI
import AppKit
import Contracts
import DesignSystem
import Input

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("客厅设置").font(.title2)
                Spacer()
                Button("完成") { model.dismissPresentation() }
                    .keyboardShortcut(.cancelAction)
                    .remoteSelected(model.isSettingsFocused(.done))
                    .id(SettingsRemoteTarget.done)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        moduleSettings
                        configuredApps
                        inputSettings
                        configurationActions
                        recentEvents
                    }
                }
                .onChange(of: model.settingsFocus) { _, _ in
                    if let target = model.focusedSettingsTarget {
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(target, anchor: .center) }
                    }
                }
            }
        }.padding(28).frame(width: 680, height: 700)
    }

    private var moduleSettings: some View {
        GroupBox("功能模块") {
            VStack(spacing: 8) {
                ForEach(model.modules) { module in
                    let target = SettingsRemoteTarget.module(module.id)
                    Toggle(isOn: Binding(get: { !model.configuration.disabledModules.contains(module.id) }, set: { model.setEnabled(module.id, $0) })) {
                        Label(module.title, systemImage: module.symbol)
                    }
                    .toggleStyle(.switch)
                    .remoteSelected(model.isSettingsFocused(target))
                    .id(target)
                }
            }.padding(12)
        }
    }

    private var configuredApps: some View {
        GroupBox("已配置的应用") {
            VStack(alignment: .leading, spacing: 8) {
                if model.configuration.entries.isEmpty { Text("在游戏或视频模块中添加你的第一个应用。").foregroundStyle(.secondary) }
                ForEach(model.configuration.entries) { entry in
                    let target = SettingsRemoteTarget.entry(entry.id)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                            Text(entry.location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            let health = model.health(entry)
                            Text(health.title).font(.caption2)
                                .foregroundStyle(health.isLaunchable ? TVTheme.mint : TVTheme.amber)
                        }
                        Spacer()
                        Button("编辑") {
                            model.focusSettings(target)
                            model.edit(entry)
                        }
                    }
                    .remoteSelected(model.isSettingsFocused(target))
                    .id(target)
                }
            }.padding(12)
        }
    }

    private var inputSettings: some View {
        GroupBox("显示、遥控与音量") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("下次启动时进入电视全屏模式", isOn: Binding(get: { model.configuration.launchInFullScreen }, set: { value in
                    do { var config = model.configuration; config.launchInFullScreen = value; try model.save(config) }
                    catch { model.message = error.localizedDescription }
                }))
                .remoteSelected(model.isSettingsFocused(.tvMode))
                .id(SettingsRemoteTarget.tvMode)

                HStack(spacing: 12) {
                    Label("系统音量", systemImage: "speaker.wave.2.fill")
                    ProgressView(value: Double(model.systemVolume ?? 0), total: 1).frame(maxWidth: .infinity)
                    Text(model.volumePercent.map { "\($0)%" } ?? "不可调")
                        .font(.system(.body, design: .monospaced)).frame(width: 58, alignment: .trailing)
                    Button { model.focusSettings(.volumeDown); model.adjustVolume(by: -SystemVolumeController.step) } label: { Image(systemName: "minus") }
                        .remoteSelected(model.isSettingsFocused(.volumeDown)).id(SettingsRemoteTarget.volumeDown)
                    Button { model.focusSettings(.volumeUp); model.adjustVolume(by: SystemVolumeController.step) } label: { Image(systemName: "plus") }
                        .remoteSelected(model.isSettingsFocused(.volumeUp)).id(SettingsRemoteTarget.volumeUp)
                }

                Text("全局 Home：⌃⌥H · \(model.input.globalHomeAvailable ? "已注册" : "注册失败，请检查是否与其他应用冲突")")
                Text("物理遥控器由独立应用 mmTV Remote 接管；本应用只接收其注入的方向键、回车、Esc、Home 与 F2 菜单。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("请在 mmTV Remote 中完成输入监控与辅助功能授权。音量键由 Remote 调整 macOS 当前输出；不支持软件音量的 HDMI 设备需使用电视或音响。设置页的音量按钮仍可本机微调。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private var configurationActions: some View {
        GroupBox("配置与诊断") {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.store.url.path).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                HStack {
                    settingsButton("导出配置", .exportConfiguration, action: model.exportConfiguration)
                    settingsButton("导出诊断", .exportDiagnostics, action: model.exportDiagnostics)
                    settingsButton("导入配置", .importConfiguration, action: model.importConfiguration)
                    settingsButton("打开配置目录", .openConfigurationDirectory, action: model.openConfigurationDirectory)
                }
                Text("版本 \(model.version) · 本地预览构建\n换机器后请确认路径与授权。HA：原生快捷控件（mock/REST）为主，Lovelace 可选；视频：Jellyfin mediaLibrary。Hermes／多终端未接入。Music／Photos 今晚暂缓。").font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private var recentEvents: some View {
        GroupBox("最近运行记录") {
            VStack(alignment: .leading, spacing: 10) {
                if model.session.events.isEmpty {
                    Text("还没有启动记录。运行应用后会在这里保留最近 50 条结果。").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.session.events.prefix(10)) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: eventSymbol(event.kind)).foregroundStyle(event.kind == .failed ? TVTheme.amber : TVTheme.mint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.caption).fontWeight(.medium)
                            Text(event.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.date, format: .dateTime.hour().minute().second()).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }.padding(12)
        }
    }

    private func settingsButton(_ title: String, _ target: SettingsRemoteTarget, action: @escaping () -> Void) -> some View {
        Button(title) { model.focusSettings(target); action() }
            .remoteSelected(model.isSettingsFocused(target))
            .id(target)
    }
    private func eventSymbol(_ kind: SessionEventKind) -> String {
        switch kind {
        case .launched: "play.fill"
        case .activated: "arrow.up.forward.app.fill"
        case .exited: "stop.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}
