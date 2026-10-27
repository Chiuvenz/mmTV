import Contracts

enum AppPresentation: Identifiable, Equatable {
    case settings
    case setup
    case editor(AppEntry)

    var id: String {
        switch self {
        case .settings: "settings"
        case .setup: "setup"
        case .editor(let entry): "editor-\(entry.id.uuidString)"
        }
    }
}
