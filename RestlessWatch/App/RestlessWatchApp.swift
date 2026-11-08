import Foundation
import SwiftUI

@main
struct RestlessWatchApp: App {
    init() {
        let line = "CURL_BOOT,\(Date().timeIntervalSince1970)\n"
        FileHandle.standardOutput.write(Data(line.utf8))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
