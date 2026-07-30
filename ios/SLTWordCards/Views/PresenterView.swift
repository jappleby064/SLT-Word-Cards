import SwiftUI

/// How the deck is being worked through.
enum PresenterMode {
    /// Show a card, reveal the word, move on. No record kept.
    case present
    /// Same, but each answer is marked after the reveal and the score is kept
    /// for the length of the run.
    case test

    var title: String {
        switch self {
        case .present: "Present"
        case .test: "Test"
        }
    }
}

/// The on-device deck: one card at a time, tap to reveal the word, swipe or use
/// the buttons to move through. In Test mode the reveal is followed by marking
/// the answer, and a score is kept.
///
/// Renders only the current card rather than a paged `TabView` — the page style
/// is iPhone/iPad-only, and this keeps one code path across iOS and Mac while
/// still supporting swipe, buttons, and arrow keys.
struct PresenterView: View {
    let cards: [Card]
    let title: String
    var mode: PresenterMode = .present

    @Environment(\.dismiss) private var dismiss

    @State private var order: [Card] = []
    @State private var index = 0
    @State private var isWordRevealed = false
    @State private var alwaysShowWord = false
    @State private var dragOffset: Double = 0
    /// Marks for this run, keyed by card. Held here and nowhere else: the score
    /// lasts as long as the test is open and is discarded when it closes. Nothing
    /// is written to disk, so no record is kept against a client.
    @State private var marks: [Card.ID: Bool] = [:]
    @State private var isShowingSummary = false
    @State private var isConfirmingDiscard = false

    private var isTest: Bool { mode == .test }

