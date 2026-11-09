# Spec Delta

## REMOVED Requirements

### Requirement: Glass does not carry meaning alone

**Reason**: The armed TAP AGAIN restart state is removed, so glass no longer has an armed-restart state to preserve. The remaining rule is that glass must stay secondary to a control's state.

**Migration**: Use Glass stays secondary to control state; the restart icon, accessibility label, and action must not depend on the material.

## ADDED Requirements

### Requirement: Glass stays secondary to control state

A control's state SHALL remain legible without relying on the material. The restart control SHALL keep the same icon, accessibility label, and confirmation action with and without Liquid Glass; the material MUST NOT be the only indication that a restart is available.

#### Scenario: Restart on both materials

- **GIVEN** a running session with a completed set
- **WHEN** the restart control is shown on iOS 18 and on iOS 26
- **THEN** both versions show the same restart icon, announce Restart session, and open the same confirmation dialog

#### Scenario: Glass is not the state

- **GIVEN** iOS 26 with Liquid Glass enabled
- **WHEN** the restart control is shown
- **THEN** its availability and meaning are clear without relying on the material
