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
    @Query(sort: \Household.name) private var households: [Household]
    @Query(sort: \ChoreTask.name) private var chores: [ChoreTask]
    @Query(sort: \TodoItem.title) private var todos: [TodoItem]
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    private var currentLocation: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    private var activePets: [Pet] { pets.filter(\.isActive).at(currentLocation) }

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

    /// Chores visible here (this location's plus global ones) that cover at
    /// least one animal, soonest due first.
    private var choresHere: [(chore: ChoreTask, count: Int)] {
        chores.compactMap { chore -> (chore: ChoreTask, count: Int)? in
            guard chore.household == nil || chore.household?.id == currentLocation?.id
            else { return nil }
            let count = chore.matchingPets(in: pets).count
            return count > 0 ? (chore, count) : nil
        }
        .sorted { $0.0.nextDue(count: $0.1) < $1.0.nextDue(count: $1.1) }
    }

    /// Open to-dos visible here, soonest due first, undated ones last.
    private var todosHere: [TodoItem] {
        todos.filter { $0.isOpen && $0.isVisible(at: currentLocation) }
            .sorted { ($0.nextDue ?? .distantFuture, $0.title) < ($1.nextDue ?? .distantFuture, $1.title) }
    }

    var body: some View {
        NavigationStack {
            List {
                if scheduledMeds.isEmpty && upcomingVisits.isEmpty && vaccinesDueSoon.isEmpty && choresHere.isEmpty && todosHere.isEmpty {
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

                if !choresHere.isEmpty {
                    Section {
                        ForEach(choresHere, id: \.chore.id) { item in
                            HStack(spacing: 12) {
                                Text(SpeciesCatalog.emoji(for: item.chore.species))
                                    .font(.title3)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.chore.name)
                                    Text("\(item.chore.countDescription(count: item.count)) · \(item.chore.intervalDescription(count: item.count).lowercased())")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(item.chore.isOverdue(count: item.count)
                                         ? "Overdue — was due \(item.chore.nextDue(count: item.count).formatted(date: .abbreviated, time: .omitted))"
                                         : "Next \(item.chore.nextDue(count: item.count).formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(item.chore.isOverdue(count: item.count) ? .orange : .secondary)
                                }
                                Spacer()
                                if item.chore.remindersEnabled {
                                    Image(systemName: "bell.fill")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                    } header: {
                        Text("Cleaning")
                    } footer: {
                        Text("Intervals scale with how many animals are here. Check chores off on the Dashboard; edit them in Settings → Cleaning reminders.")
                    }
                }

                if !todosHere.isEmpty {
                    Section {
                        ForEach(todosHere) { todo in
                            NavigationLink {
                                TodoEditView(todo: todo)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: todo.pet != nil ? "pawprint.fill" : "checklist")
                                        .font(.subheadline)
                                        .foregroundStyle(.indigo)
                                        .frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(todo.title)
                                        Text(todoSubtitle(todo))
                                            .font(.caption)
                                            .foregroundStyle(todo.isOverdue ? .orange : .secondary)
                                    }
                                    Spacer()
                                    if todo.remindersEnabled && todo.nextDue != nil {
                                        Image(systemName: "bell.fill")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("To-dos")
                    } footer: {
                        Text("Check them off on the Dashboard; tap one to edit.")
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
            .toolbar {
                ToolbarItem(placement: .trailingBar) { LocationMenu() }
            }
        }
    }

    /// "Milo · due today" — falls back when there's nothing to say.
    private func todoSubtitle(_ todo: TodoItem) -> String {
        let parts = [todo.attachmentDescription, todo.dueDescription]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "No due date" : parts.joined(separator: " · ")
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
