# Proposal

## Why

Every label in Restless is pinned to a fixed 7–11.5 pt size with heavy tracking, so the timer, the sessions list and both editors read as fine print. The app ignores the user's preferred text size entirely: someone who sets Larger Text in Settings sees no change, and the 8 pt set-map labels are below the 11 pt floor iOS uses for readable secondary text.

## What Changes

- Introduce one type scale in `Theme` built from Dynamic Type text styles, with four tiers: title, section heading, content (row title, value, body), and meta. Every screen uses a role from that scale instead of an ad-hoc point size.
- Replace every fixed `.font(.system(size:))` in the app screens and editors with a role. Names, values and actions grow the most; metadata stops being the visual bulk of the screen.
- Rebalance the hierarchy per screen: screen titles become `.largeTitle`, editable names `.title`, row titles `.headline`, values `.title3`, supporting text `.subheadline`, metadata `.footnote` and below.
- Let text wrap instead of shrink: remove `minimumScaleFactor` from wrapping copy, allow the timer's position strip to wrap to two lines at large sizes, and let the timer scroll when its content no longer fits.
- Scale the hero countdown and the progress ring with the text size, capped so the digits stay inside the circle.
- Raise every interactive control to a 44 pt minimum tap target and let rows and buttons grow with their text.
- Lock Screen panel: move to scaled styles, capped to fit the fixed panel height. Dynamic Island: keep fixed sizes because the island does not follow Dynamic Type, but raise its smallest labels from 9 to 11 pt.
- Update `prototype-workout-timer.html` first, at the same 430 × 880 frame, so it remains the visual reference for the new scale.

## Capabilities

### New Capabilities

- `app-typography`: the app's type tiers, how each screen ranks its text, how text follows the system text size, and how the timer and editors reflow at accessibility sizes.

### Modified Capabilities

- None. Existing timer, session and Live Activity requirements describe behaviour and copy; their behaviour does not change.

## Impact

- `Shared/Theme.swift`: type roles added (still SwiftUI-only, no iOS-only frameworks).
- `Restless/UI/`: `TimerScreen`, `SessionsScreen`, `SessionEditorScreen`, `PartEditorScreen`, `SetMap`; `Restless/App/RootView.swift` only for the tab bar check.
- `RestlessWidget/RestlessLiveActivity.swift`: Lock Screen and island type.
- `prototype-workout-timer.html`: reference type scale.
- Verification: Dynamic Type at default, XXL and an accessibility size on the simulator; existing `xcodebuild test` must stay green.
