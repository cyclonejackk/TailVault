//
//  PetEditView.swift
//  TailVault
//
//  Create/edit a pet: species, photo, vitals, personality,
//  custom fields, family links, vet.
//

import SwiftUI
import SwiftData
import PhotosUI

struct PetEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var allPets: [Pet]
    @Query(sort: \VetClinic.name) private var clinics: [VetClinic]
    @Query(sort: \Household.name) private var households: [Household]

    /// nil = creating a new pet
    let pet: Pet?

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    // Draft state
    @State private var name = ""
    @State private var species = "Cat"
    @State private var customSpecies = ""
    @State private var formerName = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var hasDOB = false
    @State private var dob = Date()
    @State private var hasGotcha = false
    @State private var gotchaDay = Date()
    @State private var sex = ""
    @State private var breed = ""
    @State private var colorMarkings = ""
    @State private var microchip = ""
    @State private var rabiesTag = ""
    @State private var collarTag = ""
    @State private var selectedHousehold: Household?
    @State private var newHouseholdName = ""
    @State private var indoorOutdoor: IndoorOutdoor = .indoor
    @State private var isActive = true
    @State private var activeConditions: [String] = []
    @State private var allergies: [String] = []
    @State private var healthNotes = ""
    @State private var hidingSpots: [String] = []
    @State private var toys: [String] = []
    @State private var favoriteTreats = ""
    @State private var likesTreats: Fondness = .unknown
    @State private var likesPets: Fondness = .unknown
    @State private var temperamentNotes = ""
    @State private var sitterNotes = ""
    @State private var customFields: [(name: String, value: String)] = []
    @State private var selectedParentIDs: Set<UUID> = []
    @State private var selectedSiblingIDs: Set<UUID> = []
    @State private var selectedClinic: VetClinic?
    @State private var newClinicName = ""

    private var otherPets: [Pet] {
        allPets.filter { $0.id != pet?.id }
    }

    private var isCustomSpecies: Bool { species == "Other" }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                Picker("Species", selection: $species) {
                    ForEach(SpeciesCatalog.common, id: \.name) { item in
                        Text("\(item.emoji) \(item.name)").tag(item.name)
                    }
                }
                if isCustomSpecies {
                    TextField("Custom species (Axolotl, Alpaca…)", text: $customSpecies)
                }
                TextField("Former name (optional)", text: $formerName)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoData == nil ? "Add profile photo" : "Change profile photo",
                          systemImage: "camera")
                }
                Toggle("Has date of birth", isOn: $hasDOB)
                if hasDOB {
                    DatePicker("Date of birth", selection: $dob, displayedComponents: .date)
                }
                Toggle("Has gotcha day", isOn: $hasGotcha)
                if hasGotcha {
                    DatePicker("Gotcha day", selection: $gotchaDay, displayedComponents: .date)
                }
                TextField("Sex (e.g. M neutered)", text: $sex)
                TextField("Breed", text: $breed)
                TextField("Color / markings", text: $colorMarkings)
                Picker("Indoor/outdoor", selection: $indoorOutdoor) {
                    ForEach(IndoorOutdoor.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Active (still in household)", isOn: $isActive)
            }

            Section("Identification") {
                TextField("Microchip #", text: $microchip)
                TextField("Rabies tag #", text: $rabiesTag)
                TextField("Collar/Tag # (tracker, name tag…)", text: $collarTag)
            }

            Section("Location") {
                Picker("Location", selection: $selectedHousehold) {
                    Text("None").tag(nil as Household?)
                    ForEach(households) { household in
                        Text(household.name).tag(household as Household?)
                    }
                }
                HStack {
                    TextField("New location name", text: $newHouseholdName)
                    Button("Add") {
                        let household = Household(name: newHouseholdName)
                        context.insert(household)
                        selectedHousehold = household
                        newHouseholdName = ""
                    }
                    .disabled(newHouseholdName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Health") {
                TagListField(title: "Conditions", prompt: "Conditions (comma-separated)", items: $activeConditions)
                TagListField(title: "Allergies", prompt: "Allergies (comma-separated)", items: $allergies)
                TextField("Health notes", text: $healthNotes, axis: .vertical)
            }

            Section {
                if let pet {
                    ForEach(pet.activeFeedings, id: \.persistentModelID) { feeding in
                        NavigationLink {
                            FeedingEditView(pet: pet, feeding: feeding)
                        } label: {
                            LabeledContent {
                                Text(feeding.summary).font(.caption)
                            } label: {
                                Text("\(feeding.kind.emoji) \(feeding.foodLabel)")
                            }
                        }
                    }
                    NavigationLink {
                        FeedingEditView(pet: pet, feeding: nil)
                    } label: {
                        Label("Add food", systemImage: "plus.circle")
                    }
                } else {
                    Text("Save this pet first, then add foods with brand, amount, and schedule.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } header: {
                Text("Food & feeding")
            } footer: {
                if pet != nil {
                    Text("Food edits save on their own — Cancel above won't undo them.")
                }
            }

            Section("Personality & favorites") {
                TextField("Favorite treats", text: $favoriteTreats)
                FondnessPicker(title: "Likes treats?", value: $likesTreats)
                FondnessPicker(title: "Likes pets?", value: $likesPets)
                TagListField(title: "Hiding spots", prompt: "Hiding spots (comma-separated)", items: $hidingSpots)
                TagListField(title: "Favorite toys", prompt: "Favorite toys (comma-separated)", items: $toys)
                TextField("Temperament notes", text: $temperamentNotes, axis: .vertical)
            }

            Section {
                ForEach(customFields.indices, id: \.self) { index in
                    HStack {
                        TextField("Field", text: $customFields[index].name)
                            .frame(maxWidth: 130)
                        Divider()
                        TextField("Value", text: $customFields[index].value)
                    }
                }
                .onDelete { customFields.remove(atOffsets: $0) }
                Button {
                    customFields.append((name: "", value: ""))
                } label: {
                    Label("Add field", systemImage: "plus.circle")
                }
            } header: {
                Text("Custom fields")
            } footer: {
                Text("Anything else worth tracking — insurance policy, groomer, harness size, tank temperature…")
            }

            Section("Sitter notes") {
                TextField("Feeding times, quirks, warnings…", text: $sitterNotes, axis: .vertical)
                    .lineLimit(3...8)
            }

            if !otherPets.isEmpty {
                Section("Family — parents") {
                    ForEach(otherPets) { other in
                        familyToggle(other, selection: $selectedParentIDs)
                    }
                }
                Section("Family — siblings") {
                    ForEach(otherPets) { other in
                        familyToggle(other, selection: $selectedSiblingIDs)
                    }
                }
            }

            Section("Vet") {
                Picker("Primary clinic", selection: $selectedClinic) {
                    Text("None").tag(nil as VetClinic?)
                    ForEach(clinics) { clinic in
                        Text(clinic.name).tag(clinic as VetClinic?)
                    }
                }
                HStack {
                    TextField("New clinic name", text: $newClinicName)
                    Button("Add") {
                        let clinic = VetClinic(name: newClinicName)
                        context.insert(clinic)
                        selectedClinic = clinic
                        newClinicName = ""
                    }
                    .disabled(newClinicName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle(pet == nil ? "New Pet" : "Edit \(pet!.name)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
        .onChange(of: photoItem) {
            Task {
                photoData = try? await photoItem?.loadTransferable(type: Data.self)
            }
        }
    }

    private func familyToggle(_ other: Pet, selection: Binding<Set<UUID>>) -> some View {
        Toggle(isOn: Binding(
            get: { selection.wrappedValue.contains(other.id) },
            set: { isOn in
                if isOn { selection.wrappedValue.insert(other.id) }
                else { selection.wrappedValue.remove(other.id) }
            }
        )) {
            HStack {
                PetAvatar(pet: other, size: 28)
                Text(other.name)
            }
        }
    }

    // MARK: Load / save

    private func load() {
        guard let pet else {
            // New pets start at the current location.
            selectedHousehold = CurrentLocation.resolve(
                from: households, idString: currentLocationID)
            return
        }
        name = pet.name
        if SpeciesCatalog.common.contains(where: { $0.name == pet.species }) {
            species = pet.species
        } else {
            species = "Other"
            customSpecies = pet.species
        }
        formerName = pet.formerName
        photoData = pet.photoData
        if let d = pet.dob { hasDOB = true; dob = d }
        if let g = pet.gotchaDay { hasGotcha = true; gotchaDay = g }
        sex = pet.sex
        breed = pet.breed
        colorMarkings = pet.colorMarkings
        microchip = pet.microchip
        rabiesTag = pet.rabiesTag
        collarTag = pet.collarTag
        selectedHousehold = pet.household
        indoorOutdoor = pet.indoorOutdoor
        isActive = pet.isActive
        activeConditions = pet.activeConditions
        allergies = pet.allergies
        healthNotes = pet.healthNotes
        hidingSpots = pet.favoriteHidingSpots
        toys = pet.favoriteToys
        favoriteTreats = pet.favoriteTreats
        likesTreats = pet.likesTreats
        likesPets = pet.likesPets
        temperamentNotes = pet.temperamentNotes
        sitterNotes = pet.sitterNotes
        customFields = pet.customFields
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ($0.name, $0.value) }
        selectedParentIDs = Set(pet.parents.map(\.id))
        selectedSiblingIDs = Set(pet.siblingIDs)
        selectedClinic = pet.primaryClinic
    }

    private func save() {
        let target = pet ?? Pet(name: name)
        if pet == nil { context.insert(target) }

        target.name = name.trimmingCharacters(in: .whitespaces)
        let customTrimmed = customSpecies.trimmingCharacters(in: .whitespaces)
        target.species = (isCustomSpecies && !customTrimmed.isEmpty) ? customTrimmed : species
        target.formerName = formerName
        target.photoData = photoData
        target.dob = hasDOB ? dob : nil
        target.gotchaDay = hasGotcha ? gotchaDay : nil
        target.sex = sex
        target.breed = breed
        target.colorMarkings = colorMarkings
        target.microchip = microchip
        target.rabiesTag = rabiesTag
        target.collarTag = collarTag
        target.household = selectedHousehold
        target.indoorOutdoor = indoorOutdoor
        target.isActive = isActive
        target.activeConditions = activeConditions
        target.allergies = allergies
        target.healthNotes = healthNotes
        target.favoriteHidingSpots = hidingSpots
        target.favoriteToys = toys
        target.favoriteTreats = favoriteTreats
        target.likesTreats = likesTreats
        target.likesPets = likesPets
        target.temperamentNotes = temperamentNotes
        target.sitterNotes = sitterNotes
        target.primaryClinic = selectedClinic

        // Custom fields: replace wholesale (simplest correct behavior)
        for old in target.customFields { context.delete(old) }
        target.customFields = customFields
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { index, field in
                CustomField(name: field.name, value: field.value, sortOrder: index)
            }

        // Family: parents (real relationship)
        target.parents = otherPets.filter { selectedParentIDs.contains($0.id) }

        // Family: siblings (symmetric ID links)
        for other in otherPets {
            if selectedSiblingIDs.contains(other.id) {
                Pet.linkSiblings(target, other)
            } else {
                Pet.unlinkSiblings(target, other)
            }
        }

        dismiss()
    }
}
