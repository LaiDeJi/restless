import SwiftData
import SwiftUI

@main
struct RestlessApp: App {
    private let container: ModelContainer
    @State private var engine: SessionEngine
    @State private var watchLink: WatchLink

    init() {
        do {
            let container = try ModelContainer(for: PresetRecord.self, MovementRecord.self)
            self.container = container
            let context = ModelContext(container)
            let preset = PresetRepository.seedIfNeeded(in: context)
            let engine = SessionEngine(preset: preset)
            engine.movementNamesProvider = {
                MovementRepository.names(in: context)
            }
            _engine = State(initialValue: engine)
            _watchLink = State(initialValue: WatchLink(transport: WatchSessionTransport.shared))
            WatchSessionTransport.shared.activate()
        } catch {
            fatalError("Could not open the preset store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(watchLink)
        }
        .modelContainer(container)
    }
}
