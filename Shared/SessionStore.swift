import Foundation

/// One storage location shared by the app and the widget extension.
enum SessionStore {
    static let appGroup = "group.com.whc.restless"
    private static let key = "restless.session.v5"
    private static let legacyKeys = [
        "restless.session.v4",
        "restless.session.v3",
        "restless.session.v2",
        "restless.session.v1"
    ]

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> SessionSnapshot? {
        // A v4 snapshot counted completed sets under the round-major order, so
        // the same count points at a different set now. It, like the v3
        // kind/count plan, the v2 part plan and the v1 single-part shape, cannot
        // be read as a running session; start ready at the active session.
        for legacy in legacyKeys {
            defaults.removeObject(forKey: legacy)
        }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }

    static func save(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}

enum ActivePresetStore {
    private static var storage: ActivePresetStorage {
        ActivePresetStorage(defaults: UserDefaults(suiteName: SessionStore.appGroup) ?? .standard)
    }

    static var id: UUID? {
        get { storage.id }
        set { storage.id = newValue }
    }

    /// The local day the active id was chosen for. Nil means stale, including
    /// installs that predate the marker.
    static var day: Date? {
        get { storage.day }
        set { storage.day = newValue }
    }

    /// A manual pick: the id and the local day it was chosen for, together.
    static func activate(id: UUID, on day: Date = .now) {
        storage.activate(id: id, on: day)
    }

    /// True only when the marker names this local day.
    static func marks(_ day: Date, calendar: Calendar = .current) -> Bool {
        storage.marks(day, calendar: calendar)
    }
}

/// The active session and its day marker. A value with an injectable defaults
/// suite so the follower's rules can be tested without the live app defaults.
struct ActivePresetStorage {
    static let defaultIDKey = "restless.activePreset.v1"
    static let defaultDayKey = "restless.activePresetDay.v1"

    let defaults: UserDefaults
    var idKey: String = ActivePresetStorage.defaultIDKey
    var dayKey: String = ActivePresetStorage.defaultDayKey

    var id: UUID? {
        get {
            guard let raw = defaults.string(forKey: idKey) else { return nil }
            return UUID(uuidString: raw)
        }
        nonmutating set {
            defaults.set(newValue?.uuidString, forKey: idKey)
        }
    }

    var day: Date? {
        get { defaults.object(forKey: dayKey) as? Date }
        nonmutating set { defaults.set(newValue, forKey: dayKey) }
    }

    func activate(id: UUID, on day: Date) {
        self.id = id
        self.day = day
    }

    /// A missing marker is stale, so the first launch after the upgrade
    /// follows today's plan.
    func marks(_ day: Date, calendar: Calendar = .current) -> Bool {
        guard let stored = self.day else { return false }
        return calendar.isDate(stored, inSameDayAs: day)
    }
}
