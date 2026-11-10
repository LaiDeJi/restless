import SwiftData
import SwiftUI

@main
struct RestlessApp: App {
    private let container: ModelContainer
    @State private var engine: SessionEngine

    init() {
        do {
            let container = try ModelContainer(for: PresetRecord.self, MovementRecord.self)
            self.container = container
            let context = ModelContext(container)
            let preset = PresetRepository.seedIfNeeded(in: context)
            let engine = SessionEngine(
                preset: preset,
                scheduler: SystemCountdownAlertScheduler()
            )
            engine.movementNamesProvider = {
                MovementRepository.names(in: context)
            }
            _engine = State(initialValue: engine)
        } catch {
            fatalError("Could not open the preset store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
        }
        .modelContainer(container)
    }
}
