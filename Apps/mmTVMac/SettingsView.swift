import SwiftUI
import AppKit
import Contracts
import DesignSystem

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("客厅设置").font(.title2)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GroupBox("功能模块") {
                        VStack(spacing: 12) {
                            ForEach(model.modules) { module in
                                Toggle(isOn: Binding(get: { !model.configuration.disabledModules.contains(module.id) }, set: { model.setEnabled(module.id, $0) })) {
                                    Label(module.title, systemImage: module.symbol)
                                }.toggleStyle(.switch)
                            }
                        }.padding(12)
                    }
                    GroupBox("已配置的应用") {
                        VStack(alignment: .leading, spacing: 12) {
                            if model.configuration.entries.isEmpty { Text("在游戏或视频模块中添加你的第一个应用。").foregroundStyle(.secondary) }
                            ForEach(model.configuration.entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title)
                                        Text(entry.location).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        Text(model.health(entry).title).font(.caption2)
                                            .foregroundStyle(model.health(entry).isLaunchable ? TVTheme.mint : TVTheme.amber)
                                    }
                                    Spacer()
                                    Button("编辑") { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { model.edit(entry) } }
                                }
                            }
                        }.padding(12)
                    }
                    GroupBox("显示与输入") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("下次启动时进入电视全屏模式", isOn: Binding(get: { model.configuration.tvMode }, set: { value in
                                do { var config = model.configuration; config.tvMode = value; try model.save(config) }
                                catch { model.message = error.localizedDescription }
                            }))
                            Text("全局 Home：⌃⌥H · \(model.input.globalHomeAvailable ? "已注册" : "注册失败，请检查是否与其他应用冲突")")
                            Text("遥控器可映射为方向键、Enter、Escape 和 ⌃⌥H。手柄方向键导航，A 进入，B 返回；游戏期间输入交给前台游戏。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12)
                    }
                    GroupBox("配置与诊断") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.store.url.path).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            HStack {
                                Button("导出配置", action: model.exportConfiguration)
                                Button("导出诊断", action: model.exportDiagnostics)
                                Button("导入配置", action: model.importConfiguration)
                                Button("打开配置目录") {
                                    let directory = model.store.url.deletingLastPathComponent()
                                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                                    NSWorkspace.shared.open(directory)
                                }
                            }
                            Text("版本 \(model.version) · 本地预览构建\n换机器后需要重新确认路径与系统授权。Hermes、Home Assistant 和多终端服务尚未接入。").font(.caption).foregroundStyle(.secondary)
                        }.padding(12)
                    }
                    GroupBox("最近运行记录") {
                        VStack(alignment: .leading, spacing: 10) {
                            if model.session.events.isEmpty {
                                Text("还没有启动记录。运行应用后会在这里保留最近 50 条结果。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.session.events.prefix(10)) { event in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: eventSymbol(event.kind))
                                        .foregroundStyle(event.kind == .failed ? TVTheme.amber : TVTheme.mint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title).font(.caption).fontWeight(.medium)
                                        Text(event.detail).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(event.date, format: .dateTime.hour().minute().second())
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(12)
                    }
                }
            }
        }.padding(28).frame(width: 680, height: 700)
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
