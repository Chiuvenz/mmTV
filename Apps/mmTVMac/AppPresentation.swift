import Foundation
import Contracts

enum AppPresentation: Identifiable, Equatable {
    case settings
    case setup
    case editor(AppEntry)
    case embeddedWeb(title: String, url: URL, footnote: String)

    var id: String {
        switch self {
        case .settings: "settings"
        case .setup: "setup"
        case .editor(let entry): "editor-\(entry.id.uuidString)"
        case .embeddedWeb(_, let url, _): "web-\(url.absoluteString)"
        }
    }
}
