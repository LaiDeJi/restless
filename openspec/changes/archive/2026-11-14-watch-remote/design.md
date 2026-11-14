# Design

## Context

See `proposal.md` — Why. The constraints that decide this design:

- `SessionSnapshot` is Codable, pure and deadline-based, and every mutation is a `SessionTransition` applied with an explicit `now`. `SessionEngine.handle(_ url:)` already accepts an action from outside the app.
- The phone owns everything with a clock in it: the ticker, the Live Activity and the local notification. Neither the widget nor the watch can read the phone's storage — App Groups are not configured, and a watch is a separate device regardless.
- watchOS suspends an app when the wrist drops. Background execution needs an extended runtime session or a HealthKit workout session, and the system decides what the Always On display keeps showing.
- Apple documents `sendMessage` from an active watch app as waking the paired iOS app in the background and making it reachable. Delivery is best effort: a force-quit phone, a relaunching app or an out-of-range watch makes it fail.
- The old watch app was removed because rep counting needed sensors, a profile model and a second path to end a set. None of those return here.

## Goals / Non-Goals

**Goals:**

- A wrist tap produces exactly the transition the phone's button would, with the deadline it would have had.
- The wrist screen is never wrong when it is looked at.
- One state authority, one action path, no new persistence.

**Non-Goals:**

- A countdown, timer, progress ring or any other time-derived value on the wrist.
- A standalone watch session, complication or Smart Stack widget.
- Editing, restart confirmation, or plan selection on the wrist.
- HealthKit, workout sessions, extended runtime sessions, notification permissions on the watch.

## Decisions

### WatchConnectivity, `sendMessage` for taps

The watch sends one message per tap. This is the only documented way for a watch app to make the phone app runnable from the background, and it fails fast when it cannot, which the wrist can report.

Alternatives: App Groups — impossible across devices, and unconfigured here. A server with push — new infrastructure for a local action. `transferUserInfo` — ordered and queued, but delivery waits for the next app launch, which is minutes too late for a rest.

### The tap carries its own instant

An action message is `{ action, tapTime, id }`. The phone applies it with `now = tapTime`, then reconciles to the present. A three-second delivery delay therefore produces the same deadline as an immediate one, and a message that arrives after a rest would have ended reconciles into the correct phase rather than replaying a stale one.

This is why the existing `now`-taking transitions make the feature cheap: the state model already separates "when it happened" from "when I heard about it".

The engine gains `perform(_:at:)`; the button, the island link and the URL handler keep calling it with `.now`.

### State is published, never synced

The phone writes the snapshot, the active plan and the movement names into the WatchConnectivity application context after every session change. The watch reads `receivedApplicationContext` on launch and on every delivery, so opening the wrist app never needs a round trip.

Alternatives: `sendMessage` from the phone — it does not wake the watch extension, so it would fail exactly when the wrist is down. `transferUserInfo` — a growing queue for a value that is always replaceable.

### The watch renders, it does not decide

The watch applies no transition. It may reconcile a published deadline to choose which published phase to show after a suspension, but that result is display-only and is never sent back.

Alternatives: a full local replica applying the same transitions — two clocks, two sequences to reconcile, and a divergence bug that only appears when the phone is unreachable.

### No background runtime

Without a clock on the wrist, there is nothing to keep alive: every screen is a function of the last published snapshot, and a wrist raise restores it in the same instant. Extended runtime and workout sessions are rejected because they exist to keep a running countdown visible, which is the thing this design removes.

### The start gate ships with the plan

The published context carries the active plan, so the wrist can offer START SESSION before the phone has ever started the session. Without it the watch would be dead on first use.

### Shared is split, not shared wholesale

`Shared/` currently compiles into the widget because the widget needs the preset, the snapshot and the palette. ActivityKit does not exist on watchOS, so the watch target compiles `WorkoutPreset`, `WorkoutBlock`, `SessionSnapshot`, `Theme` and the new message types, and excludes `RestlessActivity`. The palette and the button copy then come from the same file as the phone's, which is what keeps the wrist from inventing words.

### The notification gains no actions

At the moment the rest ends, the phase is ready and there is nothing meaningful to press; a background action would fire the wrong transition. The existing notification keeps its copy and gains only the default tap, which opens whichever app is on the device that delivered it.

## Risks / Trade-offs

- **A tap that cannot be delivered is lost.** No queue, by design: a queued SET DONE would land minutes later against the wrong phase. The wrist shows NOT SENT and the user taps again. → The send error handler updates one piece of screen state.
- **A force-quit phone cannot be woken.** → Same NOT SENT state; nothing is promised otherwise.
- **The documented background wake may behave differently on a released build.** → Verify on the physical watch before the screen is built, the same way App Groups were checked rather than assumed.
- **A second bundle identifier must be provisioned by the same team.** → Build an empty watch target first; if provisioning fails, the change stops there and nothing else is written.
- **Clock skew between devices shifts a deadline.** → Reject a `tapTime` more than a few seconds in the future and fall back to arrival time.
- **The watch app can be opened from the notification long after the rest ended.** → The screen renders the published phase, so it shows the next set, never the expired rest.

## Migration Plan

No stored data changes: the watch starts with an empty context and asks for the phone. Removing the target and the published context leaves the phone unchanged, since nothing reads from the watch.
