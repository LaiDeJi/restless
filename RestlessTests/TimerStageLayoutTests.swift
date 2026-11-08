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
        watchHeight: 0,
        actionsHeight: 62
    )
    let threeRows = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 120,
        watchHeight: 0,
        actionsHeight: 62
    )

    #expect(approx(oneRow.heroCenterY, 400))
    #expect(approx(threeRows.heroCenterY, 400))
    #expect(approx(oneRow.mapTopY, threeRows.mapTopY))
    #expect(threeRows.belowBottomY > oneRow.belowBottomY)
}

@Test("A wrapping position strip stays above the ring and does not move it")
func wrappingPositionStripDoesNotMoveTheRing() {
    let singleLine = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 0,
        actionsHeight: 62
    )
    let twoLines = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 138,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 0,
        actionsHeight: 62
    )

    #expect(approx(singleLine.heroCenterY, 400))
    #expect(approx(twoLines.heroCenterY, 400))
    #expect(twoLines.heroTopY >= twoLines.chromeHeight + TimerStageMetrics.chromeGap)
}

@Test("A watch strip appears below the map without moving the ring")
func watchStripSitsBelowTheMap() {
    let withoutWatch = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 0,
        actionsHeight: 62
    )
    let withWatch = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 36,
        actionsHeight: 62
    )

    #expect(approx(withoutWatch.heroCenterY, withWatch.heroCenterY))
    #expect(approx(withWatch.watchTopY, withoutWatch.belowBottomY + TimerStageMetrics.gap))
    #expect(withWatch.belowBottomY > withoutWatch.belowBottomY)
}

@Test("Actions sit at the bottom when they fit and below the map when they do not")
func actionsFollowTheContent() {
    let short = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 0,
        actionsHeight: 62
    )
    #expect(approx(short.actionsTopY, 738))
    #expect(approx(short.totalHeight, 800))

    let tall = TimerStageMetrics(
        viewportHeight: 800,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 600,
        watchHeight: 36,
        actionsHeight: 62
    )
    #expect(approx(tall.actionsTopY, tall.belowBottomY + TimerStageMetrics.gap))
    #expect(approx(tall.totalHeight, tall.actionsTopY + 62))
    #expect(tall.totalHeight > 800)
}

@Test("A short viewport clamps the ring below the chrome")
func shortViewportClampsTheRing() {
    let metrics = TimerStageMetrics(
        viewportHeight: 360,
        chromeHeight: 120,
        heroSide: 300,
        mapHeight: 40,
        watchHeight: 0,
        actionsHeight: 62
    )

    #expect(approx(metrics.heroCenterY, 280))
    #expect(metrics.heroCenterY > 180)
    #expect(approx(metrics.heroTopY, 130))
    #expect(metrics.heroTopY >= metrics.chromeHeight + TimerStageMetrics.chromeGap)
    #expect(metrics.totalHeight > 360)
}
