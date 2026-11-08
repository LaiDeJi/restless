# Design

## Context

See `proposal.md` for motivation. The constraints that shape this design:

- iOS 18, Swift 6 with complete strict concurrency, SwiftData for saved plans, ActivityKit for the Live Activity. No App Groups on the personal team, so `SessionStore` falls back to `UserDefaults.standard` and island controls stay `Link`s that open the app.
- The watch target compiles only `Shared/WorkoutPreset.swift`, `Shared/SessionSnapshot.swift`, and `Shared/Theme.swift`. A new `WorkoutPart` type must live in one of those files, or `project.yml` must add a file to the watch target.
- `prototype-workout-timer.html` owns visual and copy behaviour; `.agents/skills/restless-rest-timer/SKILL.md` owns the timing rules and island contract. Both are updated before Swift.
- The current setup sheet commits on every stepper tap: a synchronous SwiftData save, `SessionEngine.use` (which resets the session and persists the snapshot), a ticker restart, and `LiveActivityCoordinator.restart`, which ends and requests a new activity whenever any rest value changes. That main-actor work per tap is what makes the numbers lag.

## Goals / Non-Goals

**Goals:**

- Session plans of ordered parts with per-part rounds, sets, set rest, and round rest.
- Sequential execution; the finished part's round rest covers the transition to the next part.
- No product cap on rounds or sets; exact entry by stepper and numeric keyboard.
- Local-first editing, so the displayed number is never waiting on SwiftData or ActivityKit.
- A two-tab app shell and dedicated sessions and part screens.
- Part-aware timer and Live Activity, with an adaptive set map.
- Lossless-enough migration for existing presets, with a rollback path.

**Non-Goals:**

- Superset/circuit mode where parts alternate every set.
- A third tab for history, stats, or settings.
- Logging completed workouts, HealthKit, watch workout sessions, sound, haptics, or rest-end notifications.
- Typing rest durations or a wheel picker; rests stay stepper-only with 15-second steps.
- Drag-and-drop part ordering; the first version uses move up/down actions.
- Multiple concurrent Live Activities.

## Decisions

### 1. Keep `WorkoutPreset` as the session plan and nest `WorkoutPart`

The stored plan and all the maths stay in `WorkoutPreset`. A new value type sits beside it in the same file so the watch target keeps compiling.

```swift
struct WorkoutPart: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var rounds: Int
    var setsPerRound: Int
    var setRest: Int
    var roundRest: Int
}

struct WorkoutPreset: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var parts: [WorkoutPart]
}
```

The app calls this a **session** in the UI. The type keeps its old name because renaming the SwiftData entity or introducing a second persisted model buys nothing and risks the existing store. The default and migrated plan both have exactly one part, so single-part behaviour stays familiar.

Staging note: while the old setup sheet and widget are still in place, `WorkoutPreset` keeps writable first-part accessors (`rounds`, `setsPerRound`, `setRest`, `roundRest`), `Bounds.rounds = 1...Int.max`, and a one-part convenience initializer. They let the model, rest maths, and tests land before the screens. The cleanup group removes them once every caller is part-aware.

Alternatives rejected: a new `WorkoutSession` type (SwiftData entity rename, broad churn); a `PartRecord` relationship (ordering, cascade rules, and a harder migration for a small nested value).

### 2. One global set index, generalized rest choice

Existing progress is a single `doneSets` count. Keep it. `position(at:)` walks the parts and returns a part-aware position; `rest(after:)` adds one branch at the end of a part.

```swift
struct WorkoutPosition: Hashable, Sendable {
    let partIndex: Int   // 0-based
    let partName: String
    let round: Int       // 1-based
    let set: Int         // 1-based
}

func rest(after doneSets: Int) -> RestOption? {
    guard doneSets < totalSets else { return nil }
    let p = position(at: doneSets)
    let part = parts[p.partIndex]

    if p.set < part.setsPerRound {
        return RestOption(kind: .set, duration: part.setRest)
    }
    if p.round < part.rounds {
        return RestOption(kind: .round, duration: part.roundRest)
    }
    guard p.partIndex < parts.count - 1 else { return nil }
    return RestOption(kind: .round, duration: part.roundRest)
}
```

- Within a part the old rule is unchanged: set rest after a non-final set of a round, round rest after a round's final set.
- A part's final set uses that part's round rest when another part follows. The final set of the last part has no rest.
- The transition is still `RestKind.round`, so the amber accent and existing `ROUND REST` copy apply without a third kind.

Total rest:

```swift
// For each part i:
// setRests   = rounds * (setsPerRound - 1) * setRest
// roundRests = (rounds - 1) + (i < parts.count - 1 ? 1 : 0)
```

