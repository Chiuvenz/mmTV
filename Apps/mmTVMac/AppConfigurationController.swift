import Contracts
import Core
import MacHost
import Observation

@MainActor
@Observable
final class AppConfigurationController {
    let store: ConfigurationStore
    private(set) var configuration = AppConfiguration()
    private(set) var loadError: String?

    init(store: ConfigurationStore) {
        self.store = store
        do {
            var loaded = try store.load()
            var enriched = false
            for index in loaded.entries.indices
                where loaded.entries[index].kind == .application
                    && loaded.entries[index].applicationBundleID == nil {
                if let bundleID = ApplicationLocationResolver.bundleIdentifier(
                    at: loaded.entries[index].location
                ) {
                    loaded.entries[index].applicationBundleID = bundleID
                    enriched = true
                }
            }
            configuration = loaded
            if enriched { try? store.save(loaded) }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func save(_ updated: AppConfiguration) throws {
        guard loadError == nil else {
            throw LaunchError.invalid(
                "当前配置读取失败，为保护原文件已停止写入。请修复或重新导入配置。"
            )
        }
        try store.save(updated)
        configuration = updated
    }

    func upsert(_ entry: AppEntry) throws {
        try EntryValidation.validate(entry)
        var updated = configuration
        if let index = updated.entries.firstIndex(where: { $0.id == entry.id }) {
            updated.entries[index] = entry
        } else {
            updated.entries.append(entry)
        }
        try save(updated)
    }

    func remove(_ entry: AppEntry) throws {
        var updated = configuration
        updated.entries.removeAll { $0.id == entry.id }
        try save(updated)
    }

    func setEnabled(_ module: ModuleID, _ enabled: Bool) throws {
        var updated = configuration
        if enabled {
            updated.disabledModules.remove(module)
        } else {
            updated.disabledModules.insert(module)
        }
        try save(updated)
    }

    /// Explicit import is also the recovery path for an unreadable configuration.
    func replaceWithImportedConfiguration(_ imported: AppConfiguration) throws {
        try store.save(imported)
        loadError = nil
        configuration = imported
    }
}
