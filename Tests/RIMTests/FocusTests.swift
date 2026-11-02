import Foundation
import Testing
@testable import RIM

@MainActor @Suite struct FocusTests {
    @Test func timeFormat() {
        #expect(FocusModel.format(0) == "0:00")
        #expect(FocusModel.format(59.2) == "1:00")  // rounds up so the display never shows 0:00 early
        #expect(FocusModel.format(25 * 60) == "25:00")
        #expect(FocusModel.format(61) == "1:01")
    }

    @Test func countdownRunsAndFinishes() async throws {
        let focus = FocusModel()
        var finished = false
        focus.onFinish = { finished = true }
        focus.setSeconds(1)
        #expect(!focus.isRunning)

        focus.start()
        #expect(focus.isRunning)
        #expect(focus.isActive)

        for _ in 0..<50 where !focus.completed { try await Task.sleep(nanoseconds: 100_000_000) }
        #expect(focus.completed)
        #expect(finished)
        #expect(!focus.isRunning)
        #expect(focus.remaining == 0)
    }

    @Test func pauseKeepsRemainingTimeAndResetRestoresIt() {
        let focus = FocusModel()
        focus.setMinutes(10)
        focus.start()
        focus.pause()
        #expect(!focus.isRunning)
        #expect(focus.remaining <= 600 && focus.remaining > 590)

        focus.reset()
        #expect(focus.remaining == 600)
        #expect(!focus.isActive)
    }

    @Test func durationIsClamped() {
        let focus = FocusModel()
        focus.setMinutes(0)
        #expect(focus.duration == 60)
        focus.setMinutes(999)
        #expect(focus.duration == 180 * 60)
    }
}
