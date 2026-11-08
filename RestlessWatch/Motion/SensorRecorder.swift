import CoreMotion
import Foundation

/// Background accelerometer capture. `CMSensorRecorder` keeps recording at
/// 50 Hz while the app is suspended, so putting the wrist down no longer cuts
/// the recording short. The samples are fetched after the window ends.
final class SensorRecorder: @unchecked Sendable {
    private let recorder = CMSensorRecorder()
    private let queue = DispatchQueue(label: "com.whc.restless.sensor-recorder")

    var isAvailable: Bool {
        CMSensorRecorder.isAccelerometerRecordingAvailable()
    }

    var isAuthorized: Bool {
        CMSensorRecorder.authorizationStatus() == .authorized
    }

    /// True when the watch can record in the background and the user has not
    /// denied motion access. `.notDetermined` is allowed: the first start asks.
    var canRecord: Bool {
        guard CMSensorRecorder.isAccelerometerRecordingAvailable() else { return false }
        switch CMSensorRecorder.authorizationStatus() {
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

    func start(duration: TimeInterval) {
        queue.async { [weak self] in
            self?.recorder.recordAccelerometer(forDuration: duration)
        }
    }

    /// Samples in `(from, to]`. The system may need a few seconds (up to a few
    /// minutes) before the batch is readable, so callers retry.
    func samples(from: Date, to: Date) async -> [MotionTraceSample] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self,
                      let list = self.recorder.accelerometerData(from: from, to: to) else {
                    continuation.resume(returning: [])
                    return
                }

                let duration = to.timeIntervalSince(from)
                var samples: [MotionTraceSample] = []
                var iterator = NSFastEnumerationIterator(list)
                while let data = iterator.next() as? CMRecordedAccelerometerData {
                    let time = data.startDate.timeIntervalSince(from)
                    guard time >= 0, time <= duration else { continue }
                    samples.append(
                        MotionTraceSample(
                            time: time,
                            gravityX: data.acceleration.x,
                            gravityY: data.acceleration.y,
                            gravityZ: data.acceleration.z
                        )
                    )
                }
                samples.sort { $0.time < $1.time }
                continuation.resume(returning: samples)
            }
        }
    }
}
