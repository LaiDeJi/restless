import SwiftUI

/// The shared chrome of the calendar settings editors: a back pill, a kicker,
/// the title, and one explanatory line.
private struct CalendarEditorHeader: View {
    @Environment(\.dismiss) private var dismiss
    let kicker: String
    let title: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlanPillButton(title: "‹ CALENDAR") {
                dismiss()
            }
            Text(kicker)
                .font(Theme.TypeScale.section.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryText)
            Text(title)
                .font(Theme.TypeScale.screenTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(summary)
                .font(Theme.TypeScale.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func editorCard<Content: View>(_ content: Content) -> some View {
    content
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        )
}

/// One list of dated ranges and repeating weekdays, with a DATES / WEEKDAY add
/// form. A duplicate weekday and an end before the start are refused in place.
struct ExceptionsScreen: View {
    private enum Mode: Hashable {
        case dates
        case weekday
    }

    @Environment(CalendarSettingsModel.self) private var model
    @State private var mode: Mode = .dates
    @State private var start = Date.now
    @State private var end = Date.now
    @State private var label = ""
    @State private var weekday = Calendar.current.component(.weekday, from: .now)
    @State private var refusal: String?

    private var calendar: Calendar { .current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CalendarEditorHeader(
                    kicker: "CALENDAR",
                    title: "EXCEPTIONS",
                    summary: "A closed date plans no session and keeps its slot."
                )

                if model.settings.exceptions.isEmpty {
                    Text("No exceptions.")
                        .font(Theme.TypeScale.body)
                        .foregroundStyle(Theme.tertiaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(model.settings.exceptions) { exception in
                            exceptionRow(exception)
                        }
                    }
                }

                addForm
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func exceptionRow(_ exception: CalendarException) -> some View {
        editorCard(
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exception.label.isEmpty ? "CLOSED" : exception.label)
                        .font(Theme.TypeScale.rowTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CalendarCopy.exceptionWhen(exception, calendar: calendar))
                        .font(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    model.removeException(exception.id)
                } label: {
                    Image(systemName: "trash")
                        .font(Theme.TypeScale.body.weight(.semibold))
                        .foregroundStyle(Theme.destructive.opacity(0.75))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove exception")
            }
        )
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD A CLOSURE")
                .font(Theme.TypeScale.section.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryText)

            modeControl

            if mode == .dates {
                HStack(alignment: .top, spacing: 10) {
                    dateField("START", selection: $start)
                    dateField("END", selection: $end)
                }
            } else {
                weekdayPicker
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("LABEL")
                    .font(Theme.TypeScale.micro)
                    .tracking(1.0)
                    .foregroundStyle(Theme.secondaryText)
                TextField("Gym closed", text: $label)
                    .font(Theme.TypeScale.body)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.09), lineWidth: 1)
                    )
            }

            if let refusal {
                Text(refusal)
                    .font(Theme.TypeScale.meta.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                add()
            } label: {
                Text("ADD CLOSURE")
                    .font(Theme.TypeScale.action)
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Capsule().fill(Theme.setAccent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var modeControl: some View {
        HStack(spacing: 6) {
            modeButton("DATES", value: .dates)
            modeButton("WEEKDAY", value: .weekday)
            Spacer(minLength: 0)
        }
    }

    private func modeButton(_ title: String, value: Mode) -> some View {
        let selected = mode == value
        return Button {
            mode = value
            refusal = nil
        } label: {
            Text(title)
                .font(Theme.TypeScale.micro.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(selected ? Theme.ink : Theme.secondaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? Theme.setAccent : .white.opacity(0.04)))
                .overlay(
                    Capsule().stroke(selected ? .clear : .white.opacity(0.09), lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var weekdayPicker: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { number in
                let selected = weekday == number
                Button {
                    weekday = number
                    refusal = nil
                } label: {
                    Text(CalendarCopy.weekdayName(number, calendar: calendar))
                        .font(Theme.TypeScale.micro.weight(.bold))
                        .tracking(0.4)
                        .foregroundStyle(selected ? Theme.ink : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Circle().fill(selected ? Theme.setAccent : .white.opacity(0.04)))
                        .overlay(
                            Circle().stroke(selected ? .clear : .white.opacity(0.09), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func dateField(_ title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(Theme.TypeScale.micro)
                .tracking(1.0)
                .foregroundStyle(Theme.secondaryText)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.setAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        switch mode {
        case .dates:
            if model.addException(startDay: start, endDay: end, label: label) {
                refusal = nil
                label = ""
            } else {
                refusal = "THE END DATE IS BEFORE THE START DATE."
            }
        case .weekday:
            if model.addWeekdayException(weekday, label: label) {
                refusal = nil
                label = ""
            } else {
                refusal = "\(CalendarCopy.weekdayName(weekday, calendar: calendar)) IS ALREADY CLOSED."
            }
        }
    }
}
