import Foundation

/// One completion alert's words. The phone haptic and the local notification
/// both use this one pair, so no surface can drift from another.
struct CompletionAlert: Equatable, Sendable {
    let title: String
    let body: String
}

/// Pure copy for a rest or timed work countdown that reached zero. It reads the
/// post-transition snapshot, so the body can name the next set, round, movement,
/// or block.
enum CompletionAlertCopy {
    /// The alert the current countdown will raise, or nil when no countdown is
    /// running. Used when scheduling the local notification before the deadline.
    static func pending(
        for snapshot: SessionSnapshot,
        movementNames: [UUID: String] = [:]
    ) -> CompletionAlert? {
        var after = snapshot
        switch snapshot.phase {
        case .resting:
            after.finishRest()
            return restFinished(after, movementNames: movementNames)
        case .performing:
            after.setDone()
            return workFinished(after, movementNames: movementNames)
        case .notStarted, .ready, .paused, .done:
            return nil
        }
    }

    /// A rest that just reached zero. `snapshot` is already ready at the next set.
    static func restFinished(
        _ snapshot: SessionSnapshot,
        movementNames: [UUID: String] = [:]
    ) -> CompletionAlert {
        let rest = snapshot.doneSets > 0
            ? snapshot.preset.rest(after: snapshot.doneSets - 1)
            : nil
        let title = rest?.kind == .round ? "ROUND REST OVER" : "SET REST OVER"
        let finished = snapshot.preset.position(at: max(snapshot.doneSets - 1, 0))
        let context = finishedContext(
            rest?.transition ?? .set,
            at: finished,
            preset: snapshot.preset,
            movementNames: movementNames
        )
        // A movement switch or block transition already names what comes next.
        let contextNamesNext = rest?.transition == .movement || rest?.transition == .block
        return CompletionAlert(
            title: title,
            body: [context, nextSetCopy(
                snapshot,
                movementNames: movementNames,
                includeMovement: !contextNamesNext
            )]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        )
    }

    /// A timed work set that just reached zero. `snapshot` is already resting,
    /// ready after a zero rest, or done when this was the final set.
    static func workFinished(
        _ snapshot: SessionSnapshot,
        movementNames: [UUID: String] = [:]
    ) -> CompletionAlert {
        guard snapshot.phase != .done else {
            return CompletionAlert(title: "SESSION COMPLETE", body: completedBody(snapshot))
        }
        let finished = snapshot.preset.position(at: max(snapshot.doneSets - 1, 0))
        // The rest this set started, not the one after the next set.
        let rest = snapshot.preset.rest(after: max(snapshot.doneSets - 1, 0))
        var body: String
        if let rest {
            if rest.isZero {
                body = "NEXT SET IMMEDIATELY"
            } else {
                body = "REST \(durationString(rest.duration)) AFTER"
            }
            body += workNextContext(
                rest,
                at: finished,
                preset: snapshot.preset,
                position: snapshot.position,
                movementNames: movementNames
            )
        } else {
            body = "NO REST AFTER"
        }
        return CompletionAlert(title: "WORK SET OVER", body: body)
    }

    // MARK: - Pieces

    private static func finishedContext(
        _ transition: RestTransition,
        at position: WorkoutPosition,
        preset: WorkoutPreset,
        movementNames: [UUID: String]
    ) -> String {
        switch transition {
        case .set:
            return "AFTER SET \(position.set)"
        case .round:
            return "AFTER ROUND \(position.round)"
        case .movement:
            let block = block(at: position.blockIndex, in: preset)
            let nextIndex = position.movementIndex + 1
            let next = block.movements.indices.contains(nextIndex)
                ? name(block.movements[nextIndex].movementId, movementNames)
                : name(position.movementId, movementNames)
            return "AFTER \(name(position.movementId, movementNames)) · NEXT \(next)"
        case .block:
            let nextIndex = position.blockIndex + 1
            let nextBlock = preset.blocks.indices.contains(nextIndex)
                ? preset.blocks[nextIndex].name.uppercased()
                : preset.name.uppercased()
            return "AFTER \(block(at: position.blockIndex, in: preset).name.uppercased()) · NEXT \(nextBlock)"
        }
    }

    /// `NEXT ROUND 2 OF 4 · NEXT SET 1 OF 4`, or `NEXT BENCH PRESS` when neither
    /// round nor set changes.
    private static func nextSetCopy(
        _ snapshot: SessionSnapshot,
        movementNames: [UUID: String],
        includeMovement: Bool = true
    ) -> String {
        let position = snapshot.position
        let block = snapshot.currentBlock
        let copy = position.roundSetCopy(in: block)
        var parts: [String] = []
        if copy.roundText != nil {
            parts.append("NEXT ROUND \(position.round) OF \(copy.rounds)")
        }
        if copy.setText != nil {
            parts.append("NEXT SET \(position.set) OF \(copy.setsPerRound)")
        }
        if parts.isEmpty, includeMovement {
            parts.append("NEXT \(name(position.movementId, movementNames))")
        }
        return parts.joined(separator: " · ")
    }

    /// What a timed set's rest leads into, when that is more than the rest itself.
    private static func workNextContext(
        _ rest: RestOption,
        at finished: WorkoutPosition,
        preset: WorkoutPreset,
        position: WorkoutPosition,
        movementNames: [UUID: String]
    ) -> String {
        switch rest.transition {
        case .set:
            return ""
        case .movement:
            let block = block(at: finished.blockIndex, in: preset)
            let nextIndex = finished.movementIndex + 1
            let next = block.movements.indices.contains(nextIndex)
                ? name(block.movements[nextIndex].movementId, movementNames)
                : name(position.movementId, movementNames)
            return " · NEXT \(next)"
        case .block:
            let nextIndex = finished.blockIndex + 1
            let nextBlock = preset.blocks.indices.contains(nextIndex)
                ? preset.blocks[nextIndex].name.uppercased()
                : preset.name.uppercased()
            return " · NEXT \(nextBlock)"
        case .round:
            return " · NEXT ROUND \(position.round) OF \(max(snapshotRoundCount(preset, position), 1))"
        }
    }

    private static func snapshotRoundCount(_ preset: WorkoutPreset, _ position: WorkoutPosition) -> Int {
        block(at: position.blockIndex, in: preset).rounds
    }

    private static func completedBody(_ snapshot: SessionSnapshot) -> String {
        let sets = "\(snapshot.doneSets) OF \(plural(snapshot.totalSets, "SET", "SETS"))"
        let blocks = plural(snapshot.preset.blocks.count, "BLOCK", "BLOCKS")
        return "\(sets) · \(blocks) · \(durationString(snapshot.preset.totalRest)) TOTAL REST"
    }

    private static func block(at index: Int, in preset: WorkoutPreset) -> WorkoutBlock {
        guard preset.blocks.indices.contains(index) else { return .fallback }
        return preset.blocks[index]
    }

    private static func name(_ id: UUID, _ names: [UUID: String]) -> String {
        (names[id] ?? "MOVEMENT").uppercased()
    }
}