The existing `totalSets = rounds * setsPerRound` becomes a sum over parts. Because rounds and sets are unbounded, multiplications use `multipliedReportingOverflow` and clamp to `Int.max` instead of trapping; a numeric field that would overflow `Int` is rejected and keeps its previous value.

Alternative rejected: per-part counters. More state in the snapshot, more places to reconcile after backgrounding, no user benefit.

### 3. No upper bound, exact entry, rests unchanged

`WorkoutPreset.Bounds` keeps:

- rounds minimum 1, no maximum;
- sets per round minimum 1, no maximum;
- rest 15...600 seconds, step 15.

The editor row's value becomes a button. Tapping it swaps in a focused `TextField` with a number pad; committing parses with `Int`, clamps values below 1 to 1, and leaves the old value on empty or non-numeric text. Steppers stay for ±1. Rests remain stepper-only and clamp at 15 and 600, with the increase/decrease control disabled at the bound.

The set map cannot draw arbitrary shapes, so the timer threshold is 6 rounds × 12 sets (72 dots). Larger parts use a progress bar. This is a presentation limit, not a data limit.

Step buttons get a 44 pt hit area even though the visual capsule stays 34 × 30; rapid tapping is the target interaction. The editable number drops `.contentTransition(.numericText())`; the digits must lead the finger, and the transition is what makes a fast burst look frozen even after the heavy work is removed.

### 4. Store parts as JSON on the existing SwiftData record

Add one optional property to `PresetRecord`:

```swift
@Model
final class PresetRecord {
    var id: UUID
    var name: String
    // Legacy single-part columns, kept for reading old stores and rollback.
    var rounds: Int
    var setsPerRound: Int
    var setRest: Int
    var roundRest: Int
    var partsData: Data?
    var createdAt: Date

    var parts: [WorkoutPart] {
        if let data = partsData,
           let decoded = try? JSONDecoder().decode([WorkoutPart].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return [WorkoutPart(id: id, name: name, rounds: rounds, setsPerRound: setsPerRound,
                            setRest: setRest, roundRest: roundRest)]
    }
}
```

`apply` encodes `parts` and mirrors the first part into the legacy columns. A nil `partsData` therefore means "old record" and resolves to one part without a write. The first save writes `partsData`. This is a lightweight SwiftData migration: adding an optional property, no entity rename, no new model.

Rollback: an older build reads the legacy columns and sees the first part. `partsData` is preserved but ignored. It will not crash; it loses the additional parts until the newer build returns.

`SessionStore` moves from `restless.session.v1` to `restless.session.v2` because the encoded `WorkoutPreset` shape changed. `load` reads only v2 and removes v1. A missing snapshot starts the timer ready at the active session; `ActivePresetStore` is unchanged, so the user's selected plan survives.

Alternatives rejected: a separate `PartRecord` (more schema objects and ordering rules); an explicit `SchemaMigrationPlan` (the app is local-only and the add-an-optional-property path is already lightweight).

### 5. Bottom-tab shell with three session screens

A native `TabView` provides the Apple Health-style bar and handles safe-area and accessibility behaviour. The tab bar is styled to the app's palette and stays visible; the timer's action button sits above it.

| Screen | Owns |
| --- | --- |
| `TimerScreen` | The live session, part strip, hero, set map, actions. `EDIT` opens the active session. |
| `SessionsScreen` | Every saved session as a card, active badge, add action. Tapping opens the editor. |
| `SessionEditorScreen` | Session name, part list, add/reorder/delete part, use/delete session, locked banner. |
| `PartEditorScreen` | One part's name, rounds, sets, set rest, round rest, total, delete. |

- `AppRouter` (`@Observable`, main actor) holds the selected tab and the sessions navigation path. `TimerScreen`'s EDIT sets the session tab and pushes `.session(activeID)`. The part editor is a direct `NavigationLink` from the session editor.
- `SetupSheet.swift` is removed. The sessions list, not a sheet, owns session management.
- A new session is created and opened, but not activated. It has a fresh id and one part named `New part` inheriting the source session's first part values, or the default 3 × 3 / 60 / 120 if there is no source. `USE THIS SESSION` activates it. This avoids resetting a live timer just because the user started planning.
- A new part inherits the previous part's rounds, sets, and rests, with a fresh id and the name `New part`. The session always keeps one part; the last part has no delete action.
- Delete actions stay two-step inline (`DELETE` → `TAP AGAIN TO DELETE`), matching the existing voice.
- Reorder is `MOVE UP` / `MOVE DOWN` in the part row's menu. Drag ordering is deferred.
- Session and part names trim and cap at 18 characters; an empty session becomes `Untitled`, an empty part becomes `Untitled part`.
- While `SessionEngine.snapshot.isResting`, the sessions list and both editors are read-only: add, delete, reorder, activate, and every field are disabled, with an amber `EDITING LOCKED DURING REST` banner. The timer hides `EDIT`. Control returns when the rest ends; tab switching never changes the rest.
- An island link opens the app, so `RootView` handles `onOpenURL`: select the timer tab, then apply the action. `RootView` also owns scene-phase reconciliation so it works from either tab.

