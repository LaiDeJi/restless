import Foundation
import SwiftData
import SwiftUI

@main
struct RestlessApp: App {
    private let container: ModelContainer
    @State private var engine: SessionEngine
    @State private var calendarSettings: CalendarSettingsModel
    @State private var watchBridge: WatchSessionBridge

    init() {
        do {
            let container = try Self.makeContainer()
            self.container = container
            // The same main context the views query, so a record saved by the
            // engine appears in the calendar without a relaunch.
            let context = container.mainContext
            let preset = PresetRepository.seedIfNeeded(in: context)
            let engine = SessionEngine(
                preset: preset,
                scheduler: SystemCountdownAlertScheduler()
            )
            engine.movementNamesProvider = {
                MovementRepository.names(in: context)
            }
            engine.historyRecorder = WorkoutHistoryStore(context: context)
            _engine = State(initialValue: engine)
            _calendarSettings = State(initialValue: CalendarSettingsModel())
            _watchBridge = State(initialValue: WatchSessionBridge(engine: engine))
        } catch {
            fatalError("Could not open the preset store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(calendarSettings)
        }
        .modelContainer(container)
    }

    /// The current store, created in a new file after the previous one is
    /// removed. Dropping a stored property needs a store that never had it, so
    /// the old `default.store` and its SQLite companions are deleted before the
    /// container opens. Removal is best effort: a failure leaves an orphan
    /// file, which is harmless.
    private static func makeContainer() throws -> ModelContainer {
        let support = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try? FileManager.default.removeItem(at: support.appending(path: name))
        }
        return try ModelContainer(
            for: PresetRecord.self,
            MovementRecord.self,
            WorkoutRecord.self,
            configurations: ModelConfiguration(url: support.appending(path: "restless-v2.store"))
        )
    }
}
