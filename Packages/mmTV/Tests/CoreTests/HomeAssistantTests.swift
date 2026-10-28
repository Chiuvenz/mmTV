import Foundation
import Testing
import Contracts
import Core
import Home

@Test func homeAssistantPlaceholderDetection() {
    var config = HomeAssistantConfiguration(token: "REPLACE_WITH_LONG_LIVED_TOKEN", useMock: false)
    #expect(config.looksLikePlaceholderToken)
    #expect(!config.canUseLiveAPI)
    config.token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo"
    config.useMock = false
    #expect(!config.looksLikePlaceholderToken)
    #expect(config.canUseLiveAPI)
}

@Test func homeModuleDescriptorReflectsMockAndLive() {
    #expect(HomeModule.descriptor(for: nil).status == .needsSetup)
    let mock = HomeAssistantConfiguration(useMock: true)
    #expect(HomeModule.descriptor(for: mock).status == .ready)
    var live = HomeAssistantConfiguration(token: "real-token-value", useMock: false)
    #expect(HomeModule.descriptor(for: live).status == .ready)
    // Empty token still allows Lovelace (HA’s own login); only wipe URL → needsSetup.
    live.token = ""
    #expect(HomeModule.descriptor(for: live).status == .ready)
    live.baseURL = ""
    #expect(HomeModule.descriptor(for: live).status == .needsSetup)
}

@Test func mockHomeClientTogglesLightsAndActivatesScenes() async throws {
    let client = HomeAssistantClient()
    let config = HomeAssistantConfiguration(useMock: true)
    let snap = await client.snapshot(for: config)
    guard case .success(let states) = snap else {
        Issue.record("expected mock snapshot success")
        return
    }
    #expect(states.count == 3)
    #expect(states[0].isOn == false)

    let light = HomeControl.demoDefaults[0]
    let toggledResult = await client.activate(light, configuration: config)
    guard case .success(let toggled) = toggledResult else {
        Issue.record("expected light toggle success")
        return
    }
    #expect(toggled.isOn == true)

    let scene = HomeControl.demoDefaults[2]
    let activatedResult = await client.activate(scene, configuration: config)
    guard case .success(let activated) = activatedResult else {
        Issue.record("expected scene activate success")
        return
    }
    #expect(activated.kind == .scene)
    #expect(activated.detail.contains("激活"))
}

@Test func configurationRoundTripKeepsHomeAssistant() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    var config = AppConfiguration()
    config.homeAssistant = HomeAssistantConfiguration(
        baseURL: "http://127.0.0.1:8123",
        token: "secret",
        useMock: false,
        controls: [.init(id: "light.a", title: "A", kind: .light)]
    )
    try store.save(config)
    let loaded = try store.load()
    #expect(loaded.homeAssistant?.baseURL == "http://127.0.0.1:8123")
    #expect(loaded.homeAssistant?.controls.first?.id == "light.a")
    #expect(loaded.homeAssistant?.useMock == false)
}

@Test func olderConfigurationWithoutHomeAssistantStillLoads() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("config.json")
    try Data(#"{"schemaVersion":1,"entries":[],"disabledModules":[],"tvMode":false}"#.utf8).write(to: url)
    let loaded = try ConfigurationStore(url: url).load()
    #expect(loaded.homeAssistant == nil)
    #expect(HomeModule.resolvedConfiguration(in: loaded).useMock)
}

@Test func homeAssistantDecodesLegacyJSONWithoutUIMode() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("config.json")
    let json = """
    {"schemaVersion":1,"entries":[],"disabledModules":[],"tvMode":false,"homeAssistant":{"baseURL":"http://ha.local:8123","token":"x","useMock":false,"controls":[]}}
    """
    try Data(json.utf8).write(to: url)
    let loaded = try ConfigurationStore(url: url).load()
    #expect(loaded.homeAssistant?.uiMode == .lovelace)
    #expect(loaded.homeAssistant?.dashboardPath == "/")
    #expect(loaded.homeAssistant?.dashboardURL?.absoluteString == "http://ha.local:8123/")
    #expect(loaded.homeAssistant?.prefersLovelaceUI == true)
}

@Test func mediaLibraryRoundTrip() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = ConfigurationStore(url: folder.appendingPathComponent("config.json"))
    var config = AppConfiguration()
    config.mediaLibrary = MediaLibraryConfiguration(
        provider: .jellyfin,
        baseURL: "http://127.0.0.1:8096",
        libraryRoots: ["/Volumes/mmTV Media/Media/Movies"],
        embedInShell: true
    )
    try store.save(config)
    let loaded = try store.load()
    #expect(loaded.mediaLibrary?.provider == .jellyfin)
    #expect(loaded.mediaLibrary?.libraryRoots.first == "/Volumes/mmTV Media/Media/Movies")
    #expect(loaded.mediaLibrary?.embedInShell == true)
}
