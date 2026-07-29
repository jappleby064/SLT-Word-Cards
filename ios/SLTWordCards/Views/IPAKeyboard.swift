import SwiftUI

/// English (RP) phoneme inventory, matching `IPA_SOUNDS` in app.js.
enum IPA {
    static let groups: [(name: String, symbols: [String])] = [
        ("Consonants", ["p", "b", "t", "d", "k", "ɡ", "m", "n", "ŋ", "f", "v", "θ", "ð",
                        "s", "z", "ʃ", "ʒ", "h", "tʃ", "dʒ", "l", "r", "j", "w"]),
        ("Vowels", ["iː", "ɪ", "e", "æ", "ɑː", "ɒ", "ɔː", "ʊ", "uː", "ʌ", "ɜː", "ə"]),
        ("Diphthongs", ["eɪ", "aɪ", "ɔɪ", "əʊ", "aʊ", "ɪə", "eə", "ʊə"])
    ]
}

/// A phoneme field: shows the picked symbol and opens the IPA keyboard to change
/// it. Selecting a symbol replaces the value, as in the web app.
struct IPASoundField: View {
    let title: String
    @Binding var symbol: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(symbol.isEmpty ? "Any" : symbol)
                    .font(symbol.isEmpty ? .body : .body.weight(.semibold))
                    .foregroundStyle(symbol.isEmpty ? .secondary : Color.accentColor)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $isPresented) {
            IPAKeyboardSheet(title: title, symbol: $symbol)
        }
    }
}

private struct IPAKeyboardSheet: View {
    let title: String
    @Binding var symbol: String

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 54), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(IPA.groups, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.symbols, id: \.self) { candidate in
                                    key(candidate)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Any") {
                        symbol = ""
                        dismiss()
                    }
                    .disabled(symbol.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func key(_ candidate: String) -> some View {
        let isSelected = candidate == symbol
        return Button {
            symbol = candidate
            dismiss()
        } label: {
            Text(candidate)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
