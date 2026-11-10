import SwiftUI

enum Theme {
    static let background = Color(red: 0.027, green: 0.027, blue: 0.031)
    static let roundBackground = Color(red: 0.039, green: 0.031, blue: 0.020)
    static let setAccent = Color(red: 0.784, green: 1.0, blue: 0.302)
    static let roundAccent = Color(red: 1.0, green: 0.722, blue: 0.302)
    /// The one red used by every delete action: DELETE SESSION, block and
    /// movement row deletes, and REMOVE FROM BLOCK.
    static let destructive = Color(red: 1.0, green: 0.361, blue: 0.302)
    static let secondaryText = Color.white.opacity(0.38)
    static let tertiaryText = Color.white.opacity(0.26)
    static let hairline = Color.white.opacity(0.11)
    static let ink = Color(red: 0.027, green: 0.027, blue: 0.031)

    /// Named roles over SwiftUI's semantic text styles. Text scales with the
    /// system text size, and the same role means the same style on every screen
    /// and in the widget. Tracking and weight live with the call site; only
    /// `Font` here, so the widget target can compile this file.
    enum TypeScale {
        /// SESSIONS page title. Default 34.
        static let screenTitle = Font.largeTitle.weight(.semibold)
        /// Editable session or block name. Default 28.
        static let pageTitle = Font.title.weight(.semibold)
        /// Eyebrows, SESSION/BLOCKS kickers, uppercase session header. Default 13.
        static let section = Font.footnote.weight(.semibold)
        /// Card name, block row name, widget movement name. Default 17.
        static let rowTitle = Font.headline.weight(.semibold)
        /// Stepper values. Default 20.
        static let value = Font.title3.weight(.semibold)
        /// Summaries, back/Done, explanatory copy. Default 15.
        static let body = Font.subheadline
        /// Card/block meta, subtitles, badges, footer copy. Default 13.
        static let meta = Font.footnote
        /// Timer kicker, position strip, chips. Default 12.
        static let label = Font.caption.weight(.semibold)
        /// Set-map labels, progress counts, ACTIVE badge. Default 11.
        static let micro = Font.caption2.weight(.semibold)
        /// Primary buttons. Default 17.
        static let action = Font.headline.weight(.bold)
        /// EDIT, back, DONE, add/delete. Default 13.
        static let compactAction = Font.footnote.weight(.semibold)
    }
}

extension SessionSnapshot {
    var isRoundAccent: Bool {
        switch phase {
        case .resting, .paused:
            if let transition = restTransition { return !transition.isSetAccent }
            return restKind == .round
        case .ready:
            guard let rest = upcomingRest else { return false }
            return !rest.transition.isSetAccent
        case .notStarted, .performing, .done:
            return false
        }
    }

    var accentColor: Color { isRoundAccent ? Theme.roundAccent : Theme.setAccent }

    var surfaceColor: Color { isRoundAccent ? Theme.roundBackground : Theme.background }
}

extension SessionSnapshot {
    var kicker: String {
        switch phase {
        case .notStarted:
            return "READY"
        case .ready:
            guard let rest = upcomingRest else { return "LAST SET" }
            return rest.isZero ? "NO REST" : rest.kind.label
        case .performing:
            return "WORK"
        case .resting:
            return restKind?.label ?? "REST"
        case .paused:
            return "PAUSED"
        case .done:
            return "\(doneSets) OF \(plural(totalSets, "SET", "SETS"))"
        }
    }

    var subtitle: String {
        switch phase {
        case .notStarted:
            return "\(plural(preset.blocks.count, "BLOCK", "BLOCKS")) · \(plural(totalSets, "SET", "SETS")) · \(durationString(preset.totalRest)) TOTAL REST"
        case .ready:
            return upcomingRest == nil ? "NO REST AFTER" : "AFTER THIS SET"
        case .performing:
            guard let rest = upcomingRest else { return "NO REST AFTER" }
            return rest.isZero ? "NEXT SET IMMEDIATELY" : "REST \(clockString(rest.duration)) AFTER"
        case .resting, .paused:
            return restContext
        case .done:
            return "\(plural(preset.blocks.count, "BLOCK", "BLOCKS")) · \(plural(preset.movementCount, "MOVEMENT", "MOVEMENTS")) · \(durationString(preset.totalRest)) TOTAL REST"
        }
    }

