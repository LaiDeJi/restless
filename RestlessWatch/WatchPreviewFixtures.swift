#if DEBUG
import Foundation

/// Launch-argument fixtures for the watch simulator. They never ship in a
/// release build and never touch the phone.
enum WatchPreviewFixtures {
    static let movementID = UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!
    static let curlID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0FF")!
    static let largeMovementID = UUID(uuidString: "00000000-0000-0000-0000-00000000DEAD")!

    static func preset() -> WorkoutPreset {
        WorkoutPreset(
            name: "Chest",
            blocks: [
                WorkoutBlock(
                    name: "Chest",
                    rounds: 4,
                    setsPerRound: 4,
                    setRest: 60,
                    roundRest: 120,
                    movements: [
                        BlockMovement(movementId: movementID, endCondition: .manual)
                    ]
                )
            ]
        )
    }

    /// Two blocks: 16 sets then 8, so the block count and the session count
    /// differ. Five done in the first block reads 5 / 16 above and 5 OF 24 below.
    static func twoBlockPreset() -> WorkoutPreset {
        WorkoutPreset(
            name: "Chest + Arms",
            blocks: [
                WorkoutBlock(
                    name: "Chest",
                    rounds: 4,
                    setsPerRound: 4,
                    setRest: 60,
                    roundRest: 120,
                    movements: [
                        BlockMovement(movementId: movementID, endCondition: .manual)
                    ]
                ),
                WorkoutBlock(
                    name: "Arms",
                    rounds: 2,
                    setsPerRound: 4,
                    setRest: 60,
                    roundRest: 120,
                    movements: [
                        BlockMovement(movementId: curlID, endCondition: .manual)
                    ]
                )
            ]
        )
    }

    /// 40 rounds of 25 sets: 1000 sets in one block, on the same bar.
    static func largeBlockPreset() -> WorkoutPreset {
        WorkoutPreset(
            name: "Dead hang",
            blocks: [
                WorkoutBlock(
                    name: "Back",
                    rounds: 40,
                    setsPerRound: 25,
                    setRest: 60,
                    roundRest: 120,
                    movements: [
                        BlockMovement(movementId: largeMovementID, endCondition: .manual)
                    ]
                )
            ]
        )
    }

    /// `simctl launch <udid> com.whc.restless.watch -watch-phase setRest`
    static func payload(arguments: [String]) -> WatchSessionPayload? {
        guard let flag = arguments.firstIndex(of: "-watch-phase"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return payload(phase: arguments[flag + 1])
    }

    static func payload(phase: String) -> WatchSessionPayload? {
        let preset = preset()
        var snapshot = SessionSnapshot.initial(preset, now: .now)
        var names = [movementID: "Bench press"]

        switch phase {
        case "ready":
            break
        case "work":
            snapshot.doneSets = 5
            snapshot.phase = .performing
            snapshot.setDuration = 60
            snapshot.setDeadline = Date.now.addingTimeInterval(30)
        case "setRest":
            snapshot.doneSets = 5
            snapshot.phase = .resting
            snapshot.restKind = .set
            snapshot.duration = 60
            snapshot.pausedRemaining = 60
            snapshot.deadline = Date.now.addingTimeInterval(30)
        case "roundRest":
            snapshot.doneSets = 8
            snapshot.phase = .resting
            snapshot.restKind = .round
            snapshot.duration = 120
            snapshot.pausedRemaining = 120
            snapshot.deadline = Date.now.addingTimeInterval(60)
        case "paused":
            snapshot.doneSets = 5
            snapshot.phase = .paused
            snapshot.restKind = .set
            snapshot.duration = 60
            snapshot.pausedRemaining = 12
        case "expiredRest":
            snapshot.doneSets = 5
            snapshot.phase = .resting
            snapshot.restKind = .set
            snapshot.duration = 60
            snapshot.pausedRemaining = 60
            snapshot.deadline = Date.now.addingTimeInterval(-1)
        case "twoBlocks":
            snapshot = SessionSnapshot.initial(twoBlockPreset(), now: .now)
            snapshot.doneSets = 5
            snapshot.phase = .resting
            snapshot.restKind = .set
            snapshot.duration = 60
            snapshot.pausedRemaining = 60
            snapshot.deadline = Date.now.addingTimeInterval(30)
            names = [movementID: "Bench press", curlID: "Curl"]
        case "largeBlock":
            snapshot = SessionSnapshot.initial(largeBlockPreset(), now: .now)
            snapshot.doneSets = 250
            snapshot.phase = .resting
            snapshot.restKind = .round
            snapshot.duration = 120
            snapshot.pausedRemaining = 120
            snapshot.deadline = Date.now.addingTimeInterval(60)
            names = [largeMovementID: "Dead hang"]
        case "done":
            snapshot.doneSets = snapshot.totalSets
            snapshot.phase = .done
        default:
            return nil
        }

        return WatchSessionPayload(snapshot: snapshot, movementNames: names)
    }
}
#endif
