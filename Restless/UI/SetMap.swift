import SwiftUI

struct SetMap: View {
    let snapshot: SessionSnapshot

    /// Presentation limits, not data limits: above 72 dots the block is a bar.
    private let maxRounds = 12
    private let maxPerRound = 12
    private let maxDots = 72

    private var block: WorkoutBlock { snapshot.currentBlock }
    private var position: WorkoutPosition { snapshot.position }

    private var blockStart: Int {
        snapshot.preset.blocks
            .prefix(position.blockIndex)
            .reduce(0) { safeSum($0, $1.totalSets) }
    }

    private var doneInBlock: Int {
        min(max(snapshot.doneSets - blockStart, 0), block.totalSets)
    }

    private var setsPerRound: Int { max(block.setsPerRound, 1) }

    private var perRound: Int {
        max(block.movements.count, 1) * setsPerRound
    }

    private var usesDots: Bool {
        block.rounds <= maxRounds &&
            perRound <= maxPerRound &&
            block.totalSets <= maxDots
    }

    var body: some View {
        VStack(spacing: 9) {
            if usesDots {
                dotGrid
            } else {
                progressBar
            }

            Text("\(snapshot.doneSets) OF \(plural(snapshot.totalSets, "SET", "SETS"))")
                .font(Theme.TypeScale.micro)
                .tracking(1.2)
                .monospacedDigit()
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    // MARK: Dots

    private var dotGrid: some View {
        VStack(spacing: 7) {
            ForEach(1...max(block.rounds, 1), id: \.self) { round in
                HStack(spacing: 6) {
                    Text("R\(round)")
                        .font(Theme.TypeScale.micro)
                        .tracking(0.2)
                        .monospacedDigit()
                        .foregroundStyle(
                            round == position.round && snapshot.phase != .done
                                ? .white.opacity(0.72)
                                : Theme.tertiaryText.opacity(0.85)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 27, alignment: .trailing)

                    HStack(spacing: 3) {
                        ForEach(Array(block.movements.enumerated()), id: \.element.id) { index, _ in
                            if index > 0 {
                                gap
                            }
                            ForEach(1...setsPerRound, id: \.self) { step in
                                dot(round: round, movementIndex: index, step: step)
                            }
                        }
                    }
                }
            }
        }
    }

    private var gap: some View {
        Color.clear
            .frame(width: 5, height: 1)
    }

    private func dot(round: Int, movementIndex: Int, step: Int) -> some View {
        let order = (round - 1) * perRound + movementIndex * setsPerRound + (step - 1)
        let isDone = order < doneInBlock
        let isCurrent = order == doneInBlock && snapshot.phase != .done

        return Circle()
            .fill(isDone ? Color.white.opacity(0.7) : Color.white.opacity(0.11))
            .frame(width: 6, height: 6)
            .overlay {
                if isCurrent {
                    Circle()
                        .stroke(snapshot.accentColor, lineWidth: 1.5)
                        .frame(width: 9.5, height: 9.5)
                        .shadow(color: snapshot.accentColor.opacity(0.5), radius: 4)
                }
            }
            .scaleEffect(isCurrent ? 1.18 : 1)
            .animation(.easeOut(duration: 0.3), value: doneInBlock)
    }

    // MARK: Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(snapshot.accentColor)
                        .frame(width: proxy.size.width * fraction)
                        .shadow(color: snapshot.accentColor.opacity(0.35), radius: 5)
                }
            }
            .frame(width: 220, height: 6)

            Text("\(doneInBlock) OF \(block.totalSets) SETS IN THIS BLOCK")
                .font(Theme.TypeScale.micro)
                .tracking(1.2)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
        }
        .animation(.easeOut(duration: 0.3), value: doneInBlock)
    }

    private var fraction: Double {
        guard block.totalSets > 0 else { return 0 }
        return min(max(Double(doneInBlock) / Double(block.totalSets), 0), 1)
    }
}
