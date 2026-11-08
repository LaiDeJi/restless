import Foundation

/// Drives a stepper's press-and-hold loop: wait once, then step at the interval
/// until the step reports the range is exhausted or the caller stops it. A new
/// start cancels the previous run; a late finish cannot clear the new run.
@MainActor
final class StepRepeater {
    private(set) var isRunning = false

    private let initialDelay: Duration
    private let interval: Duration
    private var task: Task<Void, Never>?
    private var generation = 0

    init(
        initialDelay: Duration = .milliseconds(500),
        interval: Duration = .milliseconds(100)
    ) {
        self.initialDelay = initialDelay
        self.interval = interval
    }

    func start(_ step: @escaping @MainActor () -> Bool) {
        stop()
        generation += 1
        let token = generation
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.finish(token) }
            guard await self.wait(self.initialDelay) else { return }
            while !Task.isCancelled {
                guard step() else { return }
                guard await self.wait(self.interval) else { return }
            }
        }
    }

    func stop() {
        generation += 1
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func wait(_ duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return true
        } catch {
            return false
        }
    }

    private func finish(_ token: Int) {
        guard token == generation else { return }
        isRunning = false
        task = nil
    }
}
