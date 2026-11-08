import Foundation
import Testing
@testable import Restless

private let benchID = UUID()

@Test("Activity attributes carry the rounds plan and rebuild the same position")
func attributesRoundTrip() {
    let preset = WorkoutPreset(
        name: "Heavy",
        blocks: [
            WorkoutBlock(
                name: "Bench",
                rounds: 4,
                setsPerRound: 4,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: benchID, endCondition: .manual)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(preset)
    snapshot.startSession()
    snapshot.doneSets = 5

    let attributes = RestlessActivityAttributes(
        snapshot,
        movementNames: [benchID: "Bench press"]
    )
    let rebuilt = attributes.snapshot(RestlessActivityAttributes.ContentState(snapshot))

    #expect(attributes.totalSets == 16)
    #expect(attributes.preset == preset)
    #expect(rebuilt.preset == preset)
    #expect(rebuilt.position == snapshot.position)
    #expect(rebuilt.position.round == 2)
    #expect(rebuilt.position.set == 2)
    #expect(rebuilt.upcomingRest == snapshot.upcomingRest)
    #expect(attributes.movementName(benchID) == "BENCH PRESS")
}
