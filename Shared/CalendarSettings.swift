import Foundation

/// One closure: a dated range, or one repeating weekday. The ends are
/// normalized to the local start of day when the app creates the range;
/// `contains` normalizes again so a stored value with an old time component
/// still covers its first day.
struct CalendarException: Codable, Hashable, Identifiable, Sendable {
    enum Kind: Hashable, Sendable {
        case dates(startDay: Date, endDay: Date)
        case weekday(Int)
    }

    var id: UUID
    var label: String
    private(set) var kind: Kind

    init(
        id: UUID = UUID(),
        startDay: Date,
        endDay: Date,
        label: String = "",
        calendar: Calendar = .current
    ) {
        self.id = id
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = .dates(
            startDay: calendar.startOfDay(for: startDay),
            endDay: calendar.startOfDay(for: endDay)
        )
    }

    init(id: UUID = UUID(), weekday: Int, label: String = "") {
        self.id = id
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = .weekday(weekday)
    }

    var isWeekday: Bool {
        if case .weekday = kind { return true }
        return false
    }

    var startDay: Date? {
        if case .dates(let start, _) = kind { return start }
        return nil
    }

    var endDay: Date? {
        if case .dates(_, let end) = kind { return end }
        return nil
    }

    var weekday: Int? {
        if case .weekday(let number) = kind { return number }
        return nil
    }

