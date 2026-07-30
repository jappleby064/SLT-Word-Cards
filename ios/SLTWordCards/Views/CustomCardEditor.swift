import PhotosUI
import SwiftUI

/// Make or edit one of your own cards. Everything except the picture is required,
/// so a card is always findable on the criteria that matter.
struct CustomCardEditor: View {
    /// Nil when making a new card.
    let existing: CustomCard?

    @Environment(CustomCardStore.self) private var store
    @Environment(CardLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var word = ""
    @State private var initialSound = ""
    @State private var finalSound = ""
    @State private var structure = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var removeExistingImage = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var isEditing: Bool { existing != nil }

    private var canSave: Bool {
        !word.trimmed.isEmpty
            && !initialSound.trimmed.isEmpty
            && !finalSound.trimmed.isEmpty
            && !structure.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Word", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Word")
                } footer: {
                    Text("What the card shows. Lower case, as in the rest of the card set.")
                }

                Section {
                    IPASoundField(title: "Word initial sound", symbol: $initialSound)
                    IPASoundField(title: "Word final sound", symbol: $finalSound)
                    Picker("Structure", selection: $structure) {
                        Text("Choose…").tag("")
                        ForEach(structureOptions, id: \.self) { option in
                            Text(option.uppercased()).tag(option)
                        }
                    }
                } header: {
                    Text("Sounds and structure")
                } footer: {
                    Text("Required, so the card turns up in the same searches as every other card.")
                }

                Section {
                    picturePicker
                } header: {
                    Text("Picture")
                } footer: {
                    Text("Optional. Pictures are squared off to 500×500 and padded with white, never cropped or stretched, so they print like the rest.")
                }

                Section {
                    Text("Your cards stay in your own iCloud and are never uploaded or shared. Because nobody else has a copy, they are left out of decks you send to someone else.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isEditing, let existing {
                    Section {
                        Button(role: .destructive) {
                            store.delete(existing)
                            library.setCustomCards(store.searchableCards)
                            dismiss()
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Card" : "New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave || isSaving)
                }
            }
            .onAppear(perform: loadExisting)
            .onChange(of: pickedItem) { _, item in
                Task { await loadPicked(item) }
            }
            .alert("Couldn't save", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var picturePicker: some View {
        // Read once, outside the picker's label: that closure is @Sendable and so
        // can't touch main-actor state.
        let current = preview

        return VStack(alignment: .leading, spacing: 12) {
            if let current {
                Image(uiImage: current)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 160, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator)))
            }

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label(current == nil ? "Choose a Picture" : "Choose a Different Picture",
                      systemImage: "photo")
            }

            if current != nil {
                Button(role: .destructive) {
                    pickedImage = nil
                    pickedItem = nil
                    removeExistingImage = true
                } label: {
                    Label("Remove Picture", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var preview: UIImage? {
        if let pickedImage { return pickedImage }
        if removeExistingImage { return nil }
        if let existing, existing.hasImage {
            return ImageLoader.shared.image(for: existing.asCard)
        }
        return nil
    }

    /// Structures already in use, so custom cards stay consistent with the set.
    private var structureOptions: [String] {
        var options = Set(library.structures)
        if !structure.isEmpty { options.insert(structure) }
        return options.sorted { ($0.count, $0) < ($1.count, $1) }
    }

    private func loadExisting() {
        guard let existing else { return }
        word = existing.word
        initialSound = existing.initialSound
        finalSound = existing.finalSound
        structure = existing.structure
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "That picture couldn't be read."
            return
        }
        pickedImage = image
        removeExistingImage = false
    }

    private func save() {
        isSaving = true
        defer { isSaving = false }

        var card = existing ?? CustomCard(
            word: word,
            initialSound: initialSound,
            finalSound: finalSound,
            structure: structure
        )
        card.word = word.trimmed
        card.initialSound = initialSound.trimmed.lowercased()
        card.finalSound = finalSound.trimmed.lowercased()
        card.structure = structure.trimmed.lowercased()

        do {
            // Keep an untouched picture when only the wording changed.
            let keepExisting = pickedImage == nil && !removeExistingImage
            try store.save(card, image: pickedImage, keepExistingImage: keepExisting)
            library.setCustomCards(store.searchableCards)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Lists and manages the user's own cards.
struct MyCardsView: View {
    @Environment(CustomCardStore.self) private var store
    @Environment(CardLibrary.self) private var library

    @State private var editing: CustomCard?
    @State private var isCreating = false

    var body: some View {
        List {
            if store.cards.isEmpty {
                ContentUnavailableView {
                    Label("No cards of your own", systemImage: "rectangle.badge.plus")
                } description: {
                    Text("Add a card for a word the set doesn't have yet. It stays in your iCloud and is never uploaded.")
                } actions: {
                    Button("New Card") { isCreating = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(store.cards) { card in
                        Button {
                            editing = card
                        } label: {
                            HStack(spacing: 12) {
                                CardThumbnail(card: card.asCard)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.word)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    CardDetailLine(card: card.asCard)
                                }
                                Spacer()
                                if !card.hasImage {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.delete(store.cards[index])
                        }
                        library.setCustomCards(store.searchableCards)
                    }
                } footer: {
                    Text(store.location == .iCloud
                         ? "Kept in your private iCloud, so they appear on your other devices. Never uploaded or shared."
                         : "Kept on this device. Sign in to iCloud to have them follow you between your own devices.")
                }
            }
        }
        .navigationTitle("My Cards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New Card", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            CustomCardEditor(existing: nil)
        }
        .sheet(item: $editing) { card in
            CustomCardEditor(existing: card)
        }
    }
}
