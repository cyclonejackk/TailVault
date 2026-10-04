//
//  PetExtrasViews.swift
//  TailVault
//
//  Sheets and helpers for the profile extras: expenses, journal
//  observations, the document locker, and the lost-pet flyer.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Expense entry

struct ExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    let pet: Pet

    @State private var date = Date.now
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .vet
    @State private var note = ""

    var body: some View {
        Form {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            HStack {
                Text("$")
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }
            Picker("Category", selection: $category) {
                ForEach(ExpenseCategory.allCases) { c in
                    Text("\(c.emoji) \(c.label)").tag(c)
                }
            }
            TextField("Note (annual exam, 16 lb bag…)", text: $note, axis: .vertical)
        }
        .navigationTitle("Add Expense")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    pet.expenses.append(Expense(date: date, amount: amount, category: category, note: note))
                    dismiss()
                }
                .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
            }
        }
    }
}

// MARK: - Journal observation entry

struct ObservationEditView: View {
    @Environment(\.dismiss) private var dismiss
    let pet: Pet

    @State private var date = Date.now
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        Form {
            DatePicker("When", selection: $date)
            TextField("What did you notice? (limping, licking spot on leg…)",
                      text: $note, axis: .vertical)
                .lineLimit(3...8)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photoData == nil ? "Add photo" : "Change photo", systemImage: "camera")
            }
            if let photoData, let image = PlatformImage(data: photoData) {
                Image(platformImage: image)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .navigationTitle("Journal Entry")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    pet.observations.append(JournalEntry(date: date, note: note, photoData: photoData))
                    dismiss()
                }
                .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: photoItem) {
            Task { photoData = try? await photoItem?.loadTransferable(type: Data.self) }
        }
    }
}

// MARK: - Document viewer/editor

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: PetDocument

    var body: some View {
        Form {
            TextField("Name (Rabies certificate…)", text: $document.name)
            DatePicker("Date", selection: $document.date, displayedComponents: .date)
            TextField("Notes", text: $document.notes, axis: .vertical)
            if let data = document.imageData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let data = document.imageData, let image = PlatformImage(data: data) {
                ShareLink(item: Image(platformImage: image),
                          preview: SharePreview(document.name, image: Image(platformImage: image))) {
                    Label("Share document", systemImage: "square.and.arrow.up")
                }
            }
            Button("Delete document", role: .destructive) {
                context.delete(document)
                dismiss()
            }
        }
        .navigationTitle(document.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Lost pet flyer

/// The flyer itself — rendered to a PNG via ImageRenderer.
struct LostPetFlyerView: View {
    let pet: Pet
    let ownerName: String
    let ownerPhone: String

    var body: some View {
        VStack(spacing: 14) {
            Text("MISSING \(pet.species.uppercased())")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(.red)

            if let data = pet.photoData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 420, height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(.gray.opacity(0.2))
                    Image(systemName: SpeciesCatalog.symbol(for: pet.species))
                        .font(.system(size: 120))
                        .foregroundStyle(.gray)
                }
                .frame(width: 420, height: 420)
            }

            Text(pet.name)
                .font(.system(size: 40, weight: .bold))

            VStack(spacing: 5) {
                if !pet.breed.isEmpty || !pet.colorMarkings.isEmpty {
                    Text([pet.breed, pet.colorMarkings].filter { !$0.isEmpty }.joined(separator: " · "))
                }
                if !pet.sex.isEmpty { Text(pet.sex) }
                if !pet.microchip.isEmpty { Text("Microchip: \(pet.microchip)") }
                if !pet.collarTag.isEmpty { Text("Collar/tag: \(pet.collarTag)") }
            }
            .font(.system(size: 20))

            VStack(spacing: 4) {
                Text("IF SEEN, PLEASE CALL")
                    .font(.system(size: 22, weight: .heavy))
                Text([ownerName, ownerPhone].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.red)
            }
            .padding(.top, 6)
        }
        .padding(36)
        .frame(width: 540)
        .background(.white)
        .fontDesign(.rounded)
        .foregroundStyle(.black)
    }
}

@MainActor
enum FlyerRenderer {
    /// Renders the flyer to a shareable PNG at a temp URL.
    static func render(pet: Pet, ownerName: String, ownerPhone: String) -> URL? {
        let renderer = ImageRenderer(
            content: LostPetFlyerView(pet: pet, ownerName: ownerName, ownerPhone: ownerPhone)
        )
        renderer.scale = 2
        #if os(iOS)
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        #else
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        #endif
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pet.name) Flyer.png")
        try? data.write(to: url, options: .atomic)
        return url
    }
}
