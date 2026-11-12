import SwiftUI

@main
@MainActor
struct EdicolaApp: App {
    @State private var store = FeedStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .tint(.brand)
                // Sempre chiara, anche se l'iPhone è in modalità scura.
                .preferredColorScheme(.light)
        }
    }
}