    var body: some View {
        NavigationStack {
            Group {
                if order.isEmpty {
                    ContentUnavailableView(
                        "Empty deck",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Add some cards first.")
                    )
                } else if isShowingSummary {
                    summary
                } else {
                    content
                }
            }
            .navigationTitle(isTest ? "\(title) · Test" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        if isTestInProgress {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // Always showing the word would defeat a test.
                        if !isTest {
                            Toggle("Always show word", isOn: $alwaysShowWord)
                        }
                        Button {
                            order.shuffle()
                            restart(with: order)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        Button {
                            restart(with: cards)
                        } label: {
                            Label(isTest ? "Start Test Again" : "Restart in order",
                                  systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        // A part-finished score exists only in memory, so a stray swipe would
        // destroy it with nothing to fall back on. Closing has to be deliberate.
        .interactiveDismissDisabled(isTestInProgress)
        .confirmationDialog(
            "Discard this test?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Testing", role: .cancel) {}
        } message: {
            Text("The score so far isn't saved anywhere, so closing now loses it.")
        }
        .onAppear {
            if order.isEmpty { order = cards }
        }
    }

    /// A test that has been started but not yet finished. Once the summary is up
    /// the score has been seen, so closing needs no warning.
    private var isTestInProgress: Bool {
        isTest && !marks.isEmpty && !isShowingSummary
    }

    private var current: Card? {
        order.indices.contains(index) ? order[index] : nil
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let current {
                cardPage(current)
                    .frame(maxHeight: .infinity)
            }
            controls
        }
        .background(Color(.systemGroupedBackground))
    }

    private func cardPage(_ card: Card) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            CardFaceView(card: card, cornerRadius: 24)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .id(card.id)
                .transition(.opacity)
                .offset(x: dragOffset)
                .onTapGesture {
                    withAnimation(.snappy) { isWordRevealed.toggle() }
                }
                .gesture(swipe)

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

                Text(revealHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .opacity(showsWord ? 0 : 1)
                    .accessibilityHidden(showsWord)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, 24)

            // Reserved whether or not the buttons are showing, so revealing the
            // word never shifts the card.
            if isTest {
                markingRow(for: card)
                    .frame(height: 54)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    /// Marking only appears once the word has been shown — you can't judge an
    /// answer before seeing it.
    @ViewBuilder
    private func markingRow(for card: Card) -> some View {
        if showsWord {
            HStack(spacing: 12) {
                Button {
                    mark(card, correct: false)
                } label: {
                    Label("Not yet", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    mark(card, correct: true)
                } label: {
                    Label("Correct", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        } else {
            Color.clear
        }
    }

    private var revealHint: String {
        #if targetEnvironment(macCatalyst)
        isTest ? "Click the card to check the answer" : "Click the card to show the word"
        #else
        isTest ? "Tap the card to check the answer" : "Tap the card to show the word"
        #endif
    }

    /// Horizontal swipe to move between cards, with a little rubber-banding.
    /// Forward swiping is off in a test — marking is what moves you on.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if isTest && value.translation.width < 0 { return }
                dragOffset = value.translation.width / 3
            }
            .onEnded { value in
                dragOffset = 0
                if value.translation.width < -60, !isTest {
                    goTo(index + 1)
                } else if value.translation.width > 60 {
                    goBack()
                }
            }
    }

    private var controls: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .contentShape(.rect)
            }
            .disabled(index == 0)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Spacer()

            VStack(spacing: 2) {
                if isTest {
                    scoreLine
                }
                Text("\(index + 1) of \(order.count)")
                    .font(isTest ? .subheadline.monospacedDigit() : .headline.monospacedDigit())
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
                    .contentShape(.rect)
            }
            // In a test you advance by marking, so the score can't be skipped past.
            .disabled(isTest || index >= order.count - 1)
            .opacity(isTest ? 0 : 1)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay {
            // Space bar reveals, without taking focus from the arrow keys.
            Button("") {
                withAnimation(.snappy) { isWordRevealed.toggle() }
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private var scoreLine: some View {
        HStack(spacing: 10) {
            Label("\(correctCount)", systemImage: "checkmark")
                .foregroundStyle(.green)
            Label("\(incorrectCount)", systemImage: "xmark")
                .foregroundStyle(.orange)
        }
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .labelStyle(.titleAndIcon)
    }

    // MARK: Summary

    private var summary: some View {
        let missed = order.filter { marks[$0.id] == false }

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("\(correctCount) of \(marks.count)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(scoreSummaryLine)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                if !missed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Not yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(missed) { card in
                            HStack(spacing: 12) {
                                CardThumbnail(card: card)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.label)
                                        .font(.body.weight(.medium))
                                    CardDetailLine(card: card)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                }

                VStack(spacing: 10) {
                    if !missed.isEmpty {
                        Button {
                            restart(with: missed)
                        } label: {
                            Label(
                                missed.count == 1 ? "Practise the 1 missed" : "Practise the \(missed.count) missed",
                                systemImage: "arrow.trianglehead.clockwise"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button {
                        restart(with: cards)
                    } label: {
                        Label("Test the whole deck again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button("Done") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var scoreSummaryLine: String {
        guard !marks.isEmpty else { return "Nothing marked" }
        let percent = Int((Double(correctCount) / Double(marks.count) * 100).rounded())
        return incorrectCount == 0 ? "All correct · \(percent)%" : "\(percent)% correct"
    }

    // MARK: State

    private var showsWord: Bool {
        alwaysShowWord || isWordRevealed
    }

    private var correctCount: Int { marks.values.filter { $0 }.count }
    private var incorrectCount: Int { marks.values.filter { !$0 }.count }

    private func mark(_ card: Card, correct: Bool) {
        marks[card.id] = correct

        if index >= order.count - 1 {
            withAnimation(.snappy) { isShowingSummary = true }
        } else {
            goTo(index + 1)
        }
    }

    /// Stepping back in a test clears that card's mark so it can be answered
    /// again — otherwise a mistap would be stuck in the score.
    private func goBack() {
        guard index > 0 else { return }
        if isTest {
            marks[order[index - 1].id] = nil
        }
        goTo(index - 1)
    }

    private func goTo(_ target: Int) {
        guard !order.isEmpty else { return }
        let clamped = min(max(0, target), order.count - 1)
        withAnimation(.snappy) {
            index = clamped
            isWordRevealed = false
        }
    }

    private func restart(with cards: [Card]) {
        order = cards
        marks = [:]
        index = 0
        isWordRevealed = false
        withAnimation(.snappy) { isShowingSummary = false }
    }
}
