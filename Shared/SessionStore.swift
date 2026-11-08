import Foundation

/// One storage location shared by the app and the widget extension.
enum SessionStore {
    static let appGroup = "group.com.whc.restless"
    private static let key = "restless.session.v4"
    private static let legacyKeys = [
        "restless.session.v3",
        "restless.session.v2",
        "restless.session.v1"
    ]

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> SessionSnapshot? {
        // The v3 snapshot encoded the kind/count block plan, the v2 snapshot the
        // part plan and the v1 snapshot the old single-part shape. None can be
        // read as a running session; start ready at the active session instead.
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
    private static let key = "restless.activePreset.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SessionStore.appGroup) ?? .standard
    }

    static var id: UUID? {
        get {
            guard let raw = defaults.string(forKey: key) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: key)
        }
    }
}
