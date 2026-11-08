import SwiftUI

@MainActor
struct WatchRootView: View {
    @State private var model = WatchSessionModel()
    @State private var showLab = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 5) {
                    Text("RESTLESS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.setAccent)

                    if let count = model.countText {
                        Text(count)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: count)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    Text(model.title)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(model.phase == .unavailable ? Theme.roundAccent : Theme.secondaryText)

                    Text(model.note)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if model.phase == .ready {
                        Button("LAB") {
                            showLab = true
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.secondaryText)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            model.activate()
        }
        .onChange(of: scenePhase) { _, phase in
            model.setForeground(phase == .active)
        }
        .sheet(isPresented: $showLab) {
            RepLabView()
        }
    }
}
