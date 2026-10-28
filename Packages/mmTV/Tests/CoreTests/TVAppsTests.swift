import Testing
import TVApps

@Test func localPlayersAndBiliCandidatesArePresent() {
    let ids = Set(TVAppsModule.candidates.map(\.id))
    #expect(ids.contains("iina"))
    #expect(ids.contains("quicktime"))
    #expect(ids.contains("bilibili"))
    #expect(ids.contains("youtube"))
    let iina = TVAppsModule.candidates.first { $0.id == "iina" }
    #expect(iina?.macBundleID == "com.colliderli.iina")
    let bili = TVAppsModule.candidates.first { $0.id == "bilibili" }
    #expect(bili?.macBundleID == "com.mmtv.bilitv")
    #expect(bili?.launchArguments == ["--tv-fullscreen"])
    #expect(bili?.download.absoluteString == "https://github.com/Chiuvenz/mmTVAdapters")
}
