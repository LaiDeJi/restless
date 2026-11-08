import Foundation

/// One movement queued in the add-movement picker, with the set end selected
/// when it was queued. A typed name has no `movementID` until DONE resolves it
/// against the library.
struct PendingMovement: Identifiable, Equatable, Sendable {
    let id: UUID
    let movementID: UUID?
    let name: String
    let condition: EndCondition
    let target: Int?

    init(
        id: UUID = UUID(),
        movementID: UUID? = nil,
        name: String,
        condition: EndCondition,
        target: Int?
    ) {
        self.id = id
        self.movementID = movementID
        self.name = name
        self.condition = condition
        self.target = condition.clampedTarget(target)
    }
}

/// The picker's staged list, kept out of the session draft so CANCEL is a pure
/// dismissal and the 350 ms commit cannot persist a pending choice. A name
/// appears at most once, ignoring case.
struct PendingMovementList: Equatable, Sendable {
    private(set) var items: [PendingMovement] = []

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }

    /// Queues a library movement, or removes it when it is already queued.
    /// A name already staged from the text field is not duplicated.
    mutating func toggle(_ movement: Movement, condition: EndCondition, target: Int?) {
        if let index = items.firstIndex(where: { $0.movementID == movement.id }) {
            items.remove(at: index)
            return
        }
        guard !contains(name: movement.name) else { return }
        items.append(PendingMovement(
            movementID: movement.id,
            name: movement.name,
            condition: condition,
            target: target
        ))
    }

    /// Queues a typed name, trimmed and capped. Returns false for an empty or
    /// already queued name.
    @discardableResult
    mutating func queue(name: String, condition: EndCondition, target: Int?) -> Bool {
        let clean = WorkoutPreset.clampedName(name, fallback: "")
        guard !clean.isEmpty, !contains(name: clean) else { return false }
        items.append(PendingMovement(name: clean, condition: condition, target: target))
        return true
    }

    mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func contains(name: String) -> Bool {
        items.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func contains(movementID: UUID) -> Bool {
        items.contains { $0.movementID == movementID }
    }
}
