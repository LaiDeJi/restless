import CoreGraphics
import Foundation
import Testing
@testable import Restless

private func approx(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
    abs(lhs - rhs) < 0.001
}

private func mapBlock(rounds: Int, setsPerRound: Int, movements: Int) -> WorkoutBlock {
    WorkoutBlock(
        name: "Block",
        rounds: rounds,
        setsPerRound: setsPerRound,
        setRest: 60,
        roundRest: 120,
        movements: (0..<movements).map { _ in
            BlockMovement(movementId: UUID(), endCondition: .manual)
        }
    )
}

private func mapPreset(rounds: Int, setsPerRound: Int, movements: Int) -> WorkoutPreset {
    WorkoutPreset(
        name: "Map",
        blocks: [mapBlock(rounds: rounds, setsPerRound: setsPerRound, movements: movements)]
    )
}

private func layout(
    _ preset: WorkoutPreset,
    at index: Int,
    phase: SessionPhase = .ready
) -> SetMapLayout {
    SetMapLayout(block: preset.blocks[0], position: preset.position(at: index), phase: phase)
}

@Test("The ring centre is the same for a one-row and a three-row map")
func ringCentreIgnoresMapHeight() {
    let oneRow = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        actionsHeight: 62
    )
    let threeRows = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 120,
        actionsHeight: 62
    )

    #expect(approx(oneRow.heroCenterY, 400))
    #expect(approx(threeRows.heroCenterY, 400))
    #expect(approx(oneRow.mapTopY, threeRows.mapTopY))
}

@Test("A wrapping position strip stays above the ring and does not move it")
func wrappingPositionStripDoesNotMoveTheRing() {
    let singleLine = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        actionsHeight: 62
    )
    let twoLines = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 138,
        heroSide: 300,
        mapHeight: 40,
        actionsHeight: 62
    )

    #expect(approx(singleLine.heroCenterY, 400))
    #expect(approx(twoLines.heroCenterY, 400))
    #expect(twoLines.heroTopY >= twoLines.chromeHeight + TimerStageMetrics.chromeGap)
}

@Test("Actions follow the map at the fixed gap when the content overflows")
func actionsFollowTheMap() {
    let tall = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 600,
        actionsHeight: 62
    )
    let mapBottom = tall.mapTopY + tall.mapHeight

    #expect(approx(tall.actionsTopY, mapBottom + TimerStageMetrics.gap))
    #expect(approx(tall.totalHeight, tall.actionsTopY + 62))
    #expect(tall.totalHeight > 800)
}

@Test("Actions sit at the bottom when they fit")
func actionsSitAtTheBottom() {
    let short = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        actionsHeight: 62
    )
    #expect(approx(short.actionsTopY, 738))
    #expect(approx(short.totalHeight, 800))
}

@Test("A short viewport clamps the ring below the chrome")
func shortViewportClampsTheRing() {
    let metrics = TimerStageMetrics(
        viewportHeight: 360,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        actionsHeight: 62
    )

    #expect(approx(metrics.heroCenterY, 280))
    #expect(metrics.heroCenterY > 180)
    #expect(approx(metrics.heroTopY, 130))
    #expect(metrics.heroTopY >= metrics.chromeHeight + TimerStageMetrics.chromeGap)
    #expect(metrics.totalHeight > 360)
}

@Test("A 2 × 3 × 2 block draws six rows of two dots with a gap between movements")
func movementMajorMapRows() {
    let preset = mapPreset(rounds: 3, setsPerRound: 2, movements: 2)
    let map = layout(preset, at: 6, phase: .resting)

    #expect(map.usesDots)
    #expect(map.rows.count == 6)
    #expect(map.setsPerRow == 2)
    #expect(map.totalSets == 12)
    #expect(map.rows.map(\.movementIndex) == [0, 0, 0, 1, 1, 1])
    #expect(map.rows.map(\.round) == [1, 2, 3, 1, 2, 3])
    #expect(map.rows.map(\.firstSet) == [0, 2, 4, 6, 8, 10])
    #expect(map.rows.map(\.hasGapAbove) == [false, false, false, true, false, false])
}

@Test("The active map row follows the current movement and round")
func activeMapRowFollowsPosition() {
    let preset = mapPreset(rounds: 3, setsPerRound: 2, movements: 2)

    #expect(layout(preset, at: 0).activeRow == 0)
    #expect(layout(preset, at: 1).activeRow == 0)
    #expect(layout(preset, at: 5).activeRow == 2)
    #expect(layout(preset, at: 6, phase: .resting).activeRow == 3)
    #expect(layout(preset, at: 11).activeRow == 5)
    #expect(layout(preset, at: 11, phase: .done).activeRow == nil)
}

@Test("A single-movement block draws one row per round, unchanged")
func singleMovementMapUnchanged() {
    let preset = mapPreset(rounds: 4, setsPerRound: 4, movements: 1)
    let map = layout(preset, at: 5)

    #expect(map.usesDots)
    #expect(map.rows.count == 4)
    #expect(map.setsPerRow == 4)
    #expect(map.rows.map(\.round) == [1, 2, 3, 4])
    #expect(map.rows.map(\.firstSet) == [0, 4, 8, 12])
    #expect(map.rows.allSatisfy { !$0.hasGapAbove })
    #expect(map.activeRow == 1)
}

@Test("A block over the row, row-width, or dot cap falls back to the bar")
func mapCapsFallBackToBar() {
    let tall = mapPreset(rounds: 5, setsPerRound: 2, movements: 3)
    let tallMap = layout(tall, at: 0)
    #expect(!tallMap.usesDots)
    #expect(tallMap.rows.isEmpty)
    #expect(tallMap.activeRow == nil)

    let wide = mapPreset(rounds: 1, setsPerRound: 13, movements: 1)
    #expect(!layout(wide, at: 0).usesDots)

    let full = mapPreset(rounds: 3, setsPerRound: 12, movements: 2)
    #expect(layout(full, at: 0).usesDots)
    #expect(layout(full, at: 0).totalSets == 72)

    let over = mapPreset(rounds: 4, setsPerRound: 12, movements: 2)
    #expect(!layout(over, at: 0).usesDots)
}
