import Contracts

public enum GamesModule {
    public static func descriptor(count: Int) -> ModuleDescriptor {
        .init(.games, title: "玩一会儿", subtitle: "游戏 · 模拟器 · 你的收藏", symbol: "gamecontroller", status: count > 0 ? .ready : .needsSetup)
    }
    public static func entries(in configuration: AppConfiguration) -> [AppEntry] {
        configuration.entries.filter { $0.module == .games }
    }
}
