import Foundation
import SwiftData

/// Keeps the timer on the session the calendar plans for today. The rule is the
/// pure `ActiveSessionDecision`; this type supplies the stored order, the
/// calendar settings and the active-day marker, and only a switch calls
/// `engine.use`.
@MainActor
enum ActiveSessionFollower {
    /// Initialises the rotation anchor, resolves today's plan and applies the
    /// decision. Idempotent: the day marker makes repeated foregrounds cheap.
    @discardableResult
    static func follow(
        today: Date = .now,
        calendar: Calendar = .current,
        context: ModelContext,
        calendarSettings: CalendarSettingsModel,
        engine: SessionEngine,
        storage: ActivePresetStorage = ActivePresetStorage(
            defaults: UserDefaults(suiteName: SessionStore.appGroup) ?? .standard
        )
    ) -> ActiveSessionDecision {
        calendarSettings.initializeRotation(today: today)

        let presets = PresetRepository.fetchAll(context).map(\.preset)
        let rotation = TrainingRotation(
            settings: calendarSettings.settings,
            sessions: presets.map { RotationSession(id: $0.id, name: $0.name) },
            calendar: calendar
        )
        let plan = rotation.plan(for: today)
        let decision = ActiveSessionDecision.decide(
            activeID: storage.id,
            activeDay: storage.day,
            today: today,
            plan: plan,
            snapshot: engine.snapshot,
            calendar: calendar
        )

        switch decision {
        case .keep:
            break
        case .recordDay:
            storage.day = calendar.startOfDay(for: today)
        case .switchTo(let plan):
            guard let preset = presets.first(where: { $0.id == plan.id }) else { break }
            storage.activate(id: preset.id, on: today)
            engine.use(preset)
        }
        return decision
    }
}
