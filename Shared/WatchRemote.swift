import Foundation

/// The actions a wrist tap can send. `ignored` exists so a value from a newer
/// watch build decodes instead of throwing and abandoning the whole message.
enum WatchActionKind: String, CaseIterable, Codable, Hashable, Sendable {
    case startSession
    case setDone
    case startSet
    case pause
    case resume
    case skipRest
    case restart
    case ignored

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = WatchActionKind(rawValue: raw) ?? .ignored
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// nil for an unknown action and for `finishRest`, which only the phone's
    /// deadline ticker may produce.
    var sessionAction: SessionAction? {
        switch self {
        case .startSession: return .startSession
        case .setDone: return .setDone
        case .startSet: return .startSet
        case .pause: return .pause
        case .resume: return .resume
        case .skipRest: return .skipRest
        case .restart: return .restart
        case .ignored: return nil
        }
    }

    init?(_ action: SessionAction) {
        switch action {
        case .startSession: self = .startSession
        case .setDone: self = .setDone
        case .startSet: self = .startSet
        case .pause: self = .pause
        case .resume: self = .resume
        case .skipRest: self = .skipRest
        case .restart: self = .restart
        // A deadline is the phone's own transition, never a tap.
        case .finishRest: return nil
        }
    }
}

/// One tap, carrying both the instant it happened and an id the phone uses to
/// apply it at most once.
struct WatchActionMessage: Codable, Hashable, Sendable {
    var id: UUID
    var action: WatchActionKind
    var tapTime: Date

    init(id: UUID = UUID(), action: WatchActionKind, tapTime: Date = .now) {
        self.id = id
        self.action = action
        self.tapTime = tapTime
    }
}

/// What the phone feeds the wrist: the running snapshot, the active plan and
/// the library names its movement ids resolve to. The watch renders this and
/// sends nothing back.
struct WatchSessionPayload: Codable, Hashable, Sendable {
    var snapshot: SessionSnapshot
    var activePreset: WorkoutPreset
    var movementNames: [UUID: String]

    init(snapshot: SessionSnapshot, movementNames: [UUID: String] = [:]) {
        self.snapshot = snapshot
        self.activePreset = snapshot.preset
        self.movementNames = movementNames
    }

    /// nil when the phone has nothing the wrist could control. The app seeds a
    /// plan, but a plan whose blocks have no movements cannot start a session,
    /// so it is not published.
    static func published(
        snapshot: SessionSnapshot,
        movementNames: [UUID: String] = [:]
    ) -> WatchSessionPayload? {
        guard snapshot.preset.canCommit else { return nil }
        return WatchSessionPayload(snapshot: snapshot, movementNames: movementNames)
    }

    /// The movement the current position names, falling back to the block when
    /// the library name never reached the wrist.
    var movementName: String {
        movementName(for: displaySnapshot(at: .now))
    }

    /// The movement a given display snapshot's position names.
    func movementName(for snapshot: SessionSnapshot) -> String {
        let position = snapshot.position
        if let name = movementNames[position.movementId] { return name }
        return snapshot.currentBlock.name
    }

    /// The block, round and set the current position names.
    var position: WorkoutPosition { displaySnapshot(at: .now).position }

    /// Display-only: an expired deadline selects the phase that follows it. A
    /// deadline is applied at its own instant, so a late look still lands on the
    /// next deadline the phone would have set. The result is never sent back.
    func displaySnapshot(at now: Date) -> SessionSnapshot {
        var copy = snapshot
        while let deadline = copy.countdownDeadline, deadline <= now {
            _ = copy.reconcile(now: deadline)
        }
        return copy
    }
}

/// The property-list dictionary shape WatchConnectivity carries. Kept in
/// `Shared/` and free of WatchConnectivity so the message format is testable
/// and the widget can compile the same file.
enum WatchRemoteWire {
    static let actionKey = "restless.watch.action"
    static let sessionKey = "restless.watch.session"

    static func message(for action: WatchActionMessage) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(action) else { return [:] }
        return [actionKey: data]
    }

    static func action(from message: [String: Any]) -> WatchActionMessage? {
        guard let data = message[actionKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchActionMessage.self, from: data)
    }

    /// An empty context is how the phone says it has nothing to control.
    static func context(for payload: WatchSessionPayload?) -> [String: Any] {
        guard let payload, let data = try? JSONEncoder().encode(payload) else { return [:] }
        return [sessionKey: data]
    }

    static func payload(from context: [String: Any]) -> WatchSessionPayload? {
        guard let data = context[sessionKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchSessionPayload.self, from: data)
    }
}
