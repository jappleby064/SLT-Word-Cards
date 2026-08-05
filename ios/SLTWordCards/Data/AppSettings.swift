import Foundation

/// Which of the two ways the app is being used. Chosen on first launch and
/// changeable in Settings at any time; switching never deletes anything.
@Observable
@MainActor
final class AppSettings {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        /// Full library: learners, decks grouped under them, packs to send out.
        case teacher
        /// Personal decks only — no learners, no grouping — plus imported packs.
        case learner

        var id: String { rawValue }

        /// Reads a stored value, including the "therapist"/"client" raw values
        /// written before the rename, so an install that already chose keeps its
        /// choice instead of being sent back to the first-run chooser.
        static func stored(_ raw: String) -> Mode? {
            switch raw {
            case "therapist": .teacher
            case "client": .learner
            default: Mode(rawValue: raw)
            }
        }

        var title: String {
            switch self {
            case .teacher: "Teacher"
            case .learner: "Learner"
            }
        }

        var summary: String {
            switch self {
            case .teacher:
                "Organise decks under each learner, and send decks to them to practise with."
            case .learner:
                "Make your own decks and open the ones your teacher sends you."
            }
        }

        var symbol: String {
            switch self {
            case .teacher: "folder.badge.person.crop"
            case .learner: "person.crop.circle"
            }
        }
    }

    private static let modeKey = "appMode"
    private let defaults = UserDefaults.standard

    /// `nil` until the user has picked, which is what triggers the first-run
    /// chooser.
    var mode: Mode? {
        didSet { defaults.set(mode?.rawValue, forKey: Self.modeKey) }
    }

    var hasChosenMode: Bool { mode != nil }

    /// The effective mode for views that need one before a choice is made.
    var effectiveMode: Mode { mode ?? .teacher }

    init() {
        mode = defaults.string(forKey: Self.modeKey).flatMap(Mode.stored)
    }
}
