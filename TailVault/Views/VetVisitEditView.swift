//
//  VetVisitEditView.swift
//  TailVault
//
//  Create/edit a vet visit — past record or upcoming appointment
//  with an optional day-before reminder.
//

import SwiftUI
import SwiftData

struct VetVisitEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// nil = creating a new visit
    let visit: VetVisit?

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var date = Date.now
    @State private var reason = ""
    @State private var clinicName = ""
    @State private var outcomeNotes = ""
    @State private var reminderEnabled = false

    var body: some View {
        Form {
            Section("Visit") {
                DatePicker("Date", selection: $date)
                TextField("Reason (annual exam, recheck…)", text: $reason)
                TextField("Clinic", text: $clinicName)
            }

            Section("Notes / outcome") {
                TextField("Findings, treatments, weight, follow-ups…",
                          text: $outcomeNotes, axis: .vertical)
                    .lineLimit(3...10)
            }

            if date >= Calendar.current.startOfDay(for: .now) {
                Section {
                    Toggle("Remind me the day before 🔔", isOn: $reminderEnabled)
                }
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle(visit == nil ? "New Vet Visit" : "Edit Vet Visit")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let visit else {
            clinicName = pet.primaryClinic?.name ?? ""
            return
        }
        date = visit.date
        reason = visit.reason
        clinicName = visit.clinicName
        outcomeNotes = visit.outcomeNotes
        reminderEnabled = visit.reminderEnabled
    }

    private func save() {
        let target = visit ?? VetVisit(date: date, reason: reason)
        target.date = date
        target.reason = reason.trimmingCharacters(in: .whitespaces)
        target.clinicName = clinicName
        target.outcomeNotes = outcomeNotes
        target.reminderEnabled = reminderEnabled

        if visit == nil {
            pet.vetVisits.append(target)
        }

        NotificationManager.syncReminder(for: target)
        dismiss()
    }
}
