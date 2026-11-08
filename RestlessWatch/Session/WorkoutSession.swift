import Foundation
import HealthKit

/// Keeps the watch app running while a set is armed. A workout session gives
/// the app background runtime, so the accelerometer and the WatchConnectivity
/// link keep working with the wrist down.
@MainActor
final class WorkoutSession: NSObject, HKWorkoutSessionDelegate {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var authorized = false

    var isRunning: Bool { session?.state == .running }

    /// Requests workout write access the first time. A denied request leaves
    /// counting to the foreground-only path.
    func start() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !authorized {
            do {
                let workoutType: HKSampleType = HKObjectType.workoutType()
                try await store.requestAuthorization(toShare: [workoutType], read: [])
                authorized = true
            } catch {
                emit("WORKOUT_AUTH_FAIL,\(error.localizedDescription)")
                return
            }
        }
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            session.delegate = self
            session.startActivity(with: .now)
            self.session = session
            emit("WORKOUT_START")
        } catch {
            emit("WORKOUT_START_FAIL,\(error.localizedDescription)")
        }
    }

    func stop() {
        guard let session else { return }
        session.end()
        self.session = nil
        emit("WORKOUT_STOP")
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        emit("WORKOUT_STATE,\(toState.rawValue)")
        if toState == .ended {
            Task { @MainActor in
                self.session = nil
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        emit("WORKOUT_FAIL,\(error.localizedDescription)")
        Task { @MainActor in
            self.session = nil
        }
    }

    private nonisolated func emit(_ line: String) {
        FileHandle.standardOutput.write(Data("\(line)\n".utf8))
    }
}
