import Foundation
import Observation

/// One movement plus the set end chosen for it, ready for a batch append.
struct MovementAddition: Equatable, Sendable {
    let movement: Movement
    let condition: EndCondition
    let target: Int?
}

/// The block a block editor, movement editor, or picker is addressing. A staged
/// block is authored outside `session.blocks` and only reaches the session on
/// DONE.
enum BlockEditingTarget: Hashable, Sendable {
    case saved(UUID)
    case staged
}

/// Holds one session's edits in memory. The UI reads this draft directly, so a
/// stepper tap or keystroke changes the number in the same frame; persistence,
/// the session reset, and the Live Activity refresh happen once per burst.
@MainActor
@Observable
final class SessionDraftStore {
    var session: WorkoutPreset
    private(set) var isDirty = false
    /// A new block being authored. Not part of `session.blocks`; its edits never
    /// dirty the draft or schedule a save.
    private(set) var stagedBlock: WorkoutBlock?

    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var isDragging = false
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored var commit: (@MainActor (WorkoutPreset) -> Void)?

    init(session: WorkoutPreset, delay: Duration = .milliseconds(350)) {
        self.session = session
        self.delay = delay
    }

    func edit(_ mutate: (inout WorkoutPreset) -> Void) {
        mutate(&session)
        isDirty = true
        schedule()
    }

    // MARK: Drag

    /// Suspends the debounce for a drag gesture. An edit already waiting stays
    /// dirty and is committed by `endDrag()`; nothing is saved while the finger
    /// is down.
    func beginDrag() {
        guard !isDragging else { return }
        isDragging = true
        pending?.cancel()
        pending = nil
    }

