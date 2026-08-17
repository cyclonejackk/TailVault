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

    @State private var exportURL: URL?
    @State private var showingAddClinic = false
    @State private var newClinicName = ""
    @State private var showingAddHousehold = false
    @State private var newHouseholdName = ""

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
                        for index in offsets { context.delete(households[index]) }
                    }
                    Button {
                        showingAddHousehold = true
                    } label: {
                        Label("Add household", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Households")
                } footer: {
                    Text("Deleting a household never deletes its pets — they just become unassigned.")
                }

                Section("About") {
                    LabeledContent("Pets tracked", value: "\(pets.count)")
                    LabeledContent("Attendance records", value: "\(records.count)")
                }
            }
            .themedSurface(tintTheme)
            .navigationTitle("Settings")
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
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
            .alert("New household", isPresented: $showingAddHousehold) {
                TextField("Household name (House, Barn, a client…)", text: $newHouseholdName)
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
}

// MARK: - Household editor

struct HouseholdEditView: View {
    @Bindable var household: Household

    var body: some View {
        Form {
            Section("Household") {
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
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationBarTitleDisplayMode(.inline)
    }
}
