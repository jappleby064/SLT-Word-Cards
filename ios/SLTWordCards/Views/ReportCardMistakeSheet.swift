import MessageUI
import SwiftUI

/// Reports something wrong with a card in the shared set — the wrong picture, a
/// sound that doesn't match, a structure that's miscoded. Distinct from
/// `ReportIssueSheet`, which is about the app misbehaving rather than the
/// content being wrong.
///
/// The card's current values travel with the report, so a correction can be
/// checked against what the sender actually saw rather than what the catalogue
/// says by the time the mail is read.
struct ReportCardMistakeSheet: View {
    /// Pre-selected when the report is started from a card rather than Settings.
    var card: Card?

    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Card?
    @State private var faults: Set<CardMistakeReport.Fault> = []
    @State private var notes = ""
    @State private var isShowingComposer = false
    @State private var fallbackMessage: String?

    private var canSend: Bool {
        selected != nil && (!faults.isEmpty || !notes.trimmed.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CardChooser(selected: $selected)
                    } label: {
                        if let selected {
                            HStack(spacing: 12) {
                                CardThumbnail(card: selected)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.label)
                                    CardDetailLine(card: selected)
                                }
                            }
                        } else {
                            Label("Choose a card", systemImage: "magnifyingglass")
                        }
                    }
                } header: {
                    Text("Card")
                } footer: {
                    Text("Only cards from the shared set. Cards you made yourself are yours to edit under My cards.")
                }

                Section {
                    ForEach(CardMistakeReport.Fault.allCases) { fault in
                        Button {
                            if faults.contains(fault) {
                                faults.remove(fault)
                            } else {
                                faults.insert(fault)
                            }
                        } label: {
                            HStack {
                                Image(systemName: faults.contains(fault)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(faults.contains(fault) ? Color.accentColor : .secondary)
                                Text(fault.title)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("What's wrong")
                } footer: {
                    Text("Pick as many as apply, or leave them all and just describe it below.")
                }

                Section {
                    TextField("What it should be", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Details")
                } footer: {
                    Text("If you know the right answer — the correct sound, the picture it should be — saying so here is the quickest way to get it fixed.")
                }

                if let selected {
                    Section {
                        LabeledContent("Word", value: selected.word)
                        if !selected.initialSound.isEmpty {
                            LabeledContent("Word initial sound", value: selected.initialSound)
                        }
                        if !selected.finalSound.isEmpty {
                            LabeledContent("Word final sound", value: selected.finalSound)
                        }
                        if !selected.structure.isEmpty {
                            LabeledContent("Structure", value: selected.structure.uppercased())
                        }
                    } header: {
                        Text("Included automatically")
                    } footer: {
                        Text("What this card says on your device right now, sent so we can see exactly what you're looking at.")
                    }
                }
            }
            .navigationTitle("Report a Mistake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: send)
                        .fontWeight(.semibold)
                        .disabled(!canSend)
                }
            }
            .task {
                if selected == nil { selected = card }
            }
            .sheet(isPresented: $isShowingComposer) {
                if let report {
                    MailComposer(
                        recipient: CardRequest.recipient,
                        subject: report.subject,
                        body: report.body,
                        attachment: nil,
                        attachmentName: ""
                    ) { sent in
                        isShowingComposer = false
                        if sent { dismiss() }
                    }
                }
            }
            .alert("Can't send mail from here", isPresented: .init(
                get: { fallbackMessage != nil },
                set: { if !$0 { fallbackMessage = nil } }
            )) {
                Button("OK") { fallbackMessage = nil }
            } message: {
                Text(fallbackMessage ?? "")
            }
        }
    }

    private var report: CardMistakeReport? {
        guard let selected else { return nil }
        return CardMistakeReport(card: selected, faults: faults, notes: notes)
    }

    private func send() {
        guard let report else { return }
        if MFMailComposeViewController.canSendMail() {
            isShowingComposer = true
            return
        }
        guard let url = report.mailtoURL else {
            fallbackMessage = "No mail account is set up on this device."
            return
        }
        UIApplication.shared.open(url) { opened in
            if opened {
                dismiss()
            } else {
                fallbackMessage = "No mail account is set up on this device."
            }
        }
    }
}

/// Searchable list of the shared catalogue, filtered the same way the Search tab
/// is so a card is found the same way here as anywhere else.
private struct CardChooser: View {
    @Binding var selected: Card?

    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var criteria = SearchCriteria()

    private var results: [Card] {
        library.search(criteria).filter { !$0.isCustom }
    }

    var body: some View {
        List {
            Section("Filters") {
                CardFilterControls(criteria: $criteria, structures: library.structures)
            }

            Section(results.count == 1 ? "1 card" : "\(results.count) cards") {
                ForEach(results) { card in
                    Button {
                        selected = card
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            CardThumbnail(card: card)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.label)
                                    .foregroundStyle(Color.primary)
                                CardDetailLine(card: card)
                            }
                            Spacer()
                            if selected?.id == card.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $criteria.rawQuery, prompt: "Word or number")
        .navigationTitle("Choose a Card")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct CardMistakeReport {
    enum Fault: String, CaseIterable, Identifiable, Sendable {
        case picture
        case initialSound
        case finalSound
        case structure
        case spelling
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .picture: "The picture is wrong or unclear"
            case .initialSound: "The word initial sound is wrong"
            case .finalSound: "The word final sound is wrong"
            case .structure: "The structure is wrong"
            case .spelling: "The word is spelled wrong"
            case .other: "Something else"
            }
        }
    }

    var card: Card
    var faults: Set<Fault>
    var notes: String

    var subject: String { "Card mistake: \(card.word)" }

    var body: String {
        var lines = ["Card: \(card.label)"]
        if !card.initialSound.isEmpty { lines.append("Word initial sound: \(card.initialSound)") }
        if !card.finalSound.isEmpty { lines.append("Word final sound: \(card.finalSound)") }
        if !card.structure.isEmpty { lines.append("Structure: \(card.structure.uppercased())") }
        lines.append("Card id: \(card.id)")

        lines.append("")
        lines.append("What's wrong:")
        if faults.isEmpty {
            lines.append("- not specified")
        } else {
            // Listed in the order they appear on screen, not set order, so two
            // reports of the same thing read the same way.
            for fault in Fault.allCases where faults.contains(fault) {
                lines.append("- \(fault.title)")
            }
        }

        if !notes.trimmed.isEmpty {
            lines.append("")
            lines.append("Details:")
            lines.append(notes.trimmed)
        }

        lines.append("")
        lines.append("App: \(IssueReport.appVersion)")
        lines.append("Sent from SLT Cards.")
        return lines.joined(separator: "\n")
    }

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = CardRequest.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
