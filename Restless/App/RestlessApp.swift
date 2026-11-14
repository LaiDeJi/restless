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
            let container = try ModelContainer(
                for: PresetRecord.self,
                MovementRecord.self,
                WorkoutRecord.self
            )
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
}
