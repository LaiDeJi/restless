import SwiftUI

struct EndConditionPicker: View {
    @Binding var selection: EndCondition
    var locked = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EndCondition.editorOrder, id: \.self) { condition in
                Button {
                    selection = condition
                } label: {
                    Text(condition.label)
                        .font(Theme.TypeScale.micro.weight(.bold))
                        .tracking(0.7)
                        .foregroundStyle(selection == condition ? Theme.ink : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selection == condition ? Theme.setAccent : .clear)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(locked)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.055))
        )
    }
}

struct PlanStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var format: (Int) -> String = { "\($0)" }
    var locked = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.TypeScale.body.weight(.medium))
                .tracking(0.2)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Text(format(value))
                .font(Theme.TypeScale.value)
                .monospacedDigit()
                .foregroundStyle(locked ? .white.opacity(0.3) : .white)
                .frame(minWidth: 54, alignment: .trailing)

            HStack(spacing: 2) {
                PlanStepButton(
                    systemName: "minus",
                    accessibilityLabel: "Decrease \(label)",
                    enabled: !locked && value > range.lowerBound
                ) {
                    guard !locked, value > range.lowerBound else { return false }
                    value = max(range.lowerBound, value - step)
                    return value > range.lowerBound
                }
                PlanStepButton(
                    systemName: "plus",
                    accessibilityLabel: "Increase \(label)",
                    enabled: !locked && value < range.upperBound
                ) {
                    guard !locked, value < range.upperBound else { return false }
                    value = min(range.upperBound, value + step)
                    return value < range.upperBound
                }
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(.white.opacity(0.045))
    }
}

struct PlanCountRow: View {
    let label: String
    @Binding var value: Int
    var minimum = 1
    var locked = false

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.TypeScale.body.weight(.medium))
                .tracking(0.2)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if editing {
                TextField("", text: $draft)
                    .font(Theme.TypeScale.value)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .frame(minWidth: 54, maxWidth: 90, alignment: .trailing)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
            } else {
                Button {
                    guard !locked else { return }
                    draft = "\(value)"
                    editing = true
                    focused = true
                } label: {
                    Text("\(value)")
                        .font(Theme.TypeScale.value)
                        .monospacedDigit()
                        .foregroundStyle(locked ? .white.opacity(0.3) : .white)
                        .frame(minWidth: 54, alignment: .trailing)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(locked)
            }

            HStack(spacing: 2) {
                PlanStepButton(
                    systemName: "minus",
                    accessibilityLabel: "Decrease \(label)",
                    enabled: !locked && value > minimum
                ) {
                    guard !locked, value > minimum else { return false }
                    value = max(minimum, value - 1)
                    return value > minimum
                }
                PlanStepButton(
                    systemName: "plus",
                    accessibilityLabel: "Increase \(label)",
                    enabled: !locked && value < Int.max
                ) {
                    guard !locked, value < Int.max else { return false }
                    value += 1
                    return value < Int.max
                }
            }
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(.white.opacity(0.045))
    }

    private func commit() {
        editing = false
        let parsed = Int(draft.trimmingCharacters(in: .whitespacesAndNewlines)) ?? value
        let next = max(parsed, minimum)
        if next != value { value = next }
    }
}
