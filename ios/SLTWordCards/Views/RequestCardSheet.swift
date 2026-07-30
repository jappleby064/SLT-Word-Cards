import MessageUI
import PhotosUI
import SwiftUI

/// Asks for a card to be added to the shared set. Collects the same criteria a
/// card needs, with the picture optional and the rest required, and sends it on.
struct RequestCardSheet: View {
    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var word = ""
    @State private var initialSound = ""
    @State private var finalSound = ""
    @State private var structure = ""
    @State private var kind: Card.Kind = .word
    @State private var notes = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var isShowingComposer = false
    @State private var fallbackMessage: String?

    private var canSend: Bool {
        !word.trimmed.isEmpty
            && !initialSound.trimmed.isEmpty
            && !finalSound.trimmed.isEmpty
            && !structure.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Word", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Type", selection: $kind) {
                        Text("Word").tag(Card.Kind.word)
                        Text("Number").tag(Card.Kind.number)
                    }
                } header: {
                    Text("Card")
                }

                Section {
                    IPASoundField(title: "Word initial sound", symbol: $initialSound)
                    IPASoundField(title: "Word final sound", symbol: $finalSound)
                    Picker("Structure", selection: $structure) {
                        Text("Choose…").tag("")
                        ForEach(structureOptions, id: \.self) { option in
                            Text(option.uppercased()).tag(option)
                        }
                    }
                } header: {
                    Text("Sounds and structure")
                } footer: {
                    Text("All required — they're what the card is found by.")
                }

                Section {
                    picturePicker
                } header: {
                    Text("Picture")
                } footer: {
                    Text("Optional. A square image works best; it will be squared off to 500×500 either way.")
                }

                Section("Anything else") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Request a Card")
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
            .onChange(of: pickedItem) { _, item in
                Task { await loadPicked(item) }
            }
            .sheet(isPresented: $isShowingComposer) {
                MailComposer(
                    recipient: CardRequest.recipient,
                    subject: request.subject,
                    body: request.body,
                    attachment: pickedImage.flatMap { CardImageProcessor.standardise($0).jpegData(compressionQuality: 0.9) },
                    attachmentName: "\(word.trimmed.isEmpty ? "card" : word.trimmed).jpg"
                ) { sent in
                    isShowingComposer = false
                    if sent { dismiss() }
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

    @ViewBuilder
    private var picturePicker: some View {
        // Read once, outside the picker's label: that closure is @Sendable and so
        // can't touch main-actor state.
        let current = pickedImage

        if let current {
            Image(uiImage: current)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 160, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        PhotosPicker(selection: $pickedItem, matching: .images) {
            Label(current == nil ? "Attach a Picture" : "Choose a Different Picture",
                  systemImage: "paperclip")
        }

        if current != nil {
            Button(role: .destructive) {
                pickedImage = nil
                pickedItem = nil
            } label: {
                Label("Remove Picture", systemImage: "xmark.circle")
            }
        }
    }

    private var request: CardRequest {
        CardRequest(
            word: word,
            kind: kind,
            initialSound: initialSound,
            finalSound: finalSound,
            structure: structure,
            notes: notes,
            hasImage: pickedImage != nil
        )
    }

    private var structureOptions: [String] {
        var options = Set(library.structures)
        if !structure.isEmpty { options.insert(structure) }
        return options.sorted { ($0.count, $0) < ($1.count, $1) }
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        pickedImage = image
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() {
            isShowingComposer = true
            return
        }
        // No mail account set up — hand off to whatever does handle mail. The
        // picture can't ride along this way, so say so rather than dropping it
        // silently.
        guard let url = request.mailtoURL else {
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

/// The contents of a card request, in one place so the app and the mail body
/// can't drift apart.
struct CardRequest {
    static let recipient = "james@applebytechnical.com"

    var word: String
    var kind: Card.Kind
    var initialSound: String
    var finalSound: String
    var structure: String
    var notes: String
    var hasImage: Bool

    var subject: String {
        "Card request: \(word.trimmed)"
    }

    var body: String {
        var lines = [
            "Word: \(word.trimmed)",
            "Type: \(kind.rawValue)",
            "Word initial sound: \(initialSound.trimmed)",
            "Word final sound: \(finalSound.trimmed)",
            "Structure: \(structure.trimmed.uppercased())",
            "Image attached: \(hasImage ? "yes" : "no")"
        ]
        if !notes.trimmed.isEmpty {
            lines.append("")
            lines.append("Notes:")
            lines.append(notes.trimmed)
        }
        lines.append("")
        lines.append("Sent from SLT Cards.")
        return lines.joined(separator: "\n")
    }

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

/// Minimal wrapper around the system mail composer. Shared by the card request
/// and the issue report.
struct MailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let attachment: Data?
    let attachmentName: String
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        if let attachment {
            controller.addAttachmentData(attachment, mimeType: "image/jpeg", fileName: attachmentName)
        }
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result == .sent)
        }
    }
}
