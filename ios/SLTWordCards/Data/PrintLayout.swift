import UIKit

/// A4 card-sheet renderer, a direct port of `generatePDF` in `app.js` — which in
/// turn mirrors the original PyQt `QPrinter` logic. Geometry is kept in
/// millimetres and converted to points at the last moment so the numbers below
/// can be read against the web app line for line.
enum PrintLayout {
    // Millimetres, exactly as in app.js.
    static let pageWidth: Double = 210
    static let pageHeight: Double = 297
    static let marginX: Double = pageWidth * 0.05          // 10.5mm
    static let marginY: Double = pageHeight * 0.05         // 14.85mm
    static let columns = 3
    static let rows = 4
    static var cardsPerPage: Int { columns * rows }        // 12
    static var cellWidth: Double { (pageWidth - 2 * marginX) / Double(columns) }   // 63mm
    static var cellHeight: Double { (pageHeight - 2 * marginY) / Double(rows) }    // 66.825mm
    static var cardSize: Double { min(cellWidth, cellHeight) * 0.9 }              // 56.7mm
    static let borderWidth: Double = 0.3

    private static let pointsPerMillimetre = 72.0 / 25.4

    private static func pt(_ millimetres: Double) -> Double {
        millimetres * pointsPerMillimetre
    }

    /// The full print run: the whole selection repeated `copies` times, in the
    /// same order as the web app (ABC ABC ABC, not AAA BBB CCC).
    static func printRun(for cards: [Card], copies: Int) -> [Card] {
        let count = max(1, copies)
        return Array(repeating: cards, count: count).flatMap(\.self)
    }

    static func pageCount(cardCount: Int) -> Int {
        max(1, Int(ceil(Double(cardCount) / Double(cardsPerPage))))
    }

    /// Renders the sheet to a PDF file in the temporary directory and returns it.
    static func renderPDF(cards: [Card], copies: Int, fileName: String) throws -> URL {
        let items = printRun(for: cards, copies: copies)
        guard !items.isEmpty else { throw PrintError.nothingToPrint }

        let pageRect = CGRect(x: 0, y: 0, width: pt(pageWidth), height: pt(pageHeight))
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: fileName,
            kCGPDFContextCreator as String: "SLT Word Cards"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            for (offset, card) in items.enumerated() {
                let slot = offset % cardsPerPage
                if slot == 0 { context.beginPage() }

                let column = slot % columns
                let row = slot / columns

                // Centre the card within its grid cell.
                let cardX = marginX + Double(column) * cellWidth + (cellWidth - cardSize) / 2
                let cardY = marginY + Double(row) * cellHeight + (cellHeight - cardSize) / 2
                let frame = CGRect(x: pt(cardX), y: pt(cardY), width: pt(cardSize), height: pt(cardSize))

                if let faceText = card.faceText {
                    draw(numberText: faceText, in: frame)
                } else if let name = card.imageName, let image = ImageLoader.shared.image(named: name) {
                    image.draw(in: frame)
                }

                // Every card gets the cut border.
                let cgContext = context.cgContext
                cgContext.setStrokeColor(UIColor.black.cgColor)
                cgContext.setLineWidth(pt(borderWidth))
                cgContext.stroke(frame)
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(sanitise(fileName)).pdf", directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Large centred numeral or number word, fitted to the card the way jsPDF
    /// sizes it: scale by width, capped by height.
    private static func draw(numberText text: String, in frame: CGRect) {
        let maxDimension = pt(cardSize * 0.76)   // margin inside the border

        let probeSize = 100.0
        let probeFont = font(ofSize: probeSize)
        let widthAtProbe = (text as NSString)
            .size(withAttributes: [.font: probeFont]).width
        guard widthAtProbe > 0 else { return }

        let sizeByWidth = maxDimension / widthAtProbe * probeSize
        let fontSize = min(sizeByWidth, maxDimension)
        let resolved = font(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: resolved,
            .foregroundColor: UIColor.black
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)

        // Optically centre on the cap height rather than the line box, so a "7"
        // sits in the middle of the card like it does in the web PDF.
        let capHeight = resolved.capHeight
        let origin = CGPoint(
            x: frame.midX - textSize.width / 2,
            y: frame.midY - capHeight / 2 - resolved.ascender + capHeight
        )
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    private static func font(ofSize size: Double) -> UIFont {
        // app.js uses Helvetica Bold; it ships with iOS.
        UIFont(name: "Helvetica-Bold", size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }

    private static func sanitise(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
            .trimmed
        return cleaned.isEmpty ? "word-cards" : cleaned
    }

    enum PrintError: LocalizedError {
        case nothingToPrint

        var errorDescription: String? {
            switch self {
            case .nothingToPrint: "Select at least one card first."
            }
        }
    }
}
