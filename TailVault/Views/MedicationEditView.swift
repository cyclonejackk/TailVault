//
//  MedicationEditView.swift
//  TailVault
//
//  Create/edit a medication with flexible frequencies (2× daily,
//  every other day, every N days…), dose times, and reminders.
//

import SwiftUI
import SwiftData

struct MedicationEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// nil = creating a new medication
    let medication: Medication?

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency: MedFrequency = .onceDaily
    @State private var customIntervalDays = 3
    @State private var doseTimes: [Date] = []
    @State private var instructions = ""
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now
    @State private var remindersEnabled = false

    var body: some View {
        Form {
            Section("Medication") {
                TextField("Name (e.g. Methimazole)", text: $name)
                TextField("Dosage (e.g. 2.5 mg)", text: $dosage)
                Picker("Frequency", selection: $frequency) {
                    ForEach(MedFrequency.allCases) { Text($0.label).tag($0) }
                }
                if frequency == .everyNDays {
                    Stepper("Every \(customIntervalDays) days", value: $customIntervalDays, in: 2...90)
                }
                TextField("Instructions (with food, pill pocket…)", text: $instructions, axis: .vertical)
            }

            Section("Schedule") {
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                Toggle("Has end date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("End date", selection: $endDate, displayedComponents: .date)
                }
            }

            if frequency != .asNeeded {
                Section {
                    ForEach(doseTimes.indices, id: \.self) { index in
                        DatePicker("Dose \(index + 1)", selection: $doseTimes[index],
                                   displayedComponents: .hourAndMinute)
                    }
                    .onDelete { doseTimes.remove(atOffsets: $0) }
                    Button {
                        doseTimes.append(defaultDoseTime())
                    } label: {
                        Label("Add dose time", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Dose times")
                } footer: {
                    Text("Reminders fire at these times when enabled — e.g. two entries (8 AM, 8 PM) for twice daily. Interval schedules (every other day, every N days) count from the start date.")
                }

                Section {
                    Toggle("Enable reminders 🔔", isOn: $remindersEnabled)
                }
            }

            if let med = medication, !med.doseLogs.isEmpty {
                Section("Recent doses") {
                    ForEach(med.doseLogs.sorted { $0.date > $1.date }.prefix(5),
                            id: \.persistentModelID) { log in
                        HStack {
                            Image(systemName: log.skipped ? "xmark.circle" : "checkmark.circle.fill")
                                .foregroundStyle(log.skipped ? .red : .green)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            if !log.note.isEmpty {
                                Text(log.note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink("Full log & vet report") {
                        MedLogView(pet: pet)
                    }
                    .font(.subheadline)
                }
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle(medication == nil ? "New Medication" : "Edit Medication")
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
    }

    private func defaultDoseTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private func load() {
        guard let med = medication else {
            doseTimes = [defaultDoseTime()]
            return
        }
        name = med.name
        dosage = med.dosage
        frequency = med.frequency
        customIntervalDays = med.customIntervalDays
        doseTimes = med.doseTimes
        instructions = med.instructions
        startDate = med.startDate
        if let end = med.endDate { hasEndDate = true; endDate = end }
        remindersEnabled = med.remindersEnabled
    }

    private func save() {
        let med = medication ?? Medication(name: name)
        med.name = name.trimmingCharacters(in: .whitespaces)
        med.dosage = dosage
        med.frequency = frequency
        med.customIntervalDays = customIntervalDays
        med.doseTimes = doseTimes
        med.instructions = instructions
        med.startDate = startDate
        med.endDate = hasEndDate ? endDate : nil
        med.remindersEnabled = remindersEnabled

        if medication == nil {
            pet.medications.append(med)
        }

        NotificationManager.syncReminders(for: med)
        dismiss()
    }
}
