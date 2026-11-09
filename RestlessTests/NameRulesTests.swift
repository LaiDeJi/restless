import Foundation
import Testing
@testable import Restless

private let forty = String(repeating: "a", count: 40)

@Test("The name limit is 40 characters")
func nameLimitIsForty() {
    #expect(WorkoutPreset.bounds.nameLimit == 40)
    #expect(NameRules.limit == 40)
}

@Test("A forty-character name is kept whole at save")
func fortyCharactersSurviveSave() {
    #expect(NameRules.session(forty) == forty)
    #expect(NameRules.block(forty) == forty)
    #expect(NameRules.movement(forty) == forty)
    #expect(WorkoutPreset.clampedName(forty, fallback: "Untitled") == forty)
}

@Test("A fifty-character name is capped at forty")
func longNameIsCapped() {
    let fifty = String(repeating: "b", count: 50)
    #expect(NameRules.session(fifty).count == 40)
    #expect(NameRules.live(fifty).count == 40)
    #expect(WorkoutPreset.clampedName(fifty, fallback: "Untitled").count == 40)
}

@Test("Surrounding spaces are trimmed")
func namesAreTrimmed() {
    #expect(NameRules.session("  Chest  ") == "Chest")
    #expect(NameRules.block("  Chest  ") == "Chest")
    #expect(NameRules.movement("  Curl  ") == "Curl")
}

@Test("An empty name takes its fallback")
func emptyNameFallsBack() {
    #expect(NameRules.session("   ") == "Untitled")
    #expect(NameRules.block("") == "Untitled block")
    #expect(NameRules.movement("\n\t") == "Untitled movement")
}

@Test("Pasted newlines and tabs flatten to spaces")
func pastedNewlinesFlatten() {
    #expect(NameRules.live("Bench\nPress") == "Bench Press")
    #expect(NameRules.live("Bench\tPress") == "Bench Press")
    #expect(NameRules.session("Bench\r\nPress") == "Bench Press")
    #expect(WorkoutPreset.clampedName("Bench\nPress", fallback: "Untitled") == "Bench Press")
}

@Test("The live cap keeps a trailing space so words can be typed")
func liveCapKeepsTypingSpace() {
    #expect(NameRules.live("Bench ") == "Bench ")
    #expect(NameRules.session("Bench ") == "Bench")
}

@Test("A unique suffix stays inside the forty-character cap")
func uniqueSuffixStaysCapped() {
    let base = String(repeating: "c", count: 40)
    let unique = NameRules.uniqueName(base, used: [base])
    #expect(unique.count <= 40)
    #expect(unique != base)
    #expect(unique.hasSuffix(" 2"))
}
