import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CardLibrary.self) private var library
    @Environment(DeckLibrary.self) private var decks
    @Environment(ContentSync.self) private var sync
    @Environment(CustomCardStore.self) private var customCards

    @State private var pendingMode: AppSettings.Mode?
    @State private var isRequestingCard = false
    @State private var isReportingIssue = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: modeSelection) {
                        ForEach(AppSettings.Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(settings.effectiveMode.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Mode")
                } footer: {
                    Text("Switching modes never deletes anything. Decks filed under a client stay saved and reappear in Therapist mode.")
                }

                Section("Cards") {
                    LabeledContent("Cards available", value: "\(library.cards.count)")

                    NavigationLink {
                        MyCardsView()
                    } label: {
                        LabeledContent("My cards", value: "\(customCards.cards.count)")
                    }

                    Button {
                        isRequestingCard = true
                    } label: {
                        Label("Request a Card…", systemImage: "envelope")
                    }

                    Button {
                        Task { await sync.sync(library: library) }
                    } label: {
                        HStack {
                            Text("Check for new cards")
                            Spacer()
                            if sync.status == .checking {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(sync.status == .checking)

                    Text(syncDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Decks saved", value: "\(decks.totalDeckCount)")
                    LabeledContent("Storage", value: decks.location == .iCloud ? "iCloud Drive" : "This device")
                } header: {
                    Text("Decks")
                } footer: {
                    Text(decks.location == .iCloud
                         ? "Decks are kept in your private iCloud Drive and appear on your other devices. They are never shared with anyone else."
                         : "Decks are kept on this device. Sign in to iCloud to have them follow you between your own devices.")
                }

                Section("About") {
                    LabeledContent("Version", value: versionString)
                    Button {
                        isReportingIssue = true
                    } label: {
                        Label("Report an Issue…", systemImage: "exclamationmark.bubble")
                    }
                    Link("speakeasy-slt.uk", destination: URL(string: "https://speakeasy-slt.uk/")!)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isRequestingCard) {
                RequestCardSheet()
            }
            .sheet(isPresented: $isReportingIssue) {
                ReportIssueSheet()
            }
            .alert("Switch to \(pendingMode?.title ?? "") mode?", isPresented: showsModeConfirmation) {
                Button("Cancel", role: .cancel) { pendingMode = nil }
                Button("Switch") {
                    if let pendingMode { settings.mode = pendingMode }
                    pendingMode = nil
                }
            } message: {
                Text(pendingMode?.switchWarning ?? "")
            }
        }
    }

    /// Routes changes through a confirmation rather than switching instantly, so
    /// a mistap doesn't hide someone's whole client list mid-session.
    private var modeSelection: Binding<AppSettings.Mode> {
        Binding(
            get: { settings.effectiveMode },
            set: { newValue in
                guard newValue != settings.effectiveMode else { return }
                pendingMode = newValue
            }
        )
    }

    private var showsModeConfirmation: Binding<Bool> {
        Binding(
            get: { pendingMode != nil },
            set: { if !$0 { pendingMode = nil } }
        )
    }

    private var syncDescription: String {
        switch sync.status {
        case .idle: "Cards are ready to use offline."
        case .checking: "Checking…"
        case .upToDate(let date): "Up to date. Last checked \(date.formatted(date: .abbreviated, time: .shortened))."
        case .updated(let cards, let images, _):
            images > 0
                ? "Updated to \(cards) cards and downloaded \(images) new pictures."
                : "Updated to \(cards) cards."
        case .offline: "Offline. Using the cards saved on this device."
        case .failed(let message): "Couldn't check: \(message)"
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private extension AppSettings.Mode {
    var switchWarning: String {
        switch self {
        case .therapist:
            "Client mode's decks stay where they are, and your client folders become visible again."
        case .client:
            "Your client folders stay saved but are hidden. You'll see only your own decks and the ones sent to you."
        }
    }
}
