//
//  SettingsView.swift
//  TailVault
//
//  Appearance (dark/light/system), exports, vet clinic management.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage("ownerName") private var ownerName = ""
    @AppStorage("ownerPhone") private var ownerPhone = ""
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \AttendanceRecord.date, order: .reverse) private var records: [AttendanceRecord]
    @Query(sort: \VetClinic.name) private var clinics: [VetClinic]
    @Query(sort: \Household.name) private var households: [Household]
    @Query(sort: \ChoreTask.name) private var chores: [ChoreTask]
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    @State private var exportURL: URL?
    @State private var showingAddClinic = false
    @State private var newClinicName = ""
    @State private var showingAddHousehold = false
    @State private var newHouseholdName = ""
    @State private var newChore: ChoreTask?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TintThemePicker(selection: $tintTheme)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("The tint colors buttons and lays a faint hue over every screen — light and dark mode both.")
                }

                Section {
                    Button {
                        exportURL = CSVExporter.exportPets(pets)
                    } label: {
                        Label("Pets → spreadsheet (CSV)", systemImage: "tablecells")
                    }
                    Button {
                        exportURL = CSVExporter.exportMedLogs(pets)
                    } label: {
                        Label("Medication log → spreadsheet (CSV)", systemImage: "pills")
                    }
                    Button {
                        exportURL = CSVExporter.exportActivityLogs(pets)
                    } label: {
                        Label("Walks & enrichment → spreadsheet (CSV)", systemImage: "figure.walk")
                    }
                    Button {
                        exportURL = CSVExporter.exportExpenses(pets)
                    } label: {
                        Label("Expenses → spreadsheet (CSV)", systemImage: "dollarsign.circle")
                    }
                    Button {
                        exportURL = PDFExporter.pdf(
                            from: SitterSummary.householdText(pets: pets.filter(\.isActive), allPets: pets),
                            filename: "Pet Household Guide.pdf")
                    } label: {
                        Label("Household sitter guide (PDF)", systemImage: "doc.richtext")
                    }
                    Button {
                        exportURL = CSVExporter.exportAttendance(records)
                    } label: {
                        Label("Attendance → spreadsheet (CSV)", systemImage: "tablecells.badge.ellipsis")
                    }
                    ShareLink(
                        item: SitterSummary.householdText(pets: pets.filter(\.isActive), allPets: pets)
                    ) {
                        Label("Household sitter guide (text)", systemImage: "person.text.rectangle")
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("Exports open the share sheet — send to Mail, Notes, Messages, or save to Files.")
                }

                Section {
                    TextField("Your name", text: $ownerName)
                    TextField("Your phone", text: $ownerPhone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Owner contact")
                } footer: {
                    Text("Used on lost-pet flyers.")
                }

                Section("Vet clinics") {
                    ForEach(clinics) { clinic in
                        NavigationLink {
                            ClinicEditView(clinic: clinic)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(clinic.name)
                                if !clinic.phone.isEmpty {
                                    Text(clinic.phone).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(clinics[index]) }
                    }
                    Button {
                        showingAddClinic = true
                    } label: {
                        Label("Add clinic", systemImage: "plus.circle")
                    }
                }

                Section {
                    ForEach(households) { household in
                        NavigationLink {
                            HouseholdEditView(household: household)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(household.name)
                                Text("\(household.pets.count) pets")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let household = households[index]
                            // Deleting a location cascades to its chores and
                            // to-dos — cancel their pending reminders first.
                            for chore in household.chores {
                                NotificationManager.removeChoreReminder(id: chore.id)
                            }
                            for todo in household.todos {
                                NotificationManager.removeTodoReminder(id: todo.id)
                            }
                            context.delete(household)
                        }
                    }
                    Button {
                        showingAddHousehold = true
                    } label: {
                        Label("Add location", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Locations")
                } footer: {
                    Text("The location dropdown at the top of every page switches between these. Deleting a location never deletes its pets — they just become unassigned and show everywhere.")
                }

                Section {
                    ForEach(sortedChores) { chore in
                        NavigationLink {
                            ChoreEditView(chore: chore)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chore.name)
                                Text(choreSubtitle(chore))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let chore = sortedChores[index]
                            NotificationManager.removeChoreReminder(id: chore.id)
                            context.delete(chore)
                        }
                    }
                    Button {
                        let chore = ChoreTask(
                            name: "New cleaning task",
                            household: CurrentLocation.resolve(from: households,
                                                               idString: currentLocationID))
                        context.insert(chore)
                        newChore = chore
                    } label: {
                        Label("Add cleaning reminder", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Cleaning reminders")
                } footer: {
                    Text("Litter boxes, tank water, cage bedding… Auto-created per species per location, and the interval shrinks as more animals live there. Deleting one won't bring it back.")
                }

                Section("About") {
                    LabeledContent("Pets tracked", value: "\(pets.count)")
                    LabeledContent("Attendance records", value: "\(records.count)")
                }
            }
            .themedSurface(tintTheme)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .trailingBar) { LocationMenu() }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .sheet(item: $newChore) { chore in
                NavigationStack { ChoreEditView(chore: chore) }
            }
            .alert("New clinic", isPresented: $showingAddClinic) {
                TextField("Clinic name", text: $newClinicName)
                Button("Add") {
                    let trimmed = newClinicName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { context.insert(VetClinic(name: trimmed)) }
                    newClinicName = ""
                }
                Button("Cancel", role: .cancel) { newClinicName = "" }
            } message: {
                Text("Tap the clinic afterward to add phone, address, and notes.")
            }
            .alert("New location", isPresented: $showingAddHousehold) {
                TextField("Location name (House, Barn, a client…)", text: $newHouseholdName)
                Button("Add") {
                    let trimmed = newHouseholdName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { context.insert(Household(name: trimmed)) }
                    newHouseholdName = ""
                }
                Button("Cancel", role: .cancel) { newHouseholdName = "" }
            } message: {
                Text("Assign pets to it from their Edit screen.")
            }
        }
    }

    /// Grouped by location name, then chore name, so each location's
    /// chores read as a block.
    private var sortedChores: [ChoreTask] {
        chores.sorted {
            (($0.household?.name ?? ""), $0.name) < (($1.household?.name ?? ""), $1.name)
        }
    }

    /// "3 cats · every 2 days · Home" — or a nudge when no animals match.
    private func choreSubtitle(_ chore: ChoreTask) -> String {
        let count = chore.matchingPets(in: pets).count
        let location = chore.household?.name ?? "All locations"
        guard count > 0 else {
            let noun = chore.species.isEmpty ? "animals" : "\(chore.species.lowercased())s"
            return "No \(noun) here yet · \(location)"
        }
        return [chore.countDescription(count: count),
                chore.intervalDescription(count: count).lowercased(),
                location]
            .joined(separator: " · ")
    }
}

// MARK: - Chore editor

struct ChoreEditView: View {
    @Bindable var chore: ChoreTask
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Household.name) private var households: [Household]

    private var count: Int { chore.matchingPets(in: pets).count }

    /// Preset species plus any custom species your pets actually use
    /// (a "Bearded Dragon" chore should be pickable too).
    private var speciesOptions: [String] {
        var names = SpeciesCatalog.common.map(\.name)
        let extras = Set(pets.map(\.species)).union([chore.species])
        for extra in extras.sorted()
        where !extra.isEmpty
            && !names.contains(where: { $0.caseInsensitiveCompare(extra) == .orderedSame }) {
            names.append(extra)
        }
        return names
    }

    var body: some View {
        Form {
            Section {
                TextField("Name (Litter box change…)", text: $chore.name)
                Picker("Animal type", selection: $chore.species) {
                    Text("Any animal").tag("")
                    ForEach(speciesOptions, id: \.self) { name in
                        Text("\(SpeciesCatalog.emoji(for: name)) \(name)").tag(name)
                    }
                }
                Stepper(value: $chore.baseIntervalDays, in: 1...60) {
                    LabeledContent("For one animal",
                                   value: chore.baseIntervalDays == 1
                                       ? "Daily"
                                       : "Every \(chore.baseIntervalDays) days")
                }
            } footer: {
                Text(count > 1
                     ? "With \(chore.countDescription(count: count)) here, this runs \(chore.intervalDescription(count: count).lowercased()) — the base interval divided by the head count, never less than daily."
                     : "More animals shorten the interval automatically — the base interval is divided by the head count.")
            }

            if !households.isEmpty {
                Section {
                    Picker("Location", selection: Binding(
                        get: { chore.household?.id.uuidString ?? "" },
                        set: { idString in
                            chore.household = households.first { $0.id.uuidString == idString }
                        }
                    )) {
                        Text("All locations").tag("")
                        ForEach(households) { h in
                            Text(h.name).tag(h.id.uuidString)
                        }
                    }
                } footer: {
                    Text("Only animals at this location count toward the frequency.")
                }
            }

            Section {
                Toggle("Remind me", isOn: $chore.remindersEnabled)
                TextField("Notes (bin liner size, which closet…)",
                          text: $chore.notes, axis: .vertical)
            } footer: {
                Text("Reminders arrive at 9 AM on the day a cleaning comes due.")
            }

            if let last = chore.lastCompleted {
                Section {
                    LabeledContent("Last done",
                                   value: last.formatted(date: .abbreviated, time: .shortened))
                    if count > 0 {
                        LabeledContent("Next due",
                                       value: chore.nextDue(count: count)
                                           .formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }
        .navigationTitle(chore.name.isEmpty ? "Cleaning task" : chore.name)
        .inlineNavigationTitle()
        .onDisappear {
            NotificationManager.syncChoreReminder(for: chore, count: count)
        }
    }
}

// MARK: - Household editor

struct HouseholdEditView: View {
    @Bindable var household: Household

    var body: some View {
        Form {
            Section("Location") {
                TextField("Name", text: $household.name)
                TextField("Address", text: $household.address, axis: .vertical)
                TextField("Notes", text: $household.notes, axis: .vertical)
            }
            Section("Pets here (\(household.pets.count))") {
                if household.pets.isEmpty {
                    Text("None yet — assign pets from their Edit screen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(household.pets.sorted { $0.name < $1.name }) { pet in
                    HStack {
                        PetAvatar(pet: pet, size: 32)
                        Text(pet.name)
                        Text(pet.speciesEmoji).font(.caption)
                    }
                }
            }
        }
        .navigationTitle(household.name)
        .inlineNavigationTitle()
    }
}

// MARK: - Clinic editor

struct ClinicEditView: View {
    @Bindable var clinic: VetClinic

    var body: some View {
        Form {
            TextField("Name", text: $clinic.name)
            TextField("Phone", text: $clinic.phone)
                .keyboardType(.phonePad)
            TextField("Address", text: $clinic.address, axis: .vertical)
            TextField("Email", text: $clinic.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Notes", text: $clinic.notes, axis: .vertical)
        }
        .navigationTitle(clinic.name)
        .inlineNavigationTitle()
    }
}
