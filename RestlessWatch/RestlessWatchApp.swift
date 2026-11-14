import SwiftUI

@main
struct RestlessWatchApp: App {
    @State private var model = WatchRemoteModel()

    var body: some Scene {
        WindowGroup {
            WatchRemoteView()
                .environment(model)
        }
    }
}
