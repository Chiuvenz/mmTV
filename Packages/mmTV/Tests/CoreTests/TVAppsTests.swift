import Testing
import Contracts
import TVApps

@Test func localPlayersAndBiliCandidatesArePresent() {
    let ids = Set(TVAppsModule.candidates.map(\.id))
    #expect(ids.contains("jellyfin"))
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

@Test func videoDescriptorReadyWhenMediaLibraryConfigured() {
    let bare = TVAppsModule.descriptor(count: 0, mediaLibrary: nil)
    #expect(bare.status == .needsSetup)
    let library = MediaLibraryConfiguration()
    let ready = TVAppsModule.descriptor(count: 0, mediaLibrary: library)
    #expect(ready.status == .ready)
    #expect(ready.subtitle.contains("Jellyfin"))
    #expect(MediaLibraryConfiguration.defaultLibraryRoots.contains("/Volumes/mmTV Media/Media/Movies"))
    #expect(MediaLibraryConfiguration.defaultLibraryRoots.contains("/Volumes/mmTV Media/Media/TV"))
}
