import SwiftUI

/// Tier one of saved decks: the client list.
struct ClientsView: View {
    @Environment(DeckLibrary.self) private var decks

    @State private var isAddingClient = false
    @State private var newClientName = ""
    @State private var renaming: Client?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if decks.clients.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No clients yet", systemImage: "folder.badge.plus")
                        } description: {
                            Text("Add a client, then save decks of cards under their name.")
                        } actions: {
                            Button("Add Client") { startAddingClient() }
                                .buttonStyle(.borderedProminent)
                        }
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ForEach(decks.clients) { client in
                            NavigationLink(value: client) {
                                row(for: client)
                            }
                            .contextMenu {
                                Button {
                                    renaming = client
                                    renameText = client.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    decks.delete(client)
                                } label: {
                                    Label("Delete Client", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                decks.delete(decks.clients[index])
                            }
                        }
                    } footer: {
                        Text(decks.location == .iCloud
                             ? "Decks are stored in your private iCloud Drive and appear on your other devices. They are never shared with anyone else."
                             : "Decks are stored on this device. Sign in to iCloud to have them follow you between your own devices.")
                    }
                }
            }
            .navigationTitle("Clients")
            .navigationDestination(for: Client.self) { client in
                ClientDecksView(client: client)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startAddingClient()
                    } label: {
                        Label("Add Client", systemImage: "plus")
                    }
                }
            }
            .alert("New Client", isPresented: $isAddingClient) {
                TextField("Name", text: $newClientName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = newClientName.trimmed
                    guard !name.isEmpty else { return }
                    decks.addClient(named: name)
                }
            } message: {
                Text("Decks you save will be filed under this name.")
            }
            .alert("Rename Client", isPresented: .init(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let client = renaming, !renameText.trimmed.isEmpty {
                        decks.rename(client, to: renameText)
                    }
                    renaming = nil
                }
            }
        }
    }

    private func row(for client: Client) -> some View {
        let count = decks.decks(for: client).count
        return HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                Text(count == 1 ? "1 deck" : "\(count) decks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startAddingClient() {
        newClientName = ""
        isAddingClient = true
    }
}
