import MessageUI
import SwiftUI

/// Reports a problem. Same route as a card request — the system mail composer —
/// so the two behave alike, and the device details are filled in rather than
/// asked for.
struct ReportIssueSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var steps = ""
    @State private var isShowingComposer = false
    @State private var fallbackMessage: String?

    private var canSend: Bool { !description.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What happened", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("What happened")
                } footer: {
                    Text("Required.")
                }

                Section("What you did just before") {
                    TextField("Steps", text: $steps, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    LabeledContent("App", value: IssueReport.appVersion)
                    LabeledContent("Device", value: IssueReport.deviceSummary)
                } header: {
                    Text("Included automatically")
                } footer: {
                    Text("Sent with your report so we don't have to ask.")
                }
            }
            .navigationTitle("Report an Issue")
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
            .sheet(isPresented: $isShowingComposer) {
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

    private var report: IssueReport {
        IssueReport(description: description, steps: steps)
    }

    private func send() {
        if MFMailComposeViewController.canSendMail() {
            isShowingComposer = true
            return
        }
        guard let url = report.mailtoURL else {
            fallbackMessage = "No mail account is set up on this device."
            return
        }
        UIApplication.shared.open(url) { opened in
            if !opened {
                fallbackMessage = "No mail account is set up on this device."
            } else {
                dismiss()
            }
        }
    }
}

/// Main-actor bound because it reads `UIDevice`; it is only ever built by a view.
@MainActor
struct IssueReport {
    var description: String
    var steps: String

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    static var deviceSummary: String {
        let device = UIDevice.current
        return "\(device.model), \(device.systemName) \(device.systemVersion)"
    }

    var subject: String { "SLT Cards issue report" }

    var body: String {
        var lines = ["What happened:", description.trimmed]
        if !steps.trimmed.isEmpty {
            lines.append("")
            lines.append("What they did just before:")
            lines.append(steps.trimmed)
        }
        lines.append("")
        lines.append("App: \(Self.appVersion)")
        lines.append("Device: \(Self.deviceSummary)")
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
