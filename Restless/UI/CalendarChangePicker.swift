import SwiftUI

/// The ordered sessions as one-tap rows. The scheduled row carries SCHEDULED
/// and clears the change when picked; the current choice is checked.
struct CalendarChangePicker: View {
    let day: Date
    let presets: [WorkoutPreset]
    let scheduledPresetID: UUID?
    let chosenPresetID: UUID?
    let onPick: (WorkoutPreset) -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CHANGE EXERCISE")
                            .font(Theme.TypeScale.section.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.secondaryText)
                        Text(CalendarCopy.longDay(day))
                            .font(Theme.TypeScale.meta)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer(minLength: 8)
                    Button("DONE", action: onDone)
                        .font(Theme.TypeScale.meta.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 44)
                }

                VStack(spacing: 8) {
                    ForEach(presets) { preset in
                        row(preset)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
    }

    private func row(_ preset: WorkoutPreset) -> some View {
        Button {
            onPick(preset)
        } label: {
            HStack(spacing: 10) {
                Text(preset.name)
                    .font(Theme.TypeScale.rowTitle)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if preset.id == scheduledPresetID {
                    Text("SCHEDULED")
                        .font(Theme.TypeScale.micro.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.secondaryText.opacity(0.12)))
                        .overlay(Capsule().stroke(Theme.secondaryText.opacity(0.34), lineWidth: 1))
                }
                if preset.id == chosenPresetID {
                    Image(systemName: "checkmark")
                        .font(Theme.TypeScale.meta.weight(.bold))
                        .foregroundStyle(Theme.setAccent)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