    /// True when the running rest follows the final set of a block and another
    /// block follows: the block's round rest covers the transition.
    var isBlockTransition: Bool { restTransition == .block }

    /// What the rest just completed was attached to. `movementName` resolves the
    /// library names for a movement switch; without it the copy names the block.
    func restContext(movementName: ((UUID) -> String)? = nil) -> String {
        guard let transition = restTransition else { return "" }
        let finished = preset.position(at: max(0, doneSets - 1))
        switch transition {
        case .set:
            return "AFTER SET \(finished.set)"
        case .round:
            return "AFTER ROUND \(finished.round)"
        case .movement:
            guard preset.blocks.indices.contains(finished.blockIndex) else { return "" }
            let block = preset.blocks[finished.blockIndex]
            guard let movementName else {
                return "AFTER \(finished.blockName.uppercased()) · NEXT MOVEMENT"
            }
            let finishedName = movementName(finished.movementId).uppercased()
            let nextIndex = finished.movementIndex + 1
            guard block.movements.indices.contains(nextIndex) else {
                return "AFTER \(finishedName)"
            }
            let nextName = movementName(block.movements[nextIndex].movementId).uppercased()
            return "AFTER \(finishedName) · NEXT \(nextName)"
        case .block:
            let nextIndex = finished.blockIndex + 1
            guard preset.blocks.indices.contains(nextIndex) else { return "" }
            return "AFTER \(finished.blockName.uppercased()) · NEXT \(preset.blocks[nextIndex].name.uppercased())"
        }
    }

    var restContext: String { restContext(movementName: nil) }

    var primaryTitle: String {
        switch phase {
        case .notStarted:
            return "START SESSION"
        case .ready:
            return currentBlockMovement?.endCondition == .time ? "START" : "SET DONE"
        case .performing:
            return "SET DONE"
        case .resting:
            return "PAUSE"
        case .paused:
            return "RESUME"
        case .done:
            return "START AGAIN"
        }
    }

    var primarySubtitle: String {
        switch phase {
        case .notStarted:
            let name = preset.blocks.first?.name.uppercased() ?? ""
            return "BLOCK 1 · \(name)"
        case .ready:
            if currentBlockMovement?.endCondition == .time {
                return "\(clockString(currentBlockMovement?.target ?? 0)) HOLD"
            }
            guard let rest = upcomingRest else { return "NO REST AFTER" }
            return rest.isZero
                ? "NEXT SET IMMEDIATELY"
                : "START \(clockString(rest.duration)) \(rest.kind.shortLabel) REST"
        case .performing:
            guard let rest = upcomingRest else { return "FINISH AFTER THIS SET" }
            return rest.isZero ? "NEXT SET IMMEDIATELY" : "REST \(clockString(rest.duration)) AFTER"
        case .resting:
            return restKind?.label ?? ""
        case .paused:
            return "TAP TO RESUME"
        case .done:
            return "\(plural(totalSets, "SET", "SETS")) · \(durationString(preset.totalRest)) TOTAL REST"
        }
    }

    var primaryAction: SessionAction {
        switch phase {
        case .notStarted:
            return .startSession
        case .ready:
            return currentBlockMovement?.endCondition == .time ? .startSet : .setDone
        case .performing:
            return .setDone
        case .resting:
            return .pause
        case .paused:
            return .resume
        case .done:
            return .restart
        }
    }

    var usesSmallHero: Bool {
        switch phase {
        case .notStarted:
            return true
        case .ready:
            guard let rest = upcomingRest else { return true }
            return rest.isZero
        case .performing:
            return false
        case .done:
            return true
        case .resting, .paused:
            return false
        }
    }

    var secondsRemainingNow: Int {
        Int(remaining(at: .now).rounded(.up))
    }

    var secondsRemainingSetNow: Int {
        Int(setRemaining(at: .now).rounded(.up))
    }
}
