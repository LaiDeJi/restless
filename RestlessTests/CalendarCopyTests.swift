import Testing
@testable import Restless

@Test("The zero gap keeps the every-day summary")
func gapSummaryZero() {
    #expect(CalendarCopy.gapSummary(0) == "SESSIONS EVERY DAY")
    #expect(CalendarCopy.restGapRowValue == "BETWEEN ROUNDS")
}

@Test("One rest day reads between rounds")
func gapSummaryOne() {
    #expect(CalendarCopy.gapSummary(1) == "1 REST DAY BETWEEN ROUNDS")
}

@Test("Several rest days read between rounds")
func gapSummarySeveral() {
    #expect(CalendarCopy.gapSummary(2) == "2 REST DAYS BETWEEN ROUNDS")
    #expect(CalendarCopy.gapSummary(6) == "6 REST DAYS BETWEEN ROUNDS")
}
