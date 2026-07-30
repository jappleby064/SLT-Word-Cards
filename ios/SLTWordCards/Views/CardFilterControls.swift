import SwiftUI

/// The four filter controls from the web app, shared by the Search tab and the
/// "add cards" picker inside a deck.
struct CardFilterControls: View {
    @Binding var criteria: SearchCriteria
    let structures: [String]

    var body: some View {
        Picker("Type", selection: $criteria.kind) {
            Text("All").tag(Card.Kind?.none)
            Text("Words").tag(Card.Kind?.some(.word))
            Text("Numbers").tag(Card.Kind?.some(.number))
        }
        .pickerStyle(.segmented)

        IPASoundField(title: "Word initial sound", symbol: $criteria.initialSound)
        IPASoundField(title: "Word final sound", symbol: $criteria.finalSound)

        Picker("Structure", selection: $criteria.structure) {
            Text("Any").tag("")
            ForEach(structures, id: \.self) { structure in
                Text(structure.uppercased()).tag(structure)
            }
        }
    }
}

/// A tickable result row.
struct CardSelectRow: View {
    let card: Card
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                CardThumbnail(card: card)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(card.label)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        if card.isCustom {
                            Text("Mine")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    CardDetailLine(card: card)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