Alternatives rejected: a custom tab bar (more code for less accessibility); keeping the setup sheet (no room for a parts list and a part editor); probing whether editing an inactive session during a rest is safe (the spec keeps all editing locked for a predictable rule).

### 6. Local-first editing with a debounced commit

The freeze is not the number rendering; it is the work attached to the tap. Every bump currently runs:

1. `PresetRecord.apply` + `context.save()` on the main actor.
2. `onUse` → `SessionEngine.use` → snapshot reset, `SessionStore.save`, ticker restart.
3. `LiveActivityCoordinator.restart` → end the current activity and request a new one when a rest value changed.
4. A full `TimerScreen` invalidation behind the sheet.

Replace all of that with one in-memory draft store.

```swift
@MainActor @Observable
final class SessionDraftStore {
    var session: WorkoutPreset
    private(set) var isDirty = false
    private var pending: Task<Void, Never>?
    private let delay: Duration
    var commit: ((WorkoutPreset) -> Void)?

    init(session: WorkoutPreset, delay: Duration = .milliseconds(350)) { ... }

    func edit(_ mutate: (inout WorkoutPreset) -> Void) {
        mutate(&session)
        isDirty = true
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: self?.delay ?? .zero)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        pending?.cancel()
        guard isDirty else { return }
        isDirty = false
        commit?(session)
    }
}
```

The commit closure is wired in the screen:

```swift
record.apply(session)
try? context.save()
if record.id == ActivePresetStore.id {
    engine.use(session)   // one reset, one activity restart, after the burst
}
```

- Every stepper tap and keystroke only mutates `session` and schedules a task. The UI reads the draft directly and updates in the same frame.
- 350 ms of idle applies the change once. Editing a non-active session never touches the engine.
- `flush` runs on editor dismissal, `Done`, and `scenePhase != .active`; the timer cannot lose an edit just because the user switched tabs.
- Discrete actions — activate, create, delete, move — apply immediately because they are one intentional action, not a burst.
- The warning `Editing this session restarts it` remains for an active session with progress. The restart now happens once after the edit settles, which matches the warning rather than firing on every character.
- Tests inject a short delay and assert one commit for several edits and an immediate commit on flush.

Alternatives rejected: a save button (extra step, easy to lose); Combine debounce (more machinery for the same result); per-tap commit with only the Live Activity deferred (SwiftData and the session reset still stall the tap).

### 7. Part-aware timer presentation

`SessionSnapshot` gains `currentPart`. The screen changes only when the plan has more than one part:

- **Part strip** under the header: one capsule per part, horizontally scrolling and auto-scrolled to the active part. Completed parts dim with a check, the active part is filled with the set accent, future parts are outlined. Hidden for one part, which keeps the current screen unchanged for migrated presets.
- **Position strip** stays `ROUND n OF m · SET n OF m`; the part strip supplies the part context.
- **Set map** draws only the active part. At most 6 rounds and 12 sets per round use the existing dot grid; anything larger becomes a progress bar with `n OF m SETS IN THIS PART`.
- **Hero and actions** are unchanged. The transition rest is `.round`, so it uses the amber accent.
- **Done** summarizes parts, sets, and total rest.

Copy additions:

- `AFTER BICEPS · NEXT TRICEPS` for a transition rest, instead of `AFTER ROUND 3`.
- The ready subtitle stays `AFTER THIS SET`; the next part becomes visible when the rest starts.
- `durationString` replaces `clockString` for totals, rendering `18:00` below an hour and `1:02:00` above it.
- A shared `plural` helper avoids `1 PARTS`.

Layout: the tab bar takes roughly 49 pt, so the hero caps at 320 pt and its `GeometryReader` considers height as well as width. The part strip adds 28 pt only when it is shown. Verify on a 6.9-inch and a 6.1-inch simulator; the current design was tuned for the Pro Max only.

Accessibility: part capsules get `Part 2 of 3, Triceps, active`; steppers keep labels `Decrease rounds` / `Increase rounds`; the editable number announces its label and value. The tab bar uses native items.

### 8. Live Activity carries the plan and reuses the app's presentation

Attributes become the plan itself, so the widget and the app cannot drift:

```swift
struct RestlessActivityAttributes: ActivityAttributes {
    var preset: WorkoutPreset

    struct ContentState: Codable, Hashable {
        var phase: SessionPhase
        var doneSets: Int
        var restKind: RestKind?
        var duration: Int
        var deadline: Date?
        var pausedRemaining: Int
    }
}
```

