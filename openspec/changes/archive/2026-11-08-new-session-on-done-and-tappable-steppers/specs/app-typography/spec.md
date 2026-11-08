# Spec Delta

## MODIFIED Requirements

### Requirement: Controls grow with their text

Buttons, stepper rows and list rows SHALL take their height from their content and padding rather than a fixed height. Every interactive control SHALL provide a continuous tap target of at least 44 × 44 pt over its whole visible surface, including its center. A glyph, text run, or leading strip smaller than the control SHALL NOT be the only hittable part.

#### Scenario: Buttons grow at the largest text size

- **GIVEN** the largest accessibility text size
- **WHEN** the timer and both editors are shown
- **THEN** primary buttons, footer buttons and stepper rows grow with their labels and no label is clipped

#### Scenario: Small actions keep a full tap target

- **GIVEN** any text size
- **WHEN** the timer EDIT action, a block grip handle, a row delete action or a rest stepper is shown
- **THEN** its tappable area is at least 44 × 44 pt

#### Scenario: Plan rows still grow with their text

- **GIVEN** the largest accessibility text size
- **WHEN** a block or movement row is shown
- **THEN** the row grows with its text and the grip and delete targets stay fully visible

#### Scenario: A stepper changes on a center tap

- **GIVEN** a block editor with a minus and plus
- **WHEN** the user taps the center of either control
- **THEN** the value changes by one step and the tap target is not limited to the glyph or the leading edge

#### Scenario: A header action fires on a center tap

- **GIVEN** a new session editor
- **WHEN** the user taps the center of DONE
- **THEN** the draft is saved and the editor returns to SESSIONS

#### Scenario: An end-condition segment takes a body tap

- **GIVEN** the block movement editor with MANUAL selected
- **WHEN** the user taps the middle of the TIME segment
- **THEN** TIME becomes selected
