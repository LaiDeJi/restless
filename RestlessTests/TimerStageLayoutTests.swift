import CoreGraphics
import Testing
@testable import Restless

private func approx(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
    abs(lhs - rhs) < 0.001
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
