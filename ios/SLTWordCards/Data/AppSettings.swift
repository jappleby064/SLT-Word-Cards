import Foundation

/// Which of the two ways the app is being used. Chosen on first launch and
/// changeable in Settings at any time; switching never deletes anything.
@Observable
@MainActor
final class AppSettings {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        /// Full library: clients, decks grouped under them, packs to send out.
        case therapist
        /// Personal decks only — no clients, no grouping — plus imported packs.
        case client

        var id: String { rawValue }

        var title: String {
            switch self {
            case .therapist: "Therapist"
            case .client: "Client"
            }
        }

        var summary: String {
            switch self {
            case .therapist:
                "Organise decks under each client, and send decks to them to practise with."
            case .client:
                "Make your own decks and open the ones your therapist sends you."
            }
        }

        var symbol: String {
            switch self {
            case .therapist: "folder.badge.person.crop"
            case .client: "person.crop.circle"
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
    var effectiveMode: Mode { mode ?? .therapist }

    init() {
        mode = defaults.string(forKey: Self.modeKey).flatMap(Mode.init(rawValue:))
    }
}
