# Design

## Context

The alert scheduler owns the only `UNUserNotificationCenterDelegate` in the app. `CountdownNotificationDelegate` is a plain `NSObject` whose `willPresent` and `didReceive` methods are `nonisolated` async methods. On the physical iPhone (iOS 27.3) the tapped response reaches `didReceive` on `com.apple.root.user-initiated-qos.cooperative`, and UIKit then runs its background snapshot and state-restoration work from that same frame; `-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]` raises its main-thread assertion and the process aborts. Five device crash reports from Nov 9 and Nov 10 share that stack, including the one written at 21:00 today.

The app is Swift 6 with strict concurrency. `RootView` observes `.countdownAlertOpened` and calls `router.showTimer()` plus `engine.refreshFromStore()`; both are main-actor work. The notification path must join that actor rather than hand UIKit a background thread.

## Goals / Non-Goals

**Goals:**

- The tapped response and everything UIKit does after it run on the main thread.
- The tap only shows the TIMER tab and reconciles the stored session; it never performs a session transition.
- The identifier check (current prefix plus the legacy id) stays testable without `UserNotifications`.

**Non-Goals:**

- Changing alert timing, copy, delivery, or Live Activity behaviour.
- Changing the foreground haptic path or the background scheduling rules.
- Fixing the unrelated simulator watchdog reports that also exist for this app.

## Decisions

**Use the completion-handler delegate methods, hop once, and complete on the main actor.** The delegate implements `userNotificationCenter(_:didReceive:withCompletionHandler:)` and `willPresent` with completion handlers instead of the async variants. `didReceive` reads the identifier, and when it names a countdown alert it dispatches to the main actor, posts `.countdownAlertOpened`, and calls the completion handler there. Completing on the main actor is the part that matters: UIKit continues the response on the thread that calls the handler, so its snapshot and state-restoration work no longer runs on a cooperative queue. The async variants were rejected because their resume thread is chosen by Swift concurrency for a non-isolated class, which is what surfaced the bug. Marking the delegate `@MainActor` alone was rejected because the Objective-C protocol is not main-actor annotated; the witness still has to be `nonisolated` and the post-callback UIKit work would still follow the caller's thread.

**Do the response work before completing.** `showTimer` and `refreshFromStore` are synchronous main-actor calls; the Live Activity refresh they trigger is fire-and-forget. Reading the identifier and posting the notification is cheap, so completing immediately afterwards does not delay the system's response handling or hang the notification service.

**Keep the response decision as a small pure check.** The identifier-to-action decision (`is countdown alert` vs `ignore`) moves into a non-UI helper, so a unit test can cover the prefix, the legacy identifier, and a foreign identifier without presenting a notification.

## Risks / Trade-offs

- **The completion handler is called from a different thread than the delegate method** → UIKit explicitly resumes from the handler's thread; device verification of a tapped alert must show no abort, otherwise fall back to an explicit `DispatchQueue.main.async` completion.
- **The engine reconciles before the completion handler runs** → the timer may show the next set a moment before the system finishes the response. This is the same order the app already used and does not change the session.
- **A missed completion handler would stall notification handling** → the handler is called on every path, including ignored identifiers; no early return leaves it uncalled.
- **Unit tests cannot reproduce the device assertion** → the test covers the routing decision only; the device run is the acceptance check for the main-thread contract.

## Migration Plan

No persisted data, URL, or API changes. The fix ships in the app binary; rolling back restores the crashing delegate, so no data rollback is needed.
