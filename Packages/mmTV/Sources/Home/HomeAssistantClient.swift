import Foundation
import Contracts

/// Thin Home Assistant REST client for the living-room demo.
/// Live path: `/api/` health, `/api/states/{entity}`, `/api/services/{domain}/{service}`.
/// Mock path: in-memory on/off for lights/switches; scenes always “activate”.
public actor HomeAssistantClient {
    public enum ClientError: LocalizedError, Equatable, Sendable {
        case notConfigured
        case badURL
        case http(Int, String)
        case decoding
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .notConfigured: "尚未配置 Home Assistant（可先开 useMock）。"
            case .badURL: "Home Assistant 地址无效。"
            case .http(let code, let body): "HA 返回 \(code)：\(body)"
            case .decoding: "无法解析 Home Assistant 响应。"
            case .transport(let reason): reason
            }
        }
    }

    private var mockOn: [String: Bool] = [:]
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func resetMock() {
        mockOn = [:]
    }

    public func snapshot(for configuration: HomeAssistantConfiguration) async -> Result<[HomeControlState], ClientError> {
        let controls = configuration.controls.isEmpty ? HomeControl.demoDefaults : configuration.controls
        if configuration.useMock || !configuration.canUseLiveAPI {
            return .success(controls.map { mockState(for: $0) })
        }
        do {
            _ = try await get(path: "/api/", configuration: configuration)
            var states: [HomeControlState] = []
            for control in controls {
                states.append(try await liveState(for: control, configuration: configuration))
            }
            return .success(states)
        } catch let error as ClientError {
            return .failure(error)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }

    public func activate(_ control: HomeControl, configuration: HomeAssistantConfiguration) async -> Result<HomeControlState, ClientError> {
        if configuration.useMock || !configuration.canUseLiveAPI {
            return .success(tryMockActivate(control))
        }
        do {
            switch control.kind {
            case .scene:
                try await callService(domain: "scene", service: "turn_on",
                                      entityID: control.id, configuration: configuration)
                return .success(.init(id: control.id, title: control.title, kind: .scene,
                                      isOn: nil, detail: "已激活"))
            case .light, .switch:
                let current = try await liveState(for: control, configuration: configuration)
                let turnOn = !(current.isOn ?? false)
                let domain = control.kind == .light ? "light" : "switch"
                try await callService(domain: domain, service: turnOn ? "turn_on" : "turn_off",
                                      entityID: control.id, configuration: configuration)
                return .success(.init(id: control.id, title: control.title, kind: control.kind,
                                      isOn: turnOn, detail: turnOn ? "已开启" : "已关闭"))
            }
        } catch let error as ClientError {
            return .failure(error)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }

    private func tryMockActivate(_ control: HomeControl) -> HomeControlState {
        switch control.kind {
        case .scene:
            return .init(id: control.id, title: control.title, kind: .scene, isOn: nil, detail: "模拟 · 已激活")
        case .light, .switch:
            let next = !(mockOn[control.id] ?? false)
            mockOn[control.id] = next
            return .init(id: control.id, title: control.title, kind: control.kind,
                         isOn: next, detail: next ? "模拟 · 开" : "模拟 · 关")
        }
    }

    private func mockState(for control: HomeControl) -> HomeControlState {
        switch control.kind {
        case .scene:
            return .init(id: control.id, title: control.title, kind: .scene, isOn: nil, detail: "模拟场景")
        case .light, .switch:
            let on = mockOn[control.id] ?? false
            return .init(id: control.id, title: control.title, kind: control.kind,
                         isOn: on, detail: on ? "模拟 · 开" : "模拟 · 关")
        }
    }

    private func liveState(for control: HomeControl, configuration: HomeAssistantConfiguration) async throws -> HomeControlState {
        if control.kind == .scene {
            return .init(id: control.id, title: control.title, kind: .scene, isOn: nil, detail: "场景")
        }
        let data = try await get(path: "/api/states/\(control.id)", configuration: configuration)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            throw ClientError.decoding
        }
        let on = state == "on"
        return .init(id: control.id, title: control.title, kind: control.kind,
                     isOn: on, detail: on ? "开" : "关")
    }

    private func callService(domain: String, service: String, entityID: String,
                             configuration: HomeAssistantConfiguration) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["entity_id": entityID])
        _ = try await request(method: "POST", path: "/api/services/\(domain)/\(service)",
                              body: body, configuration: configuration)
    }

    private func get(path: String, configuration: HomeAssistantConfiguration) async throws -> Data {
        try await request(method: "GET", path: path, body: nil, configuration: configuration)
    }

    private func request(method: String, path: String, body: Data?,
                         configuration: HomeAssistantConfiguration) async throws -> Data {
        guard var components = URLComponents(string: configuration.baseURL) else { throw ClientError.badURL }
        let basePath = (components.path as NSString).standardizingPath
        let suffix = path.hasPrefix("/") ? path : "/" + path
        components.path = (basePath == "/" ? "" : basePath) + suffix
        guard let url = components.url else { throw ClientError.badURL }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ClientError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw ClientError.transport("无 HTTP 响应") }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let clipped = bodyText.isEmpty ? "(empty)" : String(bodyText.prefix(160))
            throw ClientError.http(http.statusCode, clipped)
        }
        return data
    }
}
