import SwiftUI

/// Tier one of saved decks: the learner list.
struct LearnersView: View {
    @Environment(DeckLibrary.self) private var decks

    @State private var isAddingLearner = false
    @State private var newLearnerName = ""
    @State private var renaming: Learner?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if decks.teacherLearners.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No learners yet", systemImage: "folder.badge.plus")
                        } description: {
                            Text("Add a learner, then save decks of cards under their name.")
                        } actions: {
                            Button("Add Learner") { startAddingLearner() }
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(decks.teacherLearners) { learner in
                            NavigationLink(value: learner) {
                                row(for: learner)
                            }
                            .contextMenu {
                                Button {
                                    renaming = learner
                                    renameText = learner.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    decks.delete(learner)
                                } label: {
                                    Label("Delete Learner", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                decks.delete(decks.teacherLearners[index])
                            }
                        }
                    } footer: {
                        Text(decks.location == .iCloud
                             ? "Decks are stored in your private iCloud Drive and appear on your other devices. They are never shared with anyone else."
                             : "Decks are stored on this device. Sign in to iCloud to have them follow you between your own devices.")
                    }
                }
            }
            .navigationTitle("Learners")
            .navigationDestination(for: Learner.self) { learner in
                LearnerDecksView(learner: learner)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startAddingLearner()
                    } label: {
                        Label("Add Learner", systemImage: "plus")
                    }
                }
            }
            .alert("New Learner", isPresented: $isAddingLearner) {
                TextField("Name", text: $newLearnerName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = newLearnerName.trimmed
                    guard !name.isEmpty else { return }
                    decks.addLearner(named: name)
                }
            } message: {
                Text("Decks you save will be filed under this name.")
            }
            .alert("Rename Learner", isPresented: .init(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let learner = renaming, !renameText.trimmed.isEmpty {
                        decks.rename(learner, to: renameText)
                    }
                    renaming = nil
                }
            }
        }
    }

    private func row(for learner: Learner) -> some View {
        let count = decks.decks(for: learner).count
        return HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(learner.name)
                Text(count == 1 ? "1 deck" : "\(count) decks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startAddingLearner() {
        newLearnerName = ""
        isAddingLearner = true
    }
}
