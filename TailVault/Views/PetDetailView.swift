//
//  PetDetailView.swift
//  TailVault
//
//  Full profile: vitals, health, meds (with dose logging), visits,
//  personality, custom fields, family links, vet info, sharing.
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct PetDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var allPets: [Pet]
    @Bindable var pet: Pet
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var showingEdit = false
    @State private var showingAddMed = false
    @State private var showingAddFeeding = false
    @State private var showingAddVisit = false
    @State private var showingAddActivity = false
    @State private var showingAddWalkSchedule = false
    @State private var showingAddExpense = false
    @State private var showingAddObservation = false
    @State private var docPhotoItem: PhotosPickerItem?
    @State private var selectedDocument: PetDocument?
    @State private var flyerURL: URL?
    @State private var newWeight = ""
    @AppStorage("ownerName") private var ownerName = ""
    @AppStorage("ownerPhone") private var ownerPhone = ""

    var body: some View {
        List {
            header

            vitalsSection
            healthSection
            feedingSection
            medicationSection
            visitsSection
            walkRoutineSection
            activitySection
            weightSection
            vaccineSection
            personalitySection
            journalSection
            documentsSection
            expensesSection
            customFieldsSection
            familySection
            vetSection
            sitterNotesSection
        }
        .themedSurface(tintTheme)
        .navigationTitle(pet.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Button("Edit") { showingEdit = true }
            }
            ToolbarItem(placement: .trailingBar) {
                Menu {
                    ShareLink(item: SitterSummary.text(for: pet, allPets: allPets)) {
                        Label("Sitter profile (text)", systemImage: "person.text.rectangle")
                    }
                    ShareLink(item: VetReport.medicationHistory(for: pet)) {
                        Label("Med log for vet (text)", systemImage: "cross.case")
                    }
                    Button {
                        flyerURL = PDFExporter.pdf(
                            from: SitterSummary.text(for: pet, allPets: allPets),
                            filename: "\(pet.name) Profile.pdf")
                    } label: {
                        Label("Sitter profile (PDF)", systemImage: "doc.richtext")
                    }
                    Button {
                        flyerURL = PDFExporter.pdf(
                            from: VetReport.medicationHistory(for: pet),
                            filename: "\(pet.name) Med Report.pdf")
                    } label: {
                        Label("Med log for vet (PDF)", systemImage: "doc.text")
                    }
                    Button {
                        flyerURL = FlyerRenderer.render(
                            pet: pet, ownerName: ownerName, ownerPhone: ownerPhone)
                    } label: {
                        Label("Lost pet flyer", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { PetEditView(pet: pet) }
        }
        .sheet(isPresented: $showingAddMed) {
            NavigationStack { MedicationEditView(pet: pet, medication: nil) }
        }
        .sheet(isPresented: $showingAddFeeding) {
            NavigationStack { FeedingEditView(pet: pet, feeding: nil) }
        }
        .sheet(isPresented: $showingAddVisit) {
            NavigationStack { VetVisitEditView(pet: pet, visit: nil) }
        }
        .sheet(isPresented: $showingAddActivity) {
            NavigationStack { ActivityLogEditView(pet: pet) }
                .mediumSheetDetent()
        }
        .sheet(isPresented: $showingAddWalkSchedule) {
            NavigationStack { WalkScheduleEditView(pet: pet, schedule: nil) }
        }
        .sheet(isPresented: $showingAddExpense) {
            NavigationStack { ExpenseEditView(pet: pet) }
                .mediumSheetDetent()
        }
        .sheet(isPresented: $showingAddObservation) {
            NavigationStack { ObservationEditView(pet: pet) }
        }
        .sheet(item: $selectedDocument) { doc in
            NavigationStack { DocumentDetailView(document: doc) }
        }
        .sheet(item: $flyerURL) { url in
            ShareSheet(url: url)
        }
        .onChange(of: docPhotoItem) {
            Task {
                if let data = try? await docPhotoItem?.loadTransferable(type: Data.self) {
                    let doc = PetDocument(imageData: data)
                    pet.documents.append(doc)
                    docPhotoItem = nil
                    selectedDocument = doc   // open it right away to name it
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var header: some View {
        if let data = pet.photoData, let image = PlatformImage(data: data) {
            // Big photo banner with the name over a bottom scrim.
            Section {
                ZStack(alignment: .bottomLeading) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                        .clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.65)],
                                   startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(pet.name).font(.title.bold())
                            Text(pet.speciesEmoji).font(.title3)
                        }
                        Text([pet.breed, pet.colorMarkings].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                        HStack(spacing: 12) {
                            Text("\(pet.likesTreats.emoji) treats")
                            Text("\(pet.likesPets.emoji) pets")
                        }
                        .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                HStack(spacing: 16) {
                    PetAvatar(pet: pet, size: 88)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(pet.name).font(.title2.bold())
                            Text(pet.speciesEmoji).font(.title3)
                        }
                        if !pet.formerName.isEmpty {
                            Text("formerly \(pet.formerName)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text([pet.species, pet.breed, pet.colorMarkings].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text("\(pet.likesTreats.emoji) treats").font(.subheadline)
                            Text("\(pet.likesPets.emoji) pets").font(.subheadline)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var vitalsSection: some View {
        Section("Vitals") {
            if let dob = pet.dob {
                DetailRow(label: "Born", value: "\(dob.formatted(date: .abbreviated, time: .omitted)) (\(pet.ageDescription))")
            }
            if let gotcha = pet.gotchaDay {
                DetailRow(label: "Gotcha day", value: gotcha.formatted(date: .abbreviated, time: .omitted))
            }
            DetailRow(label: "Sex", value: pet.sex)
            DetailRow(label: "Indoor/outdoor", value: pet.indoorOutdoor.label)
            DetailRow(label: "Microchip", value: pet.microchip)
            DetailRow(label: "Rabies tag", value: pet.rabiesTag)
            DetailRow(label: "Collar/Tag #", value: pet.collarTag)
            DetailRow(label: "Location", value: pet.household?.name ?? "")
            if let w = pet.currentWeight {
                DetailRow(label: "Weight", value: String(format: "%.1f lbs (%@)", w.pounds,
                          w.date.formatted(date: .abbreviated, time: .omitted)))
            }
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        if !pet.activeConditions.isEmpty || !pet.allergies.isEmpty || !pet.healthNotes.isEmpty {
            Section("Health") {
                ForEach(pet.activeConditions, id: \.self) { condition in
                    Label(condition, systemImage: "heart.text.square")
                }
                if !pet.allergies.isEmpty {
                    Label("Allergies: \(pet.allergies.joined(separator: ", "))",
                          systemImage: "exclamationmark.triangle")
                }
                if !pet.healthNotes.isEmpty {
                    Text(pet.healthNotes).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var feedingSection: some View {
        Section {
            ForEach(pet.feedings.sorted { ($0.sortOrder, $0.foodLabel) < ($1.sortOrder, $1.foodLabel) },
                    id: \.persistentModelID) { feeding in
                NavigationLink {
                    FeedingEditView(pet: pet, feeding: feeding)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(feeding.kind.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(feeding.foodLabel)
                                if !feeding.isActive {
                                    Text("discontinued")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(feeding.summary)
                                .font(.caption).foregroundStyle(.secondary)
                            if !feeding.instructions.isEmpty {
                                Text(feeding.instructions)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete { offsets in
                let sorted = pet.feedings.sorted { ($0.sortOrder, $0.foodLabel) < ($1.sortOrder, $1.foodLabel) }
                for index in offsets { context.delete(sorted[index]) }
            }
            if pet.feedings.isEmpty {
                Text("No food recorded yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Food & feeding")
                Spacer()
                Button { showingAddFeeding = true } label: { Image(systemName: "plus.circle") }
            }
        } footer: {
            if pet.feedings.isEmpty {
                Text("Brand, amount, and schedule for each food — dry, wet, prescription diet, supplements. This is what sitters need most.")
            }
        }
    }

    private var medicationSection: some View {
        Section {
            ForEach(pet.medications.sorted { $0.displayName < $1.displayName }) { med in
                NavigationLink {
                    MedicationEditView(pet: pet, medication: med)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(med.displayName).font(.body)
                            if !med.isActive {
                                Text("ended").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Text([med.frequencyDescription, med.doseTimesDescription]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                             + (med.remindersEnabled ? " · 🔔" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                        if let last = med.lastDose {
                            Text("Last given \(last.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.green)
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        med.logDose()
                    } label: {
                        Label("Log dose", systemImage: "checkmark.circle")
                    }
                    .tint(.green)
                }
            }
            .onDelete { offsets in
                let sorted = pet.medications.sorted { $0.displayName < $1.displayName }
                for index in offsets { context.delete(sorted[index]) }
            }
            if !pet.medications.isEmpty {
                NavigationLink {
                    MedLogView(pet: pet)
                } label: {
                    Label("Medication log & vet report", systemImage: "list.clipboard")
                        .font(.subheadline)
                }
            }
        } header: {
            HStack {
                Text("Medications")
                Spacer()
                Button { showingAddMed = true } label: { Image(systemName: "plus.circle") }
            }
        } footer: {
            if !pet.medications.isEmpty {
                Text("Swipe right on a med to log a dose.")
            }
        }
    }

    private var visitsSection: some View {
        Section {
            ForEach(pet.vetVisits.sorted { $0.date > $1.date }) { visit in
                NavigationLink {
                    VetVisitEditView(pet: pet, visit: visit)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(visit.reason)
                            if visit.isUpcoming {
                                Text("upcoming")
                                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.teal.opacity(0.2), in: Capsule())
                            }
                        }
                        Text(visit.date.formatted(date: .abbreviated, time: .omitted) +
                             (visit.clinicName.isEmpty ? "" : " · \(visit.clinicName)"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let sorted = pet.vetVisits.sorted { $0.date > $1.date }
                for index in offsets { context.delete(sorted[index]) }
            }
        } header: {
            HStack {
                Text("Vet visits & appointments")
                Spacer()
                Button { showingAddVisit = true } label: { Image(systemName: "plus.circle") }
            }
        }
    }

    /// The plan — recurring walks and outings the dashboard ticks off.
    /// Distinct from `activitySection`, which is the history of what
    /// actually happened.
    private var walkRoutineSection: some View {
        Section {
            ForEach(pet.walkSchedules.sorted { ($0.sortOrder, $0.firstTimeMinutes) < ($1.sortOrder, $1.firstTimeMinutes) },
                    id: \.persistentModelID) { schedule in
                NavigationLink {
                    WalkScheduleEditView(pet: pet, schedule: schedule)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(schedule.kind.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(schedule.displayLabel)
                                if !schedule.isActive {
                                    Text("retired")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(schedule.summary)
                                .font(.caption).foregroundStyle(.secondary)
                            if !schedule.notes.isEmpty {
                                Text(schedule.notes)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete { offsets in
                let sorted = pet.walkSchedules.sorted { ($0.sortOrder, $0.firstTimeMinutes) < ($1.sortOrder, $1.firstTimeMinutes) }
                for index in offsets { context.delete(sorted[index]) }
            }
            if pet.walkSchedules.isEmpty {
                Text("No walk routine set.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Walk routine")
                Spacer()
                Button { showingAddWalkSchedule = true } label: { Image(systemName: "plus.circle") }
            }
        } footer: {
            if pet.walkSchedules.isEmpty {
                Text("Recurring walks, potty breaks, and enrichment sessions. These show on the dashboard each day so they can be checked off.")
            }
        }
    }

    private var activitySection: some View {
        Section {
            ForEach(pet.activityLogs.sorted { $0.date > $1.date }.prefix(5),
                    id: \.persistentModelID) { log in
                HStack(spacing: 10) {
                    Text(log.kind.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(log.kind.label) · \(log.durationMinutes) min")
                        Text(log.date.formatted(date: .abbreviated, time: .shortened) +
                             (log.notes.isEmpty ? "" : " — \(log.notes)"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let sorted = Array(pet.activityLogs.sorted { $0.date > $1.date }.prefix(5))
                for index in offsets { context.delete(sorted[index]) }
            }
            if pet.activityLogs.isEmpty {
                Text("No walks or enrichment logged yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Recent walks & enrichment")
                Spacer()
                Button { showingAddActivity = true } label: { Image(systemName: "plus.circle") }
            }
        }
    }

    private var weightSection: some View {
        Section("Weight log") {
            if pet.weightLog.count >= 2 {
                Chart(pet.weightLog.sorted { $0.date < $1.date }, id: \.persistentModelID) { entry in
                    LineMark(x: .value("Date", entry.date),
                             y: .value("Weight", entry.pounds))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", entry.date),
                              y: .value("Weight", entry.pounds))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                .padding(.vertical, 4)
            }
            ForEach(pet.weightLog.sorted { $0.date > $1.date }.prefix(5), id: \.persistentModelID) { entry in
                LabeledContent(entry.date.formatted(date: .abbreviated, time: .omitted)) {
                    Text(String(format: "%.1f lbs", entry.pounds))
                }
            }
            HStack {
                TextField("Add weight (lbs)", text: $newWeight)
                    .keyboardType(.decimalPad)
                Button("Log") {
                    if let pounds = Double(newWeight) {
                        pet.weightLog.append(WeightEntry(date: .now, pounds: pounds))
                        newWeight = ""
                    }
                }
                .disabled(Double(newWeight) == nil)
            }
        }
    }

    @ViewBuilder
    private var vaccineSection: some View {
        if !pet.vaccinations.isEmpty {
            Section("Vaccines") {
                ForEach(pet.vaccinations, id: \.persistentModelID) { vax in
                    LabeledContent(vax.name) {
                        if let due = vax.nextDue {
                            Text("due \(due.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(vax.isOverdue ? .red : .secondary)
                        } else {
                            Text("—")
                        }
                    }
                }
            }
        }
    }

    private var personalitySection: some View {
        Section("Personality & favorites") {
            DetailRow(label: "Treats", value: pet.favoriteTreats)
            DetailRow(label: "Likes treats", value: "\(pet.likesTreats.emoji) \(pet.likesTreats.label)")
            DetailRow(label: "Likes pets", value: "\(pet.likesPets.emoji) \(pet.likesPets.label)")
            DetailRow(label: "Hiding spots", value: pet.favoriteHidingSpots.joined(separator: ", "))
            LabeledContent("Favorite toys",
                           value: pet.favoriteToys.isEmpty ? "—" : pet.favoriteToys.joined(separator: ", "))
            if !pet.temperamentNotes.isEmpty {
                Text(pet.temperamentNotes).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var journalSection: some View {
        Section {
            ForEach(pet.observations.sorted { $0.date > $1.date }.prefix(5),
                    id: \.persistentModelID) { obs in
                HStack(alignment: .top, spacing: 10) {
                    if let data = obs.photoData, let image = PlatformImage(data: data) {
                        Image(platformImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(obs.note)
                        Text(obs.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let sorted = Array(pet.observations.sorted { $0.date > $1.date }.prefix(5))
                for index in offsets { context.delete(sorted[index]) }
            }
        } header: {
            HStack {
                Text("Journal (\(pet.observations.count))")
                Spacer()
                Button { showingAddObservation = true } label: { Image(systemName: "plus.circle") }
            }
        } footer: {
            if pet.observations.isEmpty {
                Text("Symptoms, behavior changes, anything worth telling the vet — photos included.")
            }
        }
    }

    private var documentsSection: some View {
        Section {
            if !pet.documents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pet.documents.sorted { $0.date > $1.date },
                                id: \.persistentModelID) { doc in
                            Button { selectedDocument = doc } label: {
                                VStack(spacing: 4) {
                                    if let data = doc.imageData, let image = PlatformImage(data: data) {
                                        Image(platformImage: image)
                                            .resizable().scaledToFill()
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.quaternary)
                                            .frame(width: 84, height: 84)
                                            .overlay(Image(systemName: "doc"))
                                    }
                                    Text(doc.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 84)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            PhotosPicker(selection: $docPhotoItem, matching: .images) {
                Label("Add document photo", systemImage: "doc.badge.plus")
            }
        } header: {
            Text("Documents (\(pet.documents.count))")
        } footer: {
            if pet.documents.isEmpty {
                Text("Vaccine certificates, adoption papers, insurance cards — snap a photo, name it, done.")
            }
        }
    }

    private var expensesSection: some View {
        let thisYear = pet.expenses.filter {
            Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .year)
        }
        let yearTotal = thisYear.reduce(0) { $0 + $1.amount }

        return Section {
            if !pet.expenses.isEmpty {
                LabeledContent("This year") {
                    Text(yearTotal, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
            }
            ForEach(pet.expenses.sorted { $0.date > $1.date }.prefix(5),
                    id: \.persistentModelID) { expense in
                HStack {
                    Text(expense.category.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.note.isEmpty ? expense.category.label : expense.note)
                        Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(expense.amount, format: .currency(code: "USD"))
                }
            }
            .onDelete { offsets in
                let sorted = Array(pet.expenses.sorted { $0.date > $1.date }.prefix(5))
                for index in offsets { context.delete(sorted[index]) }
            }
        } header: {
            HStack {
                Text("Expenses")
                Spacer()
                Button { showingAddExpense = true } label: { Image(systemName: "plus.circle") }
            }
        }
    }

    @ViewBuilder
    private var customFieldsSection: some View {
        let fields = pet.customFields.sorted { $0.sortOrder < $1.sortOrder }
        if !fields.isEmpty {
            Section("More") {
                ForEach(fields, id: \.persistentModelID) { field in
                    DetailRow(label: field.name, value: field.value)
                }
            }
        }
    }

    @ViewBuilder
    private var familySection: some View {
        let sibs = pet.siblings(in: allPets)
        if !pet.parents.isEmpty || !pet.children.isEmpty || !sibs.isEmpty {
            Section("Family") {
                ForEach(pet.parents) { familyLink($0, role: "Parent") }
                ForEach(pet.children) { familyLink($0, role: "Offspring") }
                ForEach(sibs) { familyLink($0, role: "Sibling") }
            }
        }
    }

    private func familyLink(_ relative: Pet, role: String) -> some View {
        NavigationLink(value: relative) {
            HStack {
                PetAvatar(pet: relative, size: 32)
                Text(relative.name)
                Spacer()
                Text(role).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var vetSection: some View {
        if let clinic = pet.primaryClinic {
            Section("Vet") {
                DetailRow(label: "Clinic", value: clinic.name)
                if !clinic.phone.isEmpty {
                    if let url = URL(string: "tel:\(clinic.phone.filter(\.isNumber))") {
                        Link(destination: url) {
                            LabeledContent("Phone", value: clinic.phone)
                        }
                    }
                }
                DetailRow(label: "Address", value: clinic.address)
            }
        }
    }

    @ViewBuilder
    private var sitterNotesSection: some View {
        if !pet.sitterNotes.isEmpty {
            Section("Sitter notes") {
                Text(pet.sitterNotes)
            }
        }
    }
}

// MARK: - Activity log entry sheet

struct ActivityLogEditView: View {
    @Environment(\.dismiss) private var dismiss
    let pet: Pet

    @State private var kind: ActivityKind = .walk
    @State private var date = Date.now
    @State private var durationMinutes = 15
    @State private var notes = ""

    var body: some View {
        Form {
            Picker("Activity", selection: $kind) {
                ForEach(ActivityKind.allCases) { k in
                    Text("\(k.emoji) \(k.label)").tag(k)
                }
            }
            DatePicker("When", selection: $date)
            Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 5...240, step: 5)
            TextField("Notes (route, new toy, mood…)", text: $notes, axis: .vertical)
        }
        .navigationTitle("Log Activity")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let log = ActivityLog(date: date, kind: kind,
                                          durationMinutes: durationMinutes, notes: notes)
                    pet.activityLogs.append(log)
                    dismiss()
                }
            }
        }
    }
}
