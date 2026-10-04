//
//  AttendanceView.swift
//  TailVault
//
//  Attendance taker: check off each pet (with profile photo),
//  set date and location ("House", "Barn"…), save the record.
//  History list below with CSV export.
//

import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \AttendanceRecord.date, order: .reverse) private var records: [AttendanceRecord]
    @Query(sort: \Household.name) private var households: [Household]

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""
    @State private var showingNewRecord = false
    @State private var exportURL: URL?

    private var currentLocation: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    /// History for the current location only (all records when none exist).
    private var visibleRecords: [AttendanceRecord] {
        guard let currentLocation else { return records }
        return records.filter { $0.location == currentLocation.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingNewRecord = true
                    } label: {
                        Label("Take attendance", systemImage: "checklist")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("History (\(visibleRecords.count))") {
                    ForEach(visibleRecords) { record in
                        NavigationLink {
                            AttendanceRecordDetailView(record: record)
                        } label: {
                            AttendanceRecordRow(record: record)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(visibleRecords[index]) }
                    }
                }
            }
            .themedSurface(tintTheme)
            .navigationTitle("Attendance")
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    LocationMenu()
                }
                ToolbarItem(placement: .trailingBar) {
                    Button {
                        exportURL = CSVExporter.exportAttendance(visibleRecords)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(visibleRecords.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewRecord) {
                NavigationStack { TakeAttendanceView() }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
        }
    }
}

// MARK: - History row

private struct AttendanceRecordRow: View {
    let record: AttendanceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                Text("\(record.presentCount)/\(record.entries.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(record.presentCount == record.entries.count ? .green : .orange)
            }
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                Text(record.location.isEmpty ? "No location" : record.location)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Take attendance sheet

struct TakeAttendanceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Household.name) private var households: [Household]
    @Query(sort: \AttendanceRecord.date, order: .reverse) private var pastRecords: [AttendanceRecord]

    @AppStorage("lastAttendanceLocation") private var lastLocation = "House"
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    @State private var date = Date.now
    @State private var location = ""
    @State private var notes = ""
    @State private var presentIDs: Set<UUID> = []
    @State private var showConfetti = false

    private var currentLocation: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    private var activePets: [Pet] {
        pets.filter(\.isActive).at(currentLocation)
    }

    /// Recent distinct locations for one-tap reuse.
    private var recentLocations: [String] {
        var seen: [String] = []
        for record in pastRecords where !record.location.isEmpty {
            if !seen.contains(record.location) { seen.append(record.location) }
            if seen.count >= 4 { break }
        }
        if seen.isEmpty { seen = ["House", "Barn"] }
        return seen
    }

    var body: some View {
        Form {
            Section("When & where") {
                DatePicker("Date", selection: $date)
                if let currentLocation {
                    // Location comes from the app-wide switcher.
                    LabeledContent("Location", value: currentLocation.name)
                } else {
                    // No locations set up yet — fall back to free text.
                    TextField("Location (House, Barn…)", text: $location)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(recentLocations, id: \.self) { loc in
                                Button(loc) { location = loc }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                ForEach(activePets) { pet in
                    Button {
                        toggle(pet)
                    } label: {
                        HStack(spacing: 12) {
                            PetAvatar(pet: pet, size: 44)
                            Text(pet.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(pet.speciesEmoji).font(.caption)
                            Spacer()
                            Image(systemName: presentIDs.contains(pet.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(presentIDs.contains(pet.id) ? .green : .secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Pets — \(presentIDs.count)/\(activePets.count) present")
                    Spacer()
                    Button(presentIDs.count == activePets.count ? "Clear all" : "All present") {
                        if presentIDs.count == activePets.count {
                            presentIDs.removeAll()
                        } else {
                            presentIDs = Set(activePets.map(\.id))
                        }
                    }
                    .font(.caption)
                }
            }

            Section("Notes") {
                TextField("Anything unusual…", text: $notes, axis: .vertical)
            }
        }
        .themedSurface(tintTheme)
        .overlay {
            if showConfetti { ConfettiView() }
        }
        .onChange(of: presentIDs) {
            // Everyone accounted for — celebrate (once per full house).
            if !activePets.isEmpty, presentIDs.count == activePets.count, !showConfetti {
                showConfetti = true
                Haptics.success()
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    showConfetti = false
                }
            }
        }
        .navigationTitle("Take Attendance")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(currentLocation == nil
                              && location.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { if currentLocation == nil { location = lastLocation } }
    }

    private func toggle(_ pet: Pet) {
        if presentIDs.contains(pet.id) {
            presentIDs.remove(pet.id)
        } else {
            presentIDs.insert(pet.id)
        }
    }

    private func save() {
        let record = AttendanceRecord(
            date: date,
            location: currentLocation?.name
                ?? location.trimmingCharacters(in: .whitespaces),
            notes: notes
        )
        context.insert(record)
        for pet in activePets {
            record.entries.append(AttendanceEntry(pet: pet, present: presentIDs.contains(pet.id)))
        }
        lastLocation = record.location
        Haptics.success()
        dismiss()
    }
}

// MARK: - Saved record detail

struct AttendanceRecordDetailView: View {
    let record: AttendanceRecord

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: record.date.formatted(date: .long, time: .shortened))
                LabeledContent("Location", value: record.location)
                LabeledContent("Present", value: "\(record.presentCount) of \(record.entries.count)")
                if !record.notes.isEmpty {
                    Text(record.notes).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section("Pets") {
                ForEach(record.entries.sorted { ($0.pet?.name ?? "") < ($1.pet?.name ?? "") },
                        id: \.persistentModelID) { entry in
                    HStack(spacing: 12) {
                        if let pet = entry.pet {
                            PetAvatar(pet: pet, size: 36)
                            Text(pet.name)
                        } else {
                            Text("(deleted pet)").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: entry.present ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(entry.present ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("Attendance")
        .inlineNavigationTitle()
    }
}
