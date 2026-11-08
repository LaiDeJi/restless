# Tasks

## 1. Prototype reference

- [x] 1.1 Apply the default-size targets from `design.md` D2 to `prototype-workout-timer.html`: screen title, eyebrow, card name/meta, editable name, section kickers, stepper labels/values, timer kicker/position/subtitle/countdown, and the widget panel. Verify at 430 × 880 that no text overlaps or clips on the timer, sessions, session editor and part editor screens.
- [x] 1.2 Adjust the prototype's tracking and line heights where the larger text collides (chips, position strip, card rows) and verify every screen still fits its frame without scrolling the phone body.

## 2. Type scale tokens

- [x] 2.1 Add `Theme.TypeScale` to `Shared/Theme.swift` with the ten roles from `design.md` D1, using only `Font` semantic styles. Verify the app target builds and `RestlessWatch` still compiles `Shared/Theme.swift` for watchOS.
- [x] 2.2 Confirm no role is below 11 pt at the default size and that `section`, `meta` and `micro` are distinguishable by weight and tracking; verify by reading the roles table back against the spec's four-tier ranking.

## 3. Sessions list and editors

- [x] 3.1 Migrate `SessionsScreen` to the roles: 34 pt title, 13 pt eyebrow, 17 pt card name, 13 pt summary, 11 pt ACTIVE badge, 44 pt add button, 13 pt footer and lock banner. Verify at default that SESSIONS outranks WORKOUTS and the name outranks the summary; verify at AX3 that the card grows and the summary wraps to two lines.
- [x] 3.2 Migrate `SessionEditorScreen`: 13 pt back/DONE with 44 pt height, 28 pt name field, 13 pt kickers, 17 pt part names, 13 pt part meta, 44 × 44 move buttons, 17 pt footer actions with 52 pt min height, 13 pt delete. Verify a 2-line part meta and `TAP AGAIN TO DELETE` at AX3 without clipping.
- [x] 3.3 Migrate `PartEditorScreen`: 28 pt name, 15 pt row labels, 20 pt values, 56 pt min rows, 17 pt stepper icons with 44 × 44 targets, 13 pt footer copy and delete. Verify `SETS PER ROUND` and a four-digit value at default and AX3, and that rows grow instead of compressing.
- [x] 3.4 Replace fixed `frame(height:)` on editor buttons, rows and text with min heights plus padding, and verify every control measures at least 44 × 44 in the accessibility tree.

## 4. Timer

- [x] 4.1 Apply the roles to the timer's header, EDIT, part chips, position strip, kicker, subtitle, set-map labels, primary action and skip control. Verify at default against the updated prototype: countdown largest, session name and kicker below it, progress count smallest.
- [x] 4.2 Make the timer content a `ScrollView` with `.scrollBounceBehavior(.basedOnSize)` and `minHeight` equal to the available height; wrap the position strip in `ViewThatFits` with a two-line fallback and add the vertical header fallback for long names. Verify at AX3 that the strip wraps, the actions are reachable by scrolling, and nothing is truncated.
- [x] 4.3 Scale the hero countdown with `@ScaledMetric`, cap it at 96 (large) and 68 (small), grow the ring to 340 at accessibility sizes, and keep the kerning proportional. Verify at AX1 that digits and ring grow, and at AX5 that DONE fits inside the ring.
- [x] 4.4 Verify the timer in ready, resting, paused and done at default, XXL, AX3 and AX5 with an 18-character session name and part name; check for clipped text, shrinking labels, and actions below the fold with no way to scroll.

## 5. Live Activity

- [x] 5.1 Migrate the Lock Screen panel to the roles (11 pt session name, 17 pt part name, 12 pt kicker, 13 pt subtitle, scaled timer capped at 54) and cap the panel at `.accessibility1`. Verify at AX5 that the part name, rest label and remaining time are fully visible with no clipping.
- [x] 5.2 Raise the island's fixed sizes (leading 12/12/11, timer 30, compact 12/14, buttons 13) without changing regions or links. Verify expanded and compact presentations with a long part name and the three-letter compact label; confirm `xcrun simctl listapps <udid>` shows Restless owns the island before judging it.
- [x] 5.3 Check that the island's fixed sizes do not alter its accessibility labels or URL actions; verify set-done, pause, resume, skip and restart still work from the island links.

## 6. Integration verification

- [x] 6.1 Run `xcodegen generate` only if files were added, then build for iPhone 18 Pro Max and run `xcodebuild test`; all tests pass. If the runner hangs, follow the AGENTS recovery steps rather than rerunning unchanged.
- [x] 6.2 Build `RestlessWatch` for `generic/platform=watchOS` and confirm the shared `Theme` compiles into the watch target.
- [x] 6.3 Record one Argent e2e pass covering timer → SESSIONS → session editor → part editor → back, at default and AX3, reading the accessibility tree at each checkpoint; confirm the rest keeps running across tabs and the editing lock still appears during rest.
- [x] 6.4 Sweep `Restless/UI` and `RestlessWidget` for remaining `.font(.system(size:))` uses; only the island's fixed sizes, the hero's scaled metric and proportional kerning may remain, and the grep result is recorded in the change.

## Workflow follow-up

- Archive the change after the review passes and the four text-size checks are attached to the change.
