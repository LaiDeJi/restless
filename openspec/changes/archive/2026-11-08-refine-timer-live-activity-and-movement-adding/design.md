# Design

## Context

See `proposal.md` for the five problems. The current shape that matters:

- `TimerScreen` places a header, an optional block strip, a position strip, the
  hero ring, the set map, the watch strip and the actions through
  `TimerStageLayout`. The position strip is built by `TimerPositionStrip` from
  `UP NEXT`, `BLOCK n OF m`, the block name, the movement, and the round/set
  segments.
- `SessionTransitions.restart` already exists and does exactly what the chosen
  control needs: it resets the snapshot to the same preset in `ready` with zero
  completed sets. The Live Activity coordinator already listens to it.
- `RestlessLiveActivity` draws the Lock Screen panel with five text lines plus
  the timer, progress bar and buttons, and caps Dynamic Type at
  `accessibility1`. The system caps a Live Activity at 160 points and truncates
  the overflow; the current rest state exceeds it on an iPhone 18 Pro Max.
- `BlockEditorScreen` opens `MovementPickerSheet` for every add. The sheet stages
  movements and commits on DONE. `SessionDraftStore.appendMovements` already
  appends a batch to a saved or staged block and applies the two-movement rounds
  rule.
- The app deploys to iOS 18 and builds with the iOS 27 SDK. `TabView` and
  sheets already take Liquid Glass on iOS 26+; the custom capsules do not.
- The prototype is the copy and layout source of truth; the skill owns the
  rest/state rules. The Lock Screen panel is not in the prototype.

## Goals / Non-Goals

**Goals:**

- One restart path that reuses the existing transition and needs no new model
  state.
- A position strip that names each thing once and stays one line at default
  sizes.
- A Lock Screen panel that fits 160 points by construction, not by truncation.
- A one-tap library add that also works on a staged block, without removing the
  batch sheet.
- Liquid Glass on floating chrome only, with the deployment target unchanged.

**Non-Goals:**

- Redesigning the Dynamic Island, the activity attributes or content state.
- Changing the picker's stage-then-DONE contract or its copy.
- Adding App Group storage, Live Activity intents, sound, or haptics.
- Raising the deployment target to iOS 26.
- Reworking the session editor's block rows or their summaries.

## Decisions

### Restart control reuses `.restart`

The header gets a `↺` control when `snapshot.doneSets > 0 && snapshot.phase != .done`.
The first tap sets a local `restartArmed`; the second calls
`engine.perform(.restart)`. No new `SessionAction`, no new snapshot field, no
special case in the coordinator. The control is available in `ready`,
`performing`, `resting`, and `paused`, because restart is a session action, not
an edit; `EDIT` stays hidden while locked.

- **Placement:** trailing group in the timer header, after `EDIT`. The header's
  `ViewThatFits` fallback stacks the name above an HStack holding both controls,
  so an 18-character name and both controls survive accessibility sizes.
- **Armed state:** the icon becomes a capsule reading `TAP AGAIN` in the
  round-rest amber. The armed state survives no longer than the current phase:
  an `onChange(of: snapshot.phase)` clears it, as does leaving the timer. There
  is no timeout and no alert; this matches the two-tap delete pattern the app
  already uses.
- **Why restart, not reset to the gate:** the user chose it, and the editor's
  `RESTART SESSION` already means "start again from the first set". A reset to
  `notStarted` would add a second meaning for the same idea.
- **Alternative rejected — confirmation alert:** heavier than the app's existing
  two-tap arming, and it would pause the visual rhythm of the timer.
- **Alternative rejected — hiding it during rest:** that is exactly when a user
  wants to abandon a session.

### The position strip drops repeated block copy

`TimerPositionStrip` will build its segments as:

- `UP NEXT` during `resting` or `paused`;
- the block name only when the plan has a single block and the block name is not
  equal to the movement name (case-insensitive, trimmed);
- the movement name;
- the round segment when rounds > 1 and the set segment when sets per round > 1.

The `BLOCK n OF m` segment is removed entirely. With several blocks the block
strip already names the active block and auto-scrolls to it; with one block the
block name stays only when it says something the movement name does not. The
existing `ViewThatFits` single-line/stacked pair stays, so accessibility sizes
may still wrap above the ring.

- **Why not shorten the copy instead of deduplicating:** the duplicated block
  name is the bulk of the width, and the chip already carries it. Removing it
  makes the resting line fit without shrinking type.
- **Alternative rejected — folding the strip into the hero:** the hero already
  carries the kicker, countdown, and the rest copy; a fourth line inside the
  ring would crowd the smallest hero.
- **Test seam:** extract the segment builder as an internal pure
  `TimerPositionCopy` value so `RestlessTests` can cover multi-block,
  single-block, name-equals-movement, resting, and 1×1 cases.

### The Lock Screen panel is a three-row layout with a hard budget

The panel becomes:

1. Header row: session name (`micro`) above the movement name (`rowTitle`, one
   line), with the countdown trailing at 26 pt (scaled, capped at 32).
2. State row: the kicker in the phase accent plus one context string, on one
   line:
   - ready: the upcoming rest kicker + `SET s OF S` (or `ROUND r OF R` when sets
     per round is 1, or `AFTER THIS SET` when neither applies);
   - resting/paused: the kicker + `restContext` (`AFTER SET 5`, `AFTER ROUND 3`,
     `AFTER CURL · NEXT PUSHDOWN`, `AFTER CHEST · NEXT ARMS`);
   - performing: `WORK` + the subtitle (`REST 1:00 AFTER`);
   - done: the completed-set kicker + the session totals subtitle.
