import SwiftUI

@main
@MainActor
struct DoveSonoOraWatchApp: App {
    init() {
        // Più spazio per le tessere della carta Topo già viste.
        URLCache.shared = URLCache(memoryCapacity: 16 << 20, diskCapacity: 150 << 20)
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}
