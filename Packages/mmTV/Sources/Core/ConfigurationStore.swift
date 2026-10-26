import Foundation
import Contracts

public struct ConfigurationStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public static var standard: Self {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return .init(url: root.appendingPathComponent("mmTV/configuration.json"))
    }
    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let data = try Data(contentsOf: url)
        let header = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let version = header?["schemaVersion"] as? Int else { throw LaunchError.invalid("配置缺少版本号。") }
        guard version == 1 else { throw LaunchError.unsupportedVersion(version) }
        let config = try JSONDecoder().decode(AppConfiguration.self, from: data)
        guard Set(config.entries.map(\.id)).count == config.entries.count else { throw LaunchError.invalid("配置中存在重复应用 ID。") }
        try config.entries.forEach(EntryValidation.validate)
        return config
    }
    public func save(_ configuration: AppConfiguration) throws {
        guard configuration.schemaVersion == 1 else { throw LaunchError.unsupportedVersion(configuration.schemaVersion) }
        guard Set(configuration.entries.map(\.id)).count == configuration.entries.count else { throw LaunchError.invalid("配置中存在重复应用 ID。") }
        try configuration.entries.forEach(EntryValidation.validate)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("previous")
            // Keep the previous bytes even if the new write fails.
            try Data(contentsOf: url).write(to: backup, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}
