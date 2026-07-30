import SwiftUI

/// The picture side of a card: the word's image, or — for number cards — the
/// numeral/number word drawn large, the same substitution the PDF makes.
struct CardFaceView: View {
    let card: Card
    var cornerRadius: Double = 16
    var showsBorder = true

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))

                if let text = card.faceText {
                    Text(text)
                        .font(.system(size: side * 0.5, weight: .bold, design: .default))
                        .minimumScaleFactor(0.2)
                        .lineLimit(1)
                        .padding(side * 0.1)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: side * 0.25))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: side, height: side)
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.separator), lineWidth: 1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var image: UIImage? {
        ImageLoader.shared.image(for: card)
    }
}

/// Small square used in result rows and deck lists.
struct CardThumbnail: View {
    let card: Card
    var side: Double = 44

    var body: some View {
        CardFaceView(card: card, cornerRadius: 8)
            .frame(width: side, height: side)
    }
}

/// One line describing a card's phonetic properties.
struct CardDetailLine: View {
    let card: Card

    var body: some View {
        Text(descriptor)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var descriptor: String {
        var parts: [String] = []
        if !card.initialSound.isEmpty { parts.append("initial \(card.initialSound)") }
        if !card.finalSound.isEmpty { parts.append("final \(card.finalSound)") }
        if !card.structure.isEmpty { parts.append(card.structure.uppercased()) }
        return parts.joined(separator: " · ")
    }
}
