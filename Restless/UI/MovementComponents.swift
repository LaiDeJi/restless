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

struct MovementProfileGrid: View {
    let profile: MovementProfile

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            cell("SIGNAL", "FOREARM")
            cell("MIN PERIOD", String(format: "%.2f s", profile.minPeriod))
            cell("RISE", String(format: "%.0f°", profile.rise))
            cell("FALL", String(format: "%.0f°", profile.fall))
        }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Theme.TypeScale.micro)
                .tracking(1.0)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(Theme.TypeScale.rowTitle)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}

struct TraceChart: View {
    let trace: [MotionTraceSample]
    let axis: MovementAxis

    var body: some View {
        Canvas { context, size in
            let values = trace.map { $0.gravity(axis) }
            guard values.count > 1, let low = values.min(), let high = values.max(), high > low else {
                return
            }
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - CGFloat((value - low) / (high - low)))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(Theme.setAccent), lineWidth: 2)
        }
        .frame(height: 86)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .accessibilityHidden(true)
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
