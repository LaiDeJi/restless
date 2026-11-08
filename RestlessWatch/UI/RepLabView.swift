import SwiftUI

@MainActor
struct RepLabView: View {
    @State private var model = RepLabModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 5) {
                    Text("CURL LAB")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.setAccent)

                    Text("\(model.reps)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: model.reps)

                    Text("REPS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.secondaryText)

                    Text(model.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)

                    if model.phase == .active || model.phase == .calibrating {
                        Text("\(Int(model.angle))°")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Button(model.primaryTitle) {
                        model.performPrimaryAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.setAccent)
                    .foregroundStyle(Theme.ink)
                    .disabled(model.phase == .saving)
                    .padding(.top, 2)

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    if !model.transferNote.isEmpty {
                        Text(model.transferNote)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.tertiaryText)
                            .multilineTextAlignment(.center)
                    }

                    Text("Watch arm only · keep screen on")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 2)
            }
        }
        .task {
            WatchLinkSession.shared.activate()
        }
    }
}
