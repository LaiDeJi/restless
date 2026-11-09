import Foundation
import UserNotifications

/// The pending countdown alerts. A fake implementation lets the alert state
/// machine be tested without a notification center.
@MainActor
protocol CountdownAlertScheduler: AnyObject {
    /// Asks for notification permission once.
    func requestAuthorizationIfNeeded() async
    /// Adds or replaces the one alert for `deadline`. Alerts for other
    /// deadlines stay pending.
    func schedule(deadline: Date, alert: CompletionAlert) async
    /// Removes every pending countdown alert. Safe when nothing is pending.
    func cancel() async
    /// Removes only the alert for `deadline`, for a stale schedule.
    func cancel(deadline: Date) async
    /// Clears alerts that are already delivered, after the user opens the app.
    func stopAlerting() async
}

extension Notification.Name {
    /// Posted when the user taps the countdown notification. RootView shows
    /// TIMER; the deadline was already reconciled by the session.
    static let countdownAlertOpened = Notification.Name("restless.countdownAlertOpened")
}

/// A scheduler that does nothing: the engine's default outside the app so unit
/// tests never present a permission prompt or schedule a real alert.
@MainActor
final class NoopCountdownAlertScheduler: CountdownAlertScheduler {
    func requestAuthorizationIfNeeded() async {}
    func schedule(deadline: Date, alert: CompletionAlert) async {}
    func cancel() async {}
    func cancel(deadline: Date) async {}
    func stopAlerting() async {}
}

/// One local notification per countdown deadline. It is the only background
/// alert: the app schedules it before it leaves the foreground, and the system
/// delivers it at the deadline whether the app is still executing or suspended.
/// iOS mirrors it to the paired watch, so no watch message is needed.
@MainActor
final class SystemCountdownAlertScheduler: CountdownAlertScheduler {
    nonisolated static let notificationPrefix = "restless.countdown-alert."
    nonisolated static let legacyNotificationID = "restless-countdown-alert"

    private let notificationCenter = UNUserNotificationCenter.current()
    private let delegate = CountdownNotificationDelegate()
    private var requestedAuthorization = false

    init() {
        notificationCenter.delegate = delegate
    }

    func requestAuthorizationIfNeeded() async {
        guard !requestedAuthorization else { return }
        requestedAuthorization = true

        let settings = await notificationCenter.notificationSettings()
        print("RESTLESSDBG auth start notification=\(settings.authorizationStatus.rawValue)")
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
            print("RESTLESSDBG notification prompt granted=\(granted)")
        }
    }

    func schedule(deadline: Date, alert: CompletionAlert) async {
        let settings = await notificationCenter.notificationSettings()
        print("RESTLESSDBG schedule via notification auth=\(settings.authorizationStatus.rawValue), deadline in \(deadline.timeIntervalSinceNow)s")

        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        let interval = max(1, deadline.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: deadline),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await notificationCenter.add(request)
    }

    func cancel() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        var identifiers = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.notificationPrefix)
        }
        identifiers.append(Self.legacyNotificationID)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancel(deadline: Date) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: deadline)]
        )
    }

    func stopAlerting() async {
        let delivered = await notificationCenter.deliveredNotifications()
        var identifiers = delivered.map(\.request.identifier).filter {
            $0.hasPrefix(Self.notificationPrefix)
        }
        identifiers.append(Self.legacyNotificationID)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    nonisolated static func identifier(for deadline: Date) -> String {
        notificationPrefix + String(Int((deadline.timeIntervalSince1970 * 1_000).rounded()))
    }
}

/// Suppresses the foreground banner (the haptic already fired) and routes a
/// tapped notification to the timer.
private final class CountdownNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        let isCountdown = identifier.hasPrefix(SystemCountdownAlertScheduler.notificationPrefix)
            || identifier == SystemCountdownAlertScheduler.legacyNotificationID
        guard isCountdown else { return }
        Task { @MainActor in
            NotificationCenter.default.post(name: .countdownAlertOpened, object: nil)
        }
    }
}