    /// Ends a drag and flushes once, so the dropped order and any edit that was
    /// waiting when the drag began are saved together.
    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        flush()
    }

    // MARK: Staged block

    /// Creates the block `+ ADD BLOCK` authors. It copies the previous block's
    /// rests and no movements. A second call is ignored while one is staged.
    func beginStagedBlock(after previous: WorkoutBlock?) {
        guard stagedBlock == nil else { return }
        stagedBlock = WorkoutBlock(
            name: "Untitled block",
            rounds: WorkoutBlock.defaultRounds,
            setsPerRound: WorkoutBlock.defaultSetsPerRound,
            setRest: previous?.setRest ?? WorkoutBlock.defaultSetRest,
            roundRest: previous?.roundRest ?? WorkoutBlock.defaultRoundRest
        )
    }

    func block(_ target: BlockEditingTarget) -> WorkoutBlock? {
        switch target {
        case .saved(let id):
            session.blocks.first { $0.id == id }
        case .staged:
            stagedBlock
        }
    }

    /// A saved block edit goes through the usual debounced draft edit. A staged
    /// edit stays in memory and does not mark the draft dirty.
    func editBlock(_ target: BlockEditingTarget, _ mutate: (inout WorkoutBlock) -> Void) {
        switch target {
        case .saved(let id):
            edit { session in
                guard let index = session.blocks.firstIndex(where: { $0.id == id }) else { return }
                mutate(&session.blocks[index])
            }
        case .staged:
            guard var block = stagedBlock else { return }
            mutate(&block)
            stagedBlock = block
        }
    }

    /// DONE is the only path that appends a staged block. It reuses the same
    /// clamping and rounds rules as `appendBlock`, and leaves the staged block
    /// in place when it has no movements.
    @discardableResult
    func commitStagedBlock() -> Bool {
        guard let staged = stagedBlock, appendBlock(staged) else { return false }
        stagedBlock = nil
        return true
    }

    func discardStagedBlock() {
        stagedBlock = nil
    }

    /// Moves a block onto another block's position. Removing the source first
    /// and inserting at the target's original index makes the move
    /// direction-aware: down lands after the target, up lands before it.
    @discardableResult
    func moveBlock(_ id: UUID, onto targetID: UUID) -> Bool {
        guard id != targetID,
              let from = session.blocks.firstIndex(where: { $0.id == id }),
              let to = session.blocks.firstIndex(where: { $0.id == targetID })
        else { return false }
        edit { session in
            let block = session.blocks.remove(at: from)
            session.blocks.insert(block, at: to)
        }
        return true
    }

    @discardableResult
    func removeBlock(_ id: UUID) -> Bool {
        guard session.blocks.count > 1,
              session.blocks.contains(where: { $0.id == id })
        else { return false }
        edit { $0.blocks.removeAll { $0.id == id } }
        return true
    }

    @discardableResult
    func moveMovement(_ id: UUID, inBlock blockID: UUID, onto targetID: UUID) -> Bool {
        guard id != targetID,
              let blockIndex = session.blocks.firstIndex(where: { $0.id == blockID }),
              let from = session.blocks[blockIndex].movements.firstIndex(where: { $0.id == id }),
              let to = session.blocks[blockIndex].movements.firstIndex(where: { $0.id == targetID })
        else { return false }
        edit { session in
            let movement = session.blocks[blockIndex].movements.remove(at: from)
            session.blocks[blockIndex].movements.insert(movement, at: to)
        }
        return true
    }

    @discardableResult
    func moveMovement(_ id: UUID, in target: BlockEditingTarget, onto targetID: UUID) -> Bool {
        switch target {
        case .saved(let blockID):
            return moveMovement(id, inBlock: blockID, onto: targetID)
        case .staged:
            guard id != targetID,
                  var block = stagedBlock,
                  let from = block.movements.firstIndex(where: { $0.id == id }),
                  let to = block.movements.firstIndex(where: { $0.id == targetID })
            else { return false }
            let movement = block.movements.remove(at: from)
            block.movements.insert(movement, at: to)
            stagedBlock = block
            return true
        }
    }

    /// Replaces the block order in one draft edit. `order` must be a
    /// permutation of the current block ids; anything else leaves the session
    /// untouched so a stale provisional order cannot drop a block.
    @discardableResult
    func reorderBlocks(to order: [UUID]) -> Bool {
        let ids = session.blocks.map(\.id)
        guard Self.isPermutation(order, of: ids) else { return false }
        guard order != ids else { return true }
        edit { session in
            let byID = Dictionary(uniqueKeysWithValues: session.blocks.map { ($0.id, $0) })
            session.blocks = order.compactMap { byID[$0] }
        }
        return true
    }

    /// Replaces a block's movement order in one edit. A staged block is written
    /// directly and never dirties the draft or schedules a save.
    @discardableResult
    func reorderMovements(in target: BlockEditingTarget, to order: [UUID]) -> Bool {
        switch target {
        case .saved(let blockID):
            guard let blockIndex = session.blocks.firstIndex(where: { $0.id == blockID }) else {
                return false
            }
            let ids = session.blocks[blockIndex].movements.map(\.id)
            guard Self.isPermutation(order, of: ids) else { return false }
            guard order != ids else { return true }
            edit { session in
                let byID = Dictionary(
                    uniqueKeysWithValues: session.blocks[blockIndex].movements.map { ($0.id, $0) }
                )
                session.blocks[blockIndex].movements = order.compactMap { byID[$0] }
            }
            return true
        case .staged:
            guard var block = stagedBlock else { return false }
            let ids = block.movements.map(\.id)
            guard Self.isPermutation(order, of: ids) else { return false }
            guard order != ids else { return true }
            let byID = Dictionary(uniqueKeysWithValues: block.movements.map { ($0.id, $0) })
            block.movements = order.compactMap { byID[$0] }
            stagedBlock = block
            return true
        }
    }

    private static func isPermutation(_ order: [UUID], of ids: [UUID]) -> Bool {
        order.count == ids.count && Set(order) == Set(ids)
    }

    /// Appends a library movement with the picker's set end and target. A second
    /// movement raises a one-round block to two rounds, the same rule the picker
    /// has always applied. Returns false when the block is gone.
    @discardableResult
    func appendMovement(
        _ movement: Movement,
        toBlock blockID: UUID,
        condition: EndCondition,
        target: Int?
    ) -> Bool {
        appendMovements(
            [MovementAddition(movement: movement, condition: condition, target: target)],
            toBlock: blockID
        )
    }

    /// Appends a batch of movements in the given order with one draft edit, so
    /// the picker's DONE commits once. The rounds rule runs against the final
    /// count: a block with fewer than two movements that reaches two rises to
    /// at least two rounds. Returns false for a missing block or an empty batch.
    @discardableResult
    func appendMovements(_ additions: [MovementAddition], toBlock blockID: UUID) -> Bool {
        guard !additions.isEmpty,
              let blockIndex = session.blocks.firstIndex(where: { $0.id == blockID })
        else { return false }
        let appended = additions.map {
            BlockMovement(
                movementId: $0.movement.id,
                endCondition: $0.condition,
                target: $0.target
            ).clamped()
        }
        edit { session in
            let before = session.blocks[blockIndex].movements.count
            session.blocks[blockIndex].movements.append(contentsOf: appended)
            if before < 2,
               session.blocks[blockIndex].movements.count >= 2,
               session.blocks[blockIndex].rounds < 2 {
                session.blocks[blockIndex].rounds = 2
            }
        }
        return true
    }

    /// Appends queued movements to the addressed block. A staged block keeps
    /// the rounds rule but never marks the draft dirty or schedules a save.
    @discardableResult
    func appendMovements(_ additions: [MovementAddition], to target: BlockEditingTarget) -> Bool {
        switch target {
        case .saved(let blockID):
            return appendMovements(additions, toBlock: blockID)
        case .staged:
            guard !additions.isEmpty, var block = stagedBlock else { return false }
            let before = block.movements.count
            block.movements.append(contentsOf: additions.map {
                BlockMovement(
                    movementId: $0.movement.id,
                    endCondition: $0.condition,
                    target: $0.target
                ).clamped()
            })
            if before < 2, block.movements.count >= 2, block.rounds < 2 {
                block.rounds = 2
            }
            stagedBlock = block
            return true
        }
    }

    /// Appends one block in a single draft edit. An empty movement list is
    /// rejected so the add-block flow cannot save an empty block; two or more
    /// movements raise the block to at least two rounds. Other blocks are left
    /// untouched.
    @discardableResult
    func appendBlock(_ block: WorkoutBlock) -> Bool {
        guard !block.movements.isEmpty else { return false }
        var appended = block
        appended.rounds = max(appended.rounds, 1)
        appended.setsPerRound = max(appended.setsPerRound, 1)
        appended.movements = appended.movements.map { $0.clamped() }
        if appended.movements.count > 1 {
            appended.rounds = max(appended.rounds, 2)
        }
        edit { $0.blocks.append(appended) }
        return true
    }

    @discardableResult
    func removeMovement(_ id: UUID, inBlock blockID: UUID) -> Bool {
        guard let blockIndex = session.blocks.firstIndex(where: { $0.id == blockID }),
              session.blocks[blockIndex].movements.count > 1,
              session.blocks[blockIndex].movements.contains(where: { $0.id == id })
        else { return false }
        edit { $0.blocks[blockIndex].movements.removeAll { $0.id == id } }
        return true
    }

    @discardableResult
    func removeMovement(_ id: UUID, in target: BlockEditingTarget) -> Bool {
        switch target {
        case .saved(let blockID):
            return removeMovement(id, inBlock: blockID)
        case .staged:
            guard var block = stagedBlock,
                  block.movements.count > 1,
                  block.movements.contains(where: { $0.id == id })
            else { return false }
            block.movements.removeAll { $0.id == id }
            stagedBlock = block
            return true
        }
    }

    /// Applies any pending edit now. Called on dismissal, Done, and background.
    /// A drag in progress keeps its edit dirty until `endDrag()`.
    func flush() {
        pending?.cancel()
        pending = nil
        guard !isDragging, isDirty else { return }
        isDirty = false
        commit?(session)
    }

    private func schedule() {
        pending?.cancel()
        pending = nil
        guard !isDragging else { return }
        let delay = delay
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
