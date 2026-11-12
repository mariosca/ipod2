import SwiftUI

@main
@MainActor
struct EdicolaApp: App {
    @State private var store = FeedStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
