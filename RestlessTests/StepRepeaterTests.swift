import Foundation
import Testing
@testable import Restless

@MainActor
@Test("A repeat fires after the initial delay and then every interval")
func stepRepeaterFirstFireAndRepeat() async throws {
    let repeater = StepRepeater(initialDelay: .milliseconds(60), interval: .milliseconds(20))
    var count = 0

    repeater.start {
        count += 1
        return true
    }

    try await Task.sleep(for: .milliseconds(30))
    #expect(count == 0)

    try await Task.sleep(for: .milliseconds(50))
    #expect(count >= 1)

    try await Task.sleep(for: .milliseconds(70))
    #expect(count >= 3)

    repeater.stop()
}

@MainActor
@Test("A quick release before the initial delay fires no repeat")
func stepRepeaterQuickRelease() async throws {
    let repeater = StepRepeater(initialDelay: .milliseconds(80), interval: .milliseconds(10))
    var count = 0

    repeater.start {
        count += 1
        return true
    }

    try await Task.sleep(for: .milliseconds(20))
    repeater.stop()
    try await Task.sleep(for: .milliseconds(100))

    #expect(count == 0)
    #expect(!repeater.isRunning)
}

@MainActor
@Test("Stopping a repeat prevents every later step")
func stepRepeaterStop() async throws {
    let repeater = StepRepeater(initialDelay: .milliseconds(20), interval: .milliseconds(10))
    var count = 0

    repeater.start {
        count += 1
        return true
    }

    try await Task.sleep(for: .milliseconds(75))
    repeater.stop()
    let stopped = count
    #expect(stopped >= 2)

    try await Task.sleep(for: .milliseconds(60))
    #expect(count == stopped)
    #expect(!repeater.isRunning)
}

@MainActor
@Test("A step that reports the range bound stops the loop")
func stepRepeaterStopsAtLimit() async throws {
    let repeater = StepRepeater(initialDelay: .milliseconds(20), interval: .milliseconds(10))
    var value = 0

    repeater.start {
        value += 1
        return value < 3
    }

    try await Task.sleep(for: .milliseconds(120))

    #expect(value == 3)
    #expect(!repeater.isRunning)
}

@MainActor
@Test("A new press cancels the previous repeat")
func stepRepeaterRestartCancelsOldRun() async throws {
    let repeater = StepRepeater(initialDelay: .milliseconds(20), interval: .milliseconds(10))
    var first = 0
    var second = 0

    repeater.start {
        first += 1
        return true
    }
    try await Task.sleep(for: .milliseconds(25))

    repeater.start {
        second += 1
        return true
    }
    let firstStopped = first
    try await Task.sleep(for: .milliseconds(80))
    repeater.stop()

    #expect(firstStopped >= 1)
    #expect(first == firstStopped)
    #expect(second >= 2)
}