3. Progress bar when resting, paused or performing, then the action buttons.

The separate `positionLine` row and the separate `restCopy` row are deleted; the
state row replaces both. Every row gets `lineLimit(1)` and the movement and
context get a small `minimumScaleFactor`. Padding drops to 14 and the vertical
spacing to 8. `.dynamicTypeSize(...(.xxLarge))` replaces `accessibility1`.

At default sizes the panel is about 138 points tall with progress and buttons;
at xxLarge it is about 145–150. Both stay under 160. The expanded island keeps
its current four-line leading region, timer and bottom controls; it is not part
of this change.

- **Why xxLarge:** at `accessibility1` the movement line alone is about 28 pt,
  and the buttons and padding push the panel past 160. xxLarge is the largest
  size at which the defined rows fit without clipping.
- **Why not clip the panel to 160:** the system already does that, which is the
  bug; the layout must fit, not hide.
- **Why not remove the movement name:** it is the one line that says what the
  set is; progress and position are recoverable from the state row and the
  countdown.
- **Copy stays in the widget:** no new fields travel in the activity; the
  existing snapshot, `movementLabel`, `restCopy`, and `roundSetCopy` supply the
  text.

### The block editor adds from the library in one tap

Under the movement list and above `ORDER`, the block editor shows an
`ADD FROM LIBRARY` section listing library movements not already in the block.
Each row is a normal 44 pt row with a `+`; tapping it calls
`draft.appendMovements([MovementAddition(movement:condition: .manual, target: nil)], to: target)`
and then `draft.flush()`. The append already handles saved and staged blocks and
the two-movement rounds rule.

The section is hidden while `isLocked`, and absent when every library movement
is already in the block. The `+ ADD MOVEMENT` sheet stays below it for several
movements, typed names, and custom end conditions. The row action is discrete,
like reorder or delete, so it flushes immediately rather than waiting for the
350 ms idle debounce.

- **Why inline rather than a faster sheet:** the sheet still needs its DONE
  even for one movement; the inline row removes the sheet and both DONE taps
  for the common case.
- **Why rows, not chips:** the rest of the plan UI is rows, and a row can carry
  the name plus the profile tag. The page scrolls; the unused list is bounded by
  the library size.
- **Why not change the picker:** its staging exists so several movements can be
  reviewed before commit. This change adds a fast path and leaves that contract
  intact.
- **Staged blocks:** the same section appears for a new block, so the flow
  becomes `ADD BLOCK` → tap the movement → `DONE`. Nothing reaches
  `session.blocks` until DONE.

### Liquid Glass is a small, gated modifier

A `chromeGlass` view modifier lives beside `PlanPillButton` in
`Restless/UI/PlanChrome.swift`:

- iOS 26+: `.glassEffect(.regular.tint(tint).interactive(), in: shape)`;
- iOS 18–25: the current translucent fill and hairline stroke.

It is applied only to the timer's `EDIT` and restart controls and the SESSIONS
`+` control. `PlanPillButton` itself is not changed, so editor `DONE` and back
pills stay flat. The armed restart passes the amber tint; the unarmed controls
use the default glass. A `@ViewBuilder` body keeps the two branches in one
modifier.

- **Why not the whole app:** Apple's guidance is to use Liquid Glass sparingly,
  for controls and navigation above content, and not in the content layer. The
  ring, cards, steppers, and primary buttons are content and keep their flat
  neon-on-black contrast. The system tab bar and sheets already take glass.
- **Why no deployment bump:** the modifier branches at runtime; iOS 18 and 25
  keep the current look. Raising the target would drop devices for a cosmetic
  change.
- **Alternative rejected — `.glassEffect` on every capsule:** it would double
  the glass surfaces, wash out the accent, and make the timer harder to read in
  bright light.

### Prototype and skill first

Before Swift changes, `prototype-workout-timer.html` gets the restart pill, the
deduplicated strip, the inline library rows, and the CSS glass simulation. The
skill's timer presentation, editing, copy, Live Activity and tests sections are
updated with the same rules. The Lock Screen panel has no prototype
representation and is verified in the simulator.

## Risks / Trade-offs

- **The Lock Screen panel could still exceed 160 points with an 18-character
  movement and a long state row at xxLarge.** → Cap at xxLarge, one line per
  row, 14 pt padding, 26 pt timer; measure in the simulator at default, XXL,
  xxLarge, and an accessibility size, in both the Lock Screen and Notification
  Center.
- **Removing `BLOCK n OF m` weakens orientation in a long multi-block plan.** →
  The block strip auto-scrolls the active chip into the centre and fills it; add
  a five-block test and keep the chip visible in the screenshots.
- **The inline library lengthens the block editor for a large library.** → List
  only unused movements, keep rows compact, and leave the sheet as the path for
  big batches. The page already scrolls.
- **A two-tap restart can be triggered by a stray second tap.** → It arms only
  after a set is done, changes its label to `TAP AGAIN`, and disarms on any
  phase change; no alert and no immediate first-tap action.
- **The iOS 18–25 fallback cannot be run on this Mac (only iOS 27 runtimes are
  installed).** → The fallback is the existing fill code, unchanged; build
  against the iOS 27 SDK, review the branch, and optionally install an iOS 18
  runtime before release.
- **Glass on the EDIT/`+` controls could reduce label contrast against the dark
  background.** → Keep the labels white and the glass neutral; use the amber
  tint only for the armed restart, where the label also changes.

## Migration Plan

No stored data changes. The timer snapshot, session records, activity
attributes, and content state are untouched. Deploying is a code change; rolling
back restores the previous UI without a migration.

## Open Questions

None.