    func contains(_ day: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: day)
        switch kind {
        case .dates(let start, let end):
            return target >= start && target <= end
        case .weekday(let number):
            return calendar.component(.weekday, from: target) == number
        }
    }

    /// Nil when a decoded value is not a valid exception: an end before the
    /// start, or a weekday outside 1...7.
    func normalized(calendar: Calendar = .current) -> CalendarException? {
        switch kind {
        case .dates(let start, let end):
            guard end >= start else { return nil }
            return CalendarException(id: id, startDay: start, endDay: end, label: label, calendar: calendar)
        case .weekday(let number):
            guard (1...7).contains(number) else { return nil }
            return CalendarException(id: id, weekday: number, label: label)
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case kind
        case startDay
        case endDay
        case weekday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = (try container.decodeIfPresent(String.self, forKey: .label) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let kindName = try container.decodeIfPresent(String.self, forKey: .kind) ?? "dates"
        if kindName == "weekday" {
            kind = .weekday(try container.decodeIfPresent(Int.self, forKey: .weekday) ?? 0)
        } else {
            kind = .dates(
                startDay: try container.decode(Date.self, forKey: .startDay),
                endDay: try container.decode(Date.self, forKey: .endDay)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        switch kind {
        case .dates(let start, let end):
            try container.encode("dates", forKey: .kind)
            try container.encode(start, forKey: .startDay)
            try container.encode(end, forKey: .endDay)
        case .weekday(let number):
            try container.encode("weekday", forKey: .kind)
            try container.encode(number, forKey: .weekday)
        }
    }
}

/// One date that plans another saved session without moving the schedule.
struct DayChange: Codable, Hashable, Identifiable, Sendable {
    private(set) var day: Date
    var presetID: UUID

    var id: Date { day }

    init(day: Date, presetID: UUID, calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: day)
        self.presetID = presetID
    }
}

/// The calendar's persisted preferences: the rest gap, the exceptions, the
/// skipped dates, the per-date exercise changes, and the rotation anchor. Pure
/// Foundation so both the app and the widget target can compile it.
struct CalendarSettings: Codable, Hashable, Sendable {
    static let maxRestDaysBetween = 6
    static let sunday = 1

    private(set) var restDaysBetween: Int
    private(set) var exceptions: [CalendarException]
    private(set) var skippedDays: Set<Date>
    private(set) var dayChanges: [DayChange]
    private(set) var rotationAnchor: Date?

    init(
        restDaysBetween: Int = 0,
        exceptions: [CalendarException] = [],
        skippedDays: Set<Date> = [],
        dayChanges: [DayChange] = [],
        rotationAnchor: Date? = nil,
        calendar: Calendar = .current
    ) {
        self.restDaysBetween = min(max(restDaysBetween, 0), Self.maxRestDaysBetween)
        self.exceptions = exceptions
        self.skippedDays = Set(skippedDays.map { calendar.startOfDay(for: $0) })
        self.dayChanges = dayChanges
        self.rotationAnchor = rotationAnchor.map { calendar.startOfDay(for: $0) }
    }

    // MARK: Mutations

    mutating func setRestDaysBetween(_ value: Int) {
        restDaysBetween = min(max(value, 0), Self.maxRestDaysBetween)
    }

    /// Returns false when the end is before the start; the stored ranges are
    /// untouched in that case.
    @discardableResult
    mutating func addException(
        id: UUID = UUID(),
        startDay: Date,
        endDay: Date,
        label: String = "",
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard end >= start else { return false }
        exceptions.append(
            CalendarException(id: id, startDay: start, endDay: end, label: label, calendar: calendar)
        )
        return true
    }

    /// Returns false for a weekday outside 1...7, or one already closed.
    @discardableResult
    mutating func addWeekdayException(_ weekday: Int, label: String = "") -> Bool {
        guard (Self.sunday...7).contains(weekday) else { return false }
        guard !exceptions.contains(where: { $0.weekday == weekday }) else { return false }
        exceptions.append(CalendarException(weekday: weekday, label: label))
        return true
    }

    mutating func removeException(_ id: UUID) {
        exceptions.removeAll { $0.id == id }
    }

    mutating func setRotationAnchor(_ day: Date?, calendar: Calendar = .current) {
        rotationAnchor = day.map { calendar.startOfDay(for: $0) }
    }

    mutating func skip(_ day: Date, calendar: Calendar = .current) {
        skippedDays.insert(calendar.startOfDay(for: day))
    }

    mutating func unskip(_ day: Date, calendar: Calendar = .current) {
        skippedDays.remove(calendar.startOfDay(for: day))
    }

    mutating func clearSkips() {
        skippedDays.removeAll()
    }

    mutating func clearDayChanges() {
        dayChanges.removeAll()
    }

    mutating func setDayChange(day: Date, presetID: UUID, calendar: Calendar = .current) {
        let target = calendar.startOfDay(for: day)
        dayChanges.removeAll { $0.day == target }
        dayChanges.append(DayChange(day: target, presetID: presetID, calendar: calendar))
    }

    mutating func clearDayChange(day: Date, calendar: Calendar = .current) {
        let target = calendar.startOfDay(for: day)
        dayChanges.removeAll { $0.day == target }
    }

    /// Drops changes for dates before `day`, which can no longer be planned.
    mutating func pruneDayChanges(before day: Date, calendar: Calendar = .current) {
        let cutoff = calendar.startOfDay(for: day)
        dayChanges.removeAll { $0.day < cutoff }
    }

    // MARK: Days

    func isSkipped(_ day: Date, calendar: Calendar = .current) -> Bool {
        skippedDays.contains(calendar.startOfDay(for: day))
    }

    /// The dated range first, then a repeating weekday.
    func exception(containing day: Date, calendar: Calendar = .current) -> CalendarException? {
        let target = calendar.startOfDay(for: day)
        if let dated = exceptions.first(where: {
            guard case .dates = $0.kind else { return false }
            return $0.contains(target, calendar: calendar)
        }) {
            return dated
        }
        return exceptions.first(where: {
            guard case .weekday = $0.kind else { return false }
            return $0.contains(target, calendar: calendar)
        })
    }

    func isClosed(_ day: Date, calendar: Calendar = .current) -> Bool {
        exception(containing: day, calendar: calendar) != nil
    }

    /// The change stored for a date, if any.
    func change(for day: Date, calendar: Calendar = .current) -> DayChange? {
        let target = calendar.startOfDay(for: day)
        return dayChanges.first { $0.day == target }
    }

    // MARK: Sanitizing

    /// Rebuilds the value through the initializer, so a decoded document that
    /// somehow holds an inverted range, an unknown weekday or a day with two
    /// changes cannot reach the calendar.
    func sanitized(calendar: Calendar = .current) -> CalendarSettings {
        var clean = CalendarSettings(restDaysBetween: restDaysBetween, calendar: calendar)
        var seenWeekdays = Set<Int>()
        clean.exceptions = exceptions.compactMap { $0.normalized(calendar: calendar) }.filter { exception in
            guard case .weekday(let number) = exception.kind else { return true }
            return seenWeekdays.insert(number).inserted
        }
        clean.skippedDays = Set(skippedDays.map { calendar.startOfDay(for: $0) })
        var changes: [Date: DayChange] = [:]
        for change in dayChanges {
            let day = calendar.startOfDay(for: change.day)
            changes[day] = DayChange(day: day, presetID: change.presetID, calendar: calendar)
        }
        clean.dayChanges = changes.values.sorted { $0.day < $1.day }
        clean.rotationAnchor = rotationAnchor.map { calendar.startOfDay(for: $0) }
        return clean
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case restDaysBetween
        case exceptions
        case skippedDays
        case dayChanges
        case rotationAnchor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decoding stays raw: the store and the tests call `sanitized()` with
        // the calendar they use, so a document is never normalized against the
        // device's timezone by accident.
        restDaysBetween = try container.decodeIfPresent(Int.self, forKey: .restDaysBetween) ?? 0
        exceptions = try container.decodeIfPresent([CalendarException].self, forKey: .exceptions) ?? []
        skippedDays = Set(try container.decodeIfPresent([Date].self, forKey: .skippedDays) ?? [])
        dayChanges = try container.decodeIfPresent([DayChange].self, forKey: .dayChanges) ?? []
        rotationAnchor = try container.decodeIfPresent(Date.self, forKey: .rotationAnchor)
    }
}

/// One Codable document in `UserDefaults`. The defaults, the keys and the
/// calendar are injected so a test never shares the app's stored calendar.
///
/// A v1 document is migrated on load: the anchor and the exceptions keep their
/// dates, each rest weekday becomes a weekday exception, the week-start choice
/// is dropped, and the gap, skips and changes start empty. The migrated v2
/// document is saved, and v1 is left in place so a rollback build still reads
/// its own shape.
struct CalendarSettingsStore {
    static let defaultKey = "restless.calendar.v2"
    static let legacyKey = "restless.calendar.v1"

    private let defaults: UserDefaults
    private let key: String
    private let legacyKey: String
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        key: String = CalendarSettingsStore.defaultKey,
        legacyKey: String = CalendarSettingsStore.legacyKey,
        calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.key = key
        self.legacyKey = legacyKey
        self.calendar = calendar
    }

    func load() -> CalendarSettings {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(CalendarSettings.self, from: data) {
            return decoded.sanitized(calendar: calendar)
        }
        if key != legacyKey,
           let data = defaults.data(forKey: legacyKey),
           let legacy = try? JSONDecoder().decode(LegacyCalendar.self, from: data) {
            let migrated = legacy.migrated(calendar: calendar)
            save(migrated)
            return migrated
        }
        return CalendarSettings()
    }

    func save(_ settings: CalendarSettings) {
        var copy = settings.sanitized(calendar: calendar)
        copy.pruneDayChanges(before: Date(), calendar: calendar)
        guard let data = try? JSONEncoder().encode(copy) else { return }
        defaults.set(data, forKey: key)
    }
}

/// The v1 fields this app can still read. `weekStart` is decoded so the
/// document shape is recognized, then deliberately ignored.
private struct LegacyCalendar: Decodable {
    struct LegacyException: Decodable {
        var id: UUID?
        var startDay: Date
        var endDay: Date
        var label: String?
    }

    var weekStart: Int?
    var restWeekdays: [Int]?
    var exceptions: [LegacyException]?
    var rotationAnchor: Date?

    func migrated(calendar: Calendar) -> CalendarSettings {
        var settings = CalendarSettings(calendar: calendar)
        settings.setRotationAnchor(rotationAnchor, calendar: calendar)
        for exception in exceptions ?? [] {
            settings.addException(
                id: exception.id ?? UUID(),
                startDay: exception.startDay,
                endDay: exception.endDay,
                label: exception.label ?? "",
                calendar: calendar
            )
        }
        for weekday in Set(restWeekdays ?? []).sorted() where (CalendarSettings.sunday...7).contains(weekday) {
            settings.addWeekdayException(weekday)
        }
        return settings
    }
}
