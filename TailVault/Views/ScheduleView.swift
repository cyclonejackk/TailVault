//
//  ScheduleView.swift
//  TailVault
//
//  One place to see everything coming up across all pets:
//  medication doses (with one-tap "Given" logging), upcoming
//  vet visits, vaccines due.
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Query(sort: \Pet.name) private var pets: [Pet]
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    private var activePets: [Pet] { pets.filter(\.isActive) }

    private var scheduledMeds: [(pet: Pet, med: Medication)] {
        activePets.flatMap { pet in
            pet.activeMedications
                .filter { $0.frequency != .asNeeded }
                .map { (pet, $0) }
        }
    }

    private var upcomingVisits: [(pet: Pet, visit: VetVisit)] {
        activePets.flatMap { pet in
            pet.upcomingVisits.map { (pet, $0) }
        }
        .sorted { $0.visit.date < $1.visit.date }
    }

    private var vaccinesDueSoon: [(pet: Pet, vax: Vaccination)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now
        return activePets.flatMap { pet in
            pet.vaccinations
                .filter { ($0.nextDue ?? .distantFuture) <= cutoff }
                .map { (pet, $0) }
        }
        .sorted { ($0.vax.nextDue ?? .distantFuture) < ($1.vax.nextDue ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack {
            List {
                if scheduledMeds.isEmpty && upcomingVisits.isEmpty && vaccinesDueSoon.isEmpty {
                    ContentUnavailableView(
                        "Nothing scheduled",
                        systemImage: "checkmark.seal",
                        description: Text("No active medications, upcoming visits, or vaccines due.")
                    )
                }

                if !scheduledMeds.isEmpty {
                    Section {
                        ForEach(scheduledMeds, id: \.med.id) { item in
                            HStack(spacing: 12) {
                                PetAvatar(pet: item.pet, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(item.pet.name): \(item.med.displayName)")
                                    Text(doseTimesText(item.med))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let last = item.med.lastDose {
                                        Text("Last given \(last.date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption).foregroundStyle(.green)
                                    }
                                }
                                Spacer()
                                if item.med.remindersEnabled {
                                    Image(systemName: "bell.fill")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                                Button("Given ✓") {
                                    item.med.logDose()
                                    Haptics.success()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    } header: {
                        Text("Medications")
                    } footer: {
                        Text("Tap “Given ✓” when a dose goes down — it feeds the vet report.")
                    }
                }

                if !upcomingVisits.isEmpty {
                    Section("Upcoming vet visits") {
                        ForEach(upcomingVisits, id: \.visit.id) { item in
                            HStack(spacing: 12) {
                                PetAvatar(pet: item.pet, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(item.pet.name): \(item.visit.reason)")
                                    Text(item.visit.date.formatted(date: .complete, time: .omitted))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !vaccinesDueSoon.isEmpty {
                    Section("Vaccines due soon") {
                        ForEach(vaccinesDueSoon, id: \.vax.persistentModelID) { item in
                            HStack(spacing: 12) {
                                PetAvatar(pet: item.pet, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(item.pet.name): \(item.vax.name)")
                                    if let due = item.vax.nextDue {
                                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(item.vax.isOverdue ? .red : .secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .themedSurface(tintTheme)
            .navigationTitle("Schedule")
        }
    }

    private func doseTimesText(_ med: Medication) -> String {
        let times = med.doseTimes
            .map { $0.formatted(date: .omitted, time: .shortened) }
            .joined(separator: ", ")
        var text = med.frequencyDescription
        if !times.isEmpty { text += " at \(times)" }
        if !med.dosage.isEmpty { text = med.dosage + " · " + text }
        return text
    }
}