- `restart` compares `activity.attributes.preset != snapshot.preset` instead of field-by-field. A plan change ends and re-requests; a content change updates.
- The widget builds a display-only `SessionSnapshot` from attributes + state and reuses `kicker`, `subtitle`, `accentColor`, `currentPart`, and `upcomingRest` from `Theme.swift`. The duplicate `position`/`rest` maths in the widget is deleted.
- Lock screen: session name small, active part name prominent, kicker and rest context, timer, progress, buttons.
- Expanded: part name and `R1 · S1` leading, timer trailing, progress and controls at the bottom.
- Compact leading: a 3-character part label (`TRI`), or `DONE`; compact trailing: the countdown, `READY`, or `DONE`. The full part name and position live in the expanded and lock-screen views.
- Controls stay `Link`s to `restless://set-done`, `pause`, `resume`, `skip`, `restart`. No `LiveActivityIntent`.
- One activity at a time; stale activities are ended on launch and on plan change.

The plan payload is small (a name, a few parts, integers), so nesting `WorkoutPreset` in attributes is safe. If ActivityKit ever rejects the nested type, the fallback is a compact `[PartPlan]` DTO with the same fields.

### 9. Prototype and skill first

The prototype's model changes from one config to `sessions: [{ name, parts: [...] }]`, with a versioned localStorage key and migration of old presets into one part. Its timer needs the part strip, transition rest, and adaptive map; its setup sheet becomes the sessions list, session editor, and part editor inside the phone frame, with TIMER / SESSIONS tabs. The prototype remains silent.

The skill is rewritten around parts: model, rest rules, transition rest, total rest, unbounded rounds/sets, editing debounce, tabs, island attributes, copy, and tests worth writing. `AGENTS.md` updates its rules and layout for sessions, parts, tabs, and local-first editing.

## Testing

- `RestPlanTests`: part-aware positions, rest sequence across parts, transition rest, total rest (1080 s example), degenerate shapes (1 × 1 part followed by another, one-round parts, one-set parts), large totals, no cap, clamping of rests only.
- `SessionTests`: transition rest starts after a part's last set; the next part is ready when it ends; double tap still consumes one set; pause/skip/restart across a part boundary.
- `PresetRecordTests`: legacy record with nil `partsData` reads one part with the old values; JSON round-trip preserves part ids and order; `apply` mirrors the first part.
- `SessionDraftStoreTests`: several rapid edits produce one commit; `flush` commits immediately; a cancelled draft does not commit after flush.
- Manual: rapid SET REST taps, tab switch during a rest, editing locked during rest, 20 × 30 part shows a bar, old preset migrates, island shows part names and transition copy.
- Build and test with the commands in `AGENTS.md`; build the watch target to confirm the shared model compiles.

## Risks / Trade-offs

- **Timer layout cramps under the tab bar** → cap the hero at 320 pt, add the part strip only for multi-part sessions, verify on 6.1-inch and 6.9-inch simulators.
- **A debounced edit is lost if the app is force-quit within 350 ms** → flush on background, dismissal, and Done; the window is small and no heavier local store is worth it.
- **An old Live Activity with the previous attribute shape survives the update** → end all activities of the type on launch; ActivityKit also expires them after its normal limit.
- **SwiftData migration edge cases** → the fallback reads legacy columns and never requires `partsData`; test an in-memory legacy record. Rollback keeps the first part readable.
- **Absurd rounds × sets values** → overflow-safe arithmetic and input rejection; honest products do not approach it, and the adaptive map does not attempt to draw it.
- **Native tab bar fights the custom timer aesthetic** → style the bar to the palette; if it still looks wrong, a custom bar is a contained follow-up, not a model change.
- **Editing an inactive session while a rest runs is disallowed**, even though it would be technically safe → one predictable lock rule now; allow it later if it annoys.
- **Part ordering is menu-based, not drag** → simpler and accessible; drag is a later enhancement.

## Migration Plan

1. Update the prototype and skill first, then the model and tests.
2. Ship the shared model and rest maths with one-part fixtures; confirm the existing tests pass with `.chest` now holding one part.
3. Add `partsData`, the legacy fallback, and the v2 snapshot key; test migration in memory.
4. Replace the setup sheet with the tab shell and three screens; wire the draft store and commit closure.
5. Move the widget attributes to the plan payload and the shared presentation model.
6. Build the app, test the suite, build the watch target, and run the manual checks above.
7. Rollback is an older build: legacy columns still hold the first part, v1 snapshots are gone, and the timer starts fresh from the active session. `partsData` remains untouched for the next upgrade.

## Open Questions

None that change the specs or the task breakdown.
