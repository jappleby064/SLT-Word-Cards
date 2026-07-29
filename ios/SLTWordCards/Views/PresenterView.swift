import SwiftUI

/// The on-device deck: one card at a time, tap to reveal the word, swipe or use
/// the buttons to move through.
struct PresenterView: View {
    let cards: [Card]
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var order: [Card] = []
    @State private var index = 0
    @State private var isWordRevealed = false
    @State private var alwaysShowWord = false

    var body: some View {
        NavigationStack {
            Group {
                if order.isEmpty {
                    ContentUnavailableView(
                        "Empty deck",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Add some cards first.")
                    )
                } else {
                    content
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Always show word", isOn: $alwaysShowWord)
                        Button {
                            order.shuffle()
                            goTo(0)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        Button {
                            order = cards
                            goTo(0)
                        } label: {
                            Label("Restart in order", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            if order.isEmpty { order = cards }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(Array(order.enumerated()), id: \.offset) { position, card in
                    cardPage(card)
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: index) { _, _ in
                isWordRevealed = false
            }

            controls
        }
        .background(Color(.systemGroupedBackground))
    }

    private func cardPage(_ card: Card) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            CardFaceView(card: card, cornerRadius: 24)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .onTapGesture {
                    withAnimation(.snappy) { isWordRevealed.toggle() }
                }

            // Both states share one fixed-height, full-width block: the hint must
            // not be laid out inside the word's frame, or its line count and
            // truncation would change with the length of the word.
            ZStack {
                Text(card.label.capitalizedFirst)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .opacity(showsWord ? 1 : 0)
                    .accessibilityHidden(!showsWord)

                Text("Tap the card to show the word")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(showsWord ? 0 : 1)
                    .accessibilityHidden(showsWord)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    private var controls: some View {
        HStack {
            Button {
                goTo(index - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .disabled(index == 0)

            Spacer()

            VStack(spacing: 2) {
                Text("\(index + 1) of \(order.count)")
                    .font(.headline.monospacedDigit())
                ProgressView(value: Double(index + 1), total: Double(order.count))
                    .frame(width: 120)
            }

            Spacer()

            Button {
                goTo(index + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .disabled(index >= order.count - 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var showsWord: Bool {
        alwaysShowWord || isWordRevealed
    }

    private func goTo(_ target: Int) {
        guard !order.isEmpty else { return }
        withAnimation(.snappy) {
            index = min(max(0, target), order.count - 1)
        }
        isWordRevealed = false
    }
}
