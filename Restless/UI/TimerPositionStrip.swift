import SwiftUI

/// The segments of the timer's one-line position strip. Pure so the copy rules
/// are testable without a view: the active block is named once, `BLOCK n OF m`
/// is gone, and the round and set groups appear only when their count is more
/// than one.
struct TimerPositionCopy: Equatable {
    enum Kind: Equatable {
        case upNext
        case blockName
        case movementName
        case roundLabel
        case roundValue
        case roundTotal
        case setLabel
        case setValue
        case setTotal
    }

    struct Segment: Equatable {
        let text: String
        let kind: Kind
    }

    /// One visual unit; separators sit between groups, never inside one, so
    /// `ROUND 2 OF 4` reads as one segment.
    struct Group: Equatable {
        let segments: [Segment]
    }

    let leading: [Group]
    let trailing: [Group]

    init(snapshot: SessionSnapshot, movementName: String) {
        let block = snapshot.currentBlock
        let position = snapshot.position
        let copy = position.roundSetCopy(in: block)
        let blockName = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let movement = movementName.trimmingCharacters(in: .whitespacesAndNewlines)

        var leading: [Group] = []
        if snapshot.isResting {
            leading.append(Group(segments: [Segment(text: "UP NEXT", kind: .upNext)]))
        }
        // A multi-block plan already names the active block in the block strip.
        // A single block names itself only when that says more than the
        // movement name does.
        if snapshot.preset.blocks.count == 1,
           blockName.caseInsensitiveCompare(movement) != .orderedSame {
            leading.append(
                Group(segments: [Segment(text: blockName.uppercased(), kind: .blockName)])
            )
        }
        leading.append(
            Group(segments: [Segment(text: movement.uppercased(), kind: .movementName)])
        )

        var trailing: [Group] = []
        if copy.roundText != nil {
            trailing.append(
                Group(segments: [
                    Segment(text: "ROUND", kind: .roundLabel),
                    Segment(text: "\(position.round)", kind: .roundValue),
                    Segment(text: "OF \(copy.rounds)", kind: .roundTotal)
                ])
            )
        }
        if copy.setText != nil {
            trailing.append(
                Group(segments: [
                    Segment(text: "SET", kind: .setLabel),
                    Segment(text: "\(position.set)", kind: .setValue),
                    Segment(text: "OF \(copy.setsPerRound)", kind: .setTotal)
                ])
            )
        }

        self.leading = leading
        self.trailing = trailing
    }
}

/// The timer's position strip. Kept out of `TimerScreen` so the shared copy has
/// one home and the screen body stays readable.
struct TimerPositionStrip: View {
    let snapshot: SessionSnapshot
    let movementName: String

    var body: some View {
        let copy = TimerPositionCopy(snapshot: snapshot, movementName: movementName)
        ViewThatFits(in: .horizontal) {
            line(copy, stacked: false)
            line(copy, stacked: true)
        }
        .frame(minHeight: 24)
    }

    private func line(_ copy: TimerPositionCopy, stacked: Bool) -> some View {
        Group {
            if stacked {
                VStack(spacing: 3) {
                    ForEach(Array((copy.leading + copy.trailing).enumerated()), id: \.offset) { _, group in
                        groupView(group)
                    }
                }
            } else {
                separated(copy.leading + copy.trailing)
            }
        }
        .modifier(PositionLineStyle(wraps: stacked))
    }

    private func separated(_ groups: [TimerPositionCopy.Group]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    separator
                }
                groupView(group)
            }
        }
    }

    private func groupView(_ group: TimerPositionCopy.Group) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(group.segments.enumerated()), id: \.offset) { _, segment in
                Text(segment.text)
                    .foregroundStyle(color(for: segment.kind))
            }
        }
    }

    private func color(for kind: TimerPositionCopy.Kind) -> Color {
        switch kind {
        case .upNext:
            snapshot.accentColor
        case .blockName:
            .white.opacity(0.5)
        case .movementName, .roundValue, .setValue:
            .white
        case .roundLabel, .setLabel:
            Theme.secondaryText
        case .roundTotal, .setTotal:
            Theme.tertiaryText
        }
    }

    private var separator: some View {
        Circle()
            .fill(.white.opacity(0.16))
            .frame(width: 3, height: 3)
    }
}

private struct PositionLineStyle: ViewModifier {
    /// The single-line candidate keeps its ideal width so `ViewThatFits` can
    /// reject it; the stacked candidate may wrap its text at accessibility
    /// sizes instead of clipping at the edge.
    let wraps: Bool

    func body(content: Content) -> some View {
        content
            .font(Theme.TypeScale.label)
            .tracking(0.8)
            .lineLimit(wraps ? nil : 1)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: !wraps, vertical: true)
    }
}
