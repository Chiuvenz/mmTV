import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Contracts

struct EntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: AppEntry
    @State private var argumentsText: String
    @State private var trackedBundleID: String
    @State private var resources: String
    @State private var error: String?
    let onSave: (AppEntry) throws -> Void
    init(entry: AppEntry, onSave: @escaping (AppEntry) throws -> Void) {
        self.entry = entry; self.onSave = onSave
        _argumentsText = State(initialValue: entry.arguments.joined(separator: "\n"))
        _trackedBundleID = State(initialValue: entry.trackedBundleID ?? "")
        _resources = State(initialValue: entry.resourceDirectory ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(entry.title.isEmpty ? "添加应用入口" : "编辑应用入口").font(.title2)
            Form {
                TextField("名称", text: $entry.title)
                Picker("启动类型", selection: $entry.kind) {
                    Text("Mac 应用 (.app)").tag(LaunchKind.application)
                    Text("可执行文件 / 启动脚本").tag(LaunchKind.executable)
                }
                HStack {
                    TextField("应用路径", text: $entry.location)
                    Button("选择…", action: chooseTarget)
                }
                HStack {
                    TextField("资源目录（可选）", text: $resources)
                    Button("选择…", action: chooseResources)
                }
                TextField("实际游戏 Bundle ID（可选）", text: $trackedBundleID)
                VStack(alignment: .leading, spacing: 6) {
                    Text("启动参数：每行一个参数").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $argumentsText).font(.system(.body, design: .monospaced)).frame(height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.gray.opacity(0.3)))
                }
                TextField("备注", text: $entry.notes, axis: .vertical)
                Toggle("我已验证该应用可用方向键与遥控器操作", isOn: $entry.tvInteractionVerified)
            }.formStyle(.grouped).scrollDisabled(true)
            if entry.kind == .executable {
                Text("启动器会直接运行所选文件，不会拼接 shell 命令。若启动器另开游戏后退出，请填写实际游戏 Bundle ID，以便跟踪游戏生命周期。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 650)
    }
    private func chooseTarget() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if entry.kind == .application { panel.allowedContentTypes = [.application] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        entry.location = url.path
        if entry.title.isEmpty { entry.title = url.deletingPathExtension().lastPathComponent }
    }
    private func chooseResources() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard panel.runModal() == .OK else { return }
        resources = panel.url?.path ?? ""
    }
    private func save() {
        do {
            var updated = entry
            updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.arguments = argumentsText.components(separatedBy: .newlines).filter { !$0.isEmpty }
            updated.trackedBundleID = trackedBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : trackedBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.resourceDirectory = resources.isEmpty ? nil : resources
            try onSave(updated)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
