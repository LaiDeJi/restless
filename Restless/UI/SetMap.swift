import SwiftUI

/// The block map's rows and dots: one row per round of each movement, in run
/// order. Pure data so the timer and its tests cannot disagree about which dot
/// belongs to which set.
struct SetMapLayout: Equatable {
    struct Row: Equatable, Identifiable {
        let movementIndex: Int
        /// One-based round of that movement.
        let round: Int
        /// The 0-based run-order index of the row's first set in the block.
        let firstSet: Int
        /// A gap separates the movements, so the first row of every movement
        /// after the first carries one above it.
        let hasGapAbove: Bool

        var id: Int { firstSet }
    }

    /// Dots, not data: above these limits the block is drawn as a bar.
    static let maxRows = 12
    static let maxSetsPerRow = 12
    static let maxDots = 72

    let rows: [Row]
    let setsPerRow: Int
    let totalSets: Int
    /// The index into `rows` of the current set's row; nil in done, and on a bar.
    let activeRow: Int?
    let usesDots: Bool

    init(block: WorkoutBlock, position: WorkoutPosition, phase: SessionPhase) {
        let sets = max(block.setsPerRound, 1)
        let rounds = max(block.rounds, 1)
        let movementCount = block.movements.count
        let rowCount = safeProduct(movementCount, rounds)
        let total = safeProduct(rowCount, sets)

        setsPerRow = sets
        totalSets = total
        usesDots = movementCount > 0
            && rowCount <= Self.maxRows
            && sets <= Self.maxSetsPerRow
            && total <= Self.maxDots

        guard usesDots else {
            rows = []
            activeRow = nil
            return
        }

        var built: [Row] = []
        built.reserveCapacity(rowCount)
        for movementIndex in 0..<movementCount {
            for round in 1...rounds {
                let firstSet = safeProduct(
                    safeSum(safeProduct(movementIndex, rounds), round - 1),
                    sets
                )
                built.append(
                    Row(
                        movementIndex: movementIndex,
                        round: round,
                        firstSet: firstSet,
                        hasGapAbove: movementIndex > 0 && round == 1
                    )
                )
            }
        }
        rows = built

        if phase == .done {
            activeRow = nil
        } else {
            let movementIndex = min(max(position.movementIndex, 0), max(movementCount - 1, 0))
            let round = min(max(position.round, 1), rounds)
            activeRow = built.firstIndex {
                $0.movementIndex == movementIndex && $0.round == round
            }
        }
    }
}

struct SetMap: View {
    let snapshot: SessionSnapshot

    private var block: WorkoutBlock { snapshot.currentBlock }
    private var position: WorkoutPosition { snapshot.position }
    private var progress: BlockProgress { snapshot.blockProgress }

    private var layout: SetMapLayout {
        SetMapLayout(block: block, position: position, phase: snapshot.phase)
    }

    var body: some View {
        VStack(spacing: 9) {
            if layout.usesDots {
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
            ForEach(Array(layout.rows.enumerated()), id: \.element.id) { index, row in
                if row.hasGapAbove {
                    gap
                }
                HStack(spacing: 6) {
                    Text("R\(row.round)")
                        .font(Theme.TypeScale.micro)
                        .tracking(0.2)
                        .monospacedDigit()
                        .foregroundStyle(
                            index == layout.activeRow
                                ? .white.opacity(0.72)
                                : Theme.tertiaryText.opacity(0.85)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 27, alignment: .trailing)

                    HStack(spacing: 3) {
                        ForEach(1...layout.setsPerRow, id: \.self) { step in
                            dot(order: row.firstSet + step - 1)
                        }
                    }
                }
            }
        }
    }

    /// The gap between two movements.
    private var gap: some View {
        Color.clear
            .frame(height: 6)
    }

    private func dot(order: Int) -> some View {
        let isDone = order < progress.done
        let isCurrent = order == progress.done && snapshot.phase != .done

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
            .animation(.easeOut(duration: 0.3), value: progress.done)
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
                        .frame(width: proxy.size.width * progress.fraction)
                        .shadow(color: snapshot.accentColor.opacity(0.35), radius: 5)
                }
            }
            .frame(width: 220, height: 6)

            Text("\(progress.done) OF \(progress.total) SETS IN THIS BLOCK")
                .font(Theme.TypeScale.micro)
                .tracking(1.2)
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
        }
        .animation(.easeOut(duration: 0.3), value: progress.done)
    }
}
