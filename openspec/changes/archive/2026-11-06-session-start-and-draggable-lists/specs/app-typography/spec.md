# Spec Delta

## MODIFIED Requirements

### Requirement: Controls grow with their text

Buttons, stepper rows and list rows SHALL take their height from their content and padding rather than a fixed height, and every interactive control SHALL provide at least a 44 × 44 pt tap target.

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
