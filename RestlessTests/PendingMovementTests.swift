import Foundation
import Testing
@testable import Restless

@Test("A queued name is trimmed and capped")
func queueNameTrimsAndCaps() {
    var list = PendingMovementList()

    let queued = list.queue(name: "  Cable Fly  ", condition: .manual, target: nil)
    #expect(queued)
    #expect(list.items.map(\.name) == ["Cable Fly"])

    let longQueued = list.queue(
        name: "  A movement name that is far too long for the cap  ",
        condition: .time,
        target: 60
    )
    #expect(longQueued)
    #expect(list.items[1].name == "A movement name that is far too long for")
}

@Test("An empty name is not queued")
func queueRejectsEmptyName() {
    var list = PendingMovementList()

    let queued = list.queue(name: "   ", condition: .manual, target: nil)
    #expect(!queued)
    #expect(list.isEmpty)
}

@Test("A duplicate name is rejected ignoring case")
func queueRejectsDuplicateName() {
    var list = PendingMovementList()

    let first = list.queue(name: "Cable Fly", condition: .manual, target: nil)
    let duplicate = list.queue(name: "cable fly", condition: .reps, target: 10)
    #expect(first)
    #expect(!duplicate)
    #expect(list.count == 1)
}

@Test("Toggling a library movement queues then removes it")
func toggleLibraryMovement() {
    let movement = Movement(name: "Bench Press")
    var list = PendingMovementList()

    list.toggle(movement, condition: .reps, target: 10)
    #expect(list.count == 1)
    #expect(list.contains(movementID: movement.id))
    #expect(list.items[0].condition == .reps)
    #expect(list.items[0].target == 10)

    list.toggle(movement, condition: .manual, target: nil)
    #expect(list.isEmpty)
}

@Test("A library movement is not queued twice under the same name")
func toggleRejectsDuplicateName() {
    let movement = Movement(name: "Bench Press")
    var list = PendingMovementList()

    let queued = list.queue(name: "bench press", condition: .manual, target: nil)
    #expect(queued)
    list.toggle(movement, condition: .reps, target: 10)
    #expect(list.count == 1)
    #expect(list.items[0].movementID == nil)
}

@Test("Removing a pending movement keeps the rest in order")
func removeKeepsOrder() {
    var list = PendingMovementList()
    list.queue(name: "Cable Fly", condition: .manual, target: nil)
    list.queue(name: "Bench Press", condition: .reps, target: 10)
    list.queue(name: "Curl", condition: .time, target: 45)
    let removed = list.items[1].id

    list.remove(removed)
    #expect(list.items.map(\.name) == ["Cable Fly", "Curl"])
}

@Test("A manual queued movement carries no target")
func manualCarriesNoTarget() {
    var list = PendingMovementList()

    list.queue(name: "Cable Fly", condition: .manual, target: 10)
    #expect(list.items[0].target == nil)

    list.queue(name: "Plank", condition: .time, target: 10)
    #expect(list.items[1].target == 15)
}
