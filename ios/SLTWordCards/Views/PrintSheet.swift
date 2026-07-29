import PDFKit
import SwiftUI

/// Export for print: the same A4 3×4 sheet the web app produces, with the
/// "instances of each card" duplicate control.
struct PrintSheet: View {
    let cards: [Card]
    let initialCopies: Int
    let jobName: String
    /// Called when the user changes the copy count, so a deck can remember it.
    var onCopiesChange: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var copies = 1
    @State private var document: PDFDocument?
    @State private var fileURL: URL?
    @State private var isRendering = false
    @State private var errorMessage: String?

    private var totalCards: Int { cards.count * max(1, copies) }
    private var pageCount: Int { PrintLayout.pageCount(cardCount: totalCards) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                Divider()
                settings
            }
            .navigationTitle("Print Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task {
                copies = max(1, initialCopies)
                render()
            }
            .onChange(of: copies) { _, newValue in
                onCopiesChange?(newValue)
                render()
            }
            .alert("Couldn't build the PDF", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var preview: some View {
        ZStack {
            Color(.systemGroupedBackground)

            if let document {
                PDFPreview(document: document)
            } else if isRendering {
                ProgressView("Laying out cards…")
            } else {
                ContentUnavailableView(
                    "Nothing to print",
                    systemImage: "printer.dotmatrix",
                    description: Text("Select at least one card.")
                )
            }
        }
    }

    private var settings: some View {
        VStack(spacing: 14) {
            Stepper(value: $copies, in: 1...20) {
                HStack {
                    Text("Copies of each card")
                    Spacer()
                    Text("\(copies)")
                        .font(.body.monospacedDigit().weight(.semibold))
                }
            }

            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                printNow()
            } label: {
                Label("Print…", systemImage: "printer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(fileURL == nil)
        }
        .padding()
        .background(.bar)
    }

    private var summary: String {
        let cardWord = cards.count == 1 ? "card" : "cards"
        let pageWord = pageCount == 1 ? "page" : "pages"
        return "\(cards.count) \(cardWord) × \(copies) = \(totalCards) on \(pageCount) A4 \(pageWord), 12 per page at 56.7mm."
    }

    private func render() {
        guard !cards.isEmpty else {
            document = nil
            fileURL = nil
            return
        }
        isRendering = true
        do {
            let url = try PrintLayout.renderPDF(cards: cards, copies: copies, fileName: jobName)
            fileURL = url
            document = PDFDocument(url: url)
        } catch {
            errorMessage = error.localizedDescription
            document = nil
            fileURL = nil
        }
        isRendering = false
    }

    private func printNow() {
        guard let fileURL else { return }
        AirPrint.present(url: fileURL, jobName: jobName)
    }
}

/// Read-only PDF preview so the sheet can be checked before printing.
private struct PDFPreview: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemGroupedBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}

/// AirPrint entry point. iPad needs a presentation anchor, iPhone does not.
enum AirPrint {
    @MainActor
    static func present(url: URL, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        info.orientation = .portrait
        controller.printInfo = info
        controller.printingItem = url

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
            controller.present(animated: true, completionHandler: nil)
            return
        }

        // iPad and Mac require a presentation anchor; iPhone does not.
        if UIDevice.current.userInterfaceIdiom == .phone {
            controller.present(animated: true, completionHandler: nil)
        } else {
            let anchor = CGRect(x: window.bounds.midX, y: window.bounds.maxY - 80, width: 1, height: 1)
            controller.present(from: anchor, in: window, animated: true, completionHandler: nil)
        }
    }
}
