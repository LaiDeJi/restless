import Foundation
import Testing
@testable import Restless

private let deadline = Date(timeIntervalSince1970: 1_000)

@Test("A current countdown identifier asks for the timer")
func currentCountdownIdentifierShowsTimer() {
    let identifier = SystemCountdownAlertScheduler.identifier(for: deadline)

    #expect(CountdownAlertTap(identifier: identifier) == .showTimer)
}

@Test("The legacy countdown identifier asks for the timer")
func legacyCountdownIdentifierShowsTimer() {
    #expect(CountdownAlertTap(identifier: SystemCountdownAlertScheduler.legacyNotificationID) == .showTimer)
}

@Test("A foreign identifier is ignored")
func foreignIdentifierIsIgnored() {
    #expect(CountdownAlertTap(identifier: "com.apple.mobiletimer.alarm") == .ignore)
    #expect(CountdownAlertTap(identifier: "") == .ignore)
}

@Test("A countdown tap shows the timer and names no session action")
func countdownTapShowsTimerOnly() {
    let tap = CountdownAlertTap(identifier: SystemCountdownAlertScheduler.identifier(for: deadline))

    // The decision has exactly two cases, neither of which is a SessionAction:
    // a tap only drives RootView's router.showTimer() and refreshFromStore().
    // A new case fails this exhaustive switch, so the tap cannot quietly start
    // completing sets or skipping rests.
    switch tap {
    case .showTimer:
        break
    case .ignore:
        Issue.record("A countdown alert must open the timer")
    }
}
