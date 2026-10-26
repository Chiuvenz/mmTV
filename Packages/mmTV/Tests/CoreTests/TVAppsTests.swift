import Testing
import TVApps

@Test func biliTVMacCandidateUsesIndependentBundleAndTVFullscreen() {
    let candidate = TVAppsModule.candidates.first { $0.id == "bilibili" }
    #expect(candidate?.macBundleID == "com.mmtv.bilitv")
    #expect(candidate?.launchArguments == ["--tv-fullscreen"])
}
