# Proposal

## Why

Between sets the phone is the only control surface: marking a set done, skipping a rest, pausing, or resuming all need it in hand. The wrist already receives the rest-end notification and can do nothing with it. Restless had a watch app before and removed it (`2026-11-10-remove-movement-recording`) because it needed motion permissions, HealthKit, a profile model and a second way to end a set. A remote needs none of that: the state machine already accepts actions from outside the app, so the wrist can send the same action the phone's button sends.

## What Changes

- **A watchOS companion app that is only a remote.** It shows the phase, the movement, the position in the plan and the sets completed, and it offers the current phase's buttons.
- **No countdown on the wrist.** Nothing on the watch screen is derived from the clock, so nothing freezes on the Always On display or goes stale between wrist raises. The phone keeps the countdown, the notification and the Live Activity.
- **The same buttons, in the same order.** The primary button is the snapshot's `primaryAction` with its `primaryTitle`; during a rest the secondary glyph is `skipRest`. The watch makes no copy or ordering decision of its own.
- **The phone stays the only authority.** A tap sends one action with the time it was tapped; the phone applies it through `SessionTransitions.apply` at that time, so a delayed message does not move the deadline. The watch applies no transition, runs no timer, alerts nothing, and adds no HealthKit, workout session or extended runtime session.
- **The watch is fed, not synced.** The phone publishes the running snapshot and the active plan; the watch renders the last one it received and reconciles the deadline for display only.
- **The wrist notification opens the app.** Tapping the mirrored rest-end notification on the watch opens the remote on its buttons. It still carries no action buttons and raises no second alert.

## Capabilities

### New Capabilities

- `watch-remote`: the wrist as a control surface for the running session — what it displays, which actions it may send, how a tap reaches the phone, and what it must never do (own state, count time, alert).

### Modified Capabilities

- `countdown-alerts`: tapping a completion alert on the watch opens the watch app instead of the phone, so the existing "tapping an alert opens Restless on the timer" requirement needs a device-qualified form.

## Impact

- New watchOS app target and scheme in `project.yml`; `xcodegen generate` regenerates the project.
- `Shared/`: one Codable message type for actions and one for the published snapshot and active plan. No App Group, no `SessionStore` change, no new SwiftData.
- `Restless/`: a `WCSession` delegate activated at launch that maps a received action to `refreshFromStore()` and the existing `handle(_:)` switch, and publishes state when the session changes.
- `RestlessWatch/`: one screen, its button set derived from the snapshot, and a local deadline reconciliation for display.
- Specs and the rest-timer skill gain the watch surface; `countdown-alerts` gains the watch tap case.
- Provisioning: a second bundle identifier signed by the same team. Verify on the physical watch before building the screen, since the simulator cannot exercise the background wake.
