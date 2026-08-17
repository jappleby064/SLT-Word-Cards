import SwiftUI

/// The picture side of a card: the word's image, or — for number cards — the
/// numeral/number word drawn large, the same substitution the PDF makes.
struct CardFaceView: View {
    let card: Card
    var cornerRadius: Double = Theme.Radius.large
    var showsBorder = true

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Deliberately white in both appearances rather than
                // `.systemBackground`. Card pictures are 500×500 JPEGs with white
                // padding baked in, and a printed card is white, so a dark card
                // face would put a white square inside a black one — and would
                // draw the numeral in white on white.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white)

                if let text = card.faceText {
                    Text(text)
                        .font(.system(size: side * 0.5, weight: .bold, design: .default))
                        .foregroundStyle(.black)
                        .minimumScaleFactor(0.2)
                        .lineLimit(1)
                        .padding(side * 0.1)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: side * 0.25))
                        .foregroundStyle(.black.opacity(0.25))
                }
            }
            .frame(width: side, height: side)
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Theme.rule, lineWidth: Theme.hairline)
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
        CardFaceView(card: card, cornerRadius: Theme.Radius.small)
            .frame(width: side, height: side)
    }
}

/// One line describing a card's phonetic properties.
struct CardDetailLine: View {
    let card: Card

    var body: some View {
        Text(descriptor)
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
    }

    private var descriptor: String {
        var parts: [String] = []
        if !card.initialSound.isEmpty { parts.append("initial \(card.initialSound)") }
        if !card.finalSound.isEmpty { parts.append("final \(card.finalSound)") }
        if !card.structure.isEmpty { parts.append(card.structure.uppercased()) }
        return parts.joined(separator: " · ")
    }
}
