# Verification — adopt-dynamic-type

Date: 2026-11-05. Device: iPhone 18 Pro Max simulator (iOS 27.0). Text sizes:
default (`large`), XXL (`extra-extra-large`), AX3 (`accessibility-extra-large`)
and AX5 (`accessibility-extra-extra-extra-large`).

## Type roles

`Theme.TypeScale` in `Shared/Theme.swift` carries the roles from design D1:
`screenTitle` 34, `pageTitle` 28, `section` 13 semibold, `rowTitle` 17,
`value` 20, `body` 15, `meta` 13, `label` 12, `micro` 11, `action` 17,
`compactAction` 13. (D1's table lists eleven roles; the task summary says ten.)

No role is below 11 pt at the default size. `section` (13 semibold) and `meta`
(13 regular) differ by weight, and `micro` is 11 semibold. Call-site tracking:
`section` 1.2, `meta` 0.2–0.6, `micro` 0.2–1.2; the largest uppercase tracking
is 1.6, inside the spec's limit.

## Build and tests

- App build for iPhone 18 Pro Max — BUILD SUCCEEDED.
- `xcodebuild test` — 42 Swift Testing tests passed, 0 failures, TEST SUCCEEDED.
- `RestlessWatch` for `generic/platform=watchOS` — BUILD SUCCEEDED with
  `Shared/Theme.swift` in the watch target.

## Fixed-size sweep (task 6.4)

`grep -rn "\.font(\.system(size:" Restless/UI RestlessWidget`:

```
Restless/UI/TimerScreen.swift:384        hero countdown, size from @ScaledMetric capped 96/68
RestlessWidget/RestlessLiveActivity.swift:18,22,26   island expanded leading 12/12/11
RestlessWidget/RestlessLiveActivity.swift:34         island timer 30
RestlessWidget/RestlessLiveActivity.swift:54,61,66   island compact 12/14
RestlessWidget/RestlessLiveActivity.swift:129        Lock Screen timer, min(@ScaledMetric 42, 54)
```

The Lock Screen timer is a capped `@ScaledMetric` required by design D5; the
task's allow-list names only the island, the hero and the kerning, so this one
is recorded rather than removed.

`grep "frame(height:"` finds no fixed heights in `Restless/UI` or
`RestlessWidget`. `minimumScaleFactor` remains only for the timer's session-name
header (0.6) and the island compact label (0.8), both allowed by D5.

## Prototype

Checked at 430 × 880: timer (ready, resting with two parts, 18-character
session name), sessions list, session editor (locked and unlocked) and part
editor. No text overlaps or clips, and the phone body does not scroll.

## App screens

- **Default:** timer ready/resting; sessions list (SESSIONS outranks WORKOUTS,
  name outranks summary); session editor; part editor. The lock banner appears
  in the list and the editor while resting, controls are dimmed, and the rest
  keeps running when the tab changes.
- **XXL:** timer ready (round rest), sessions list and session editor; all
  text scales, cards and rows grow, no truncation.
- **AX3:** timer resting with two parts; the position strip uses the two-line
  fallback; sessions list moves the ACTIVE badge below the card text so the
  summary wraps without a squeezed column; the part index and meta wrap
  cleanly; part-editor rows stack the label above value and steppers so
  `ROUNDS` never breaks mid-word. The lock banner shows in the list, the
  session editor and the part editor; the rest ran from 2:00 to 1:12 across
  the tab switch.
- **AX5 with an 18-character session name:** the header falls back to the name
  above a trailing EDIT; the position strip stacks PART / ROUND / SET; the
  countdown is capped and the ring grows to 340; DONE fits inside the ring and
  the done subtitle shows all three lines; the primary action grows and stays
  reachable by scrolling. No label shrinks except the capped session-name
  header.

## Live Activity

- Lock Screen at AX5 (panel capped at `.accessibility1`): session name, part
  name, rest label, subtitle and the capped 54 pt timer are all visible with no
  clipping.
- Island expanded: leading 12/12/11, timer 30, buttons 13; compact: 12/14 with
  the three-letter label (`CHE`). Regions and labels are unchanged.
- `xcrun simctl listapps` showed both `com.whc.restless` and an older
  `com.whc.rounds`; the old bundle was uninstalled from the throwaway simulator
  so the island judged here belongs to Restless.
- Island links applied from `restless://`: set-done, pause, resume, skip and
  restart all updated the app state.
