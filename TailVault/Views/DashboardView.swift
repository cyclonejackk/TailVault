//
//  DashboardView.swift
//  TailVault
//
//  Home tab: what needs doing right now. A one-glance "Today" progress
//  strip, then the three routines you can tick off without leaving this
//  screen — medication doses (with dosage, so two strengths of the same
//  drug never blur together), meals, and scheduled walks. Below that:
//  alerts (overdue vaccines, visits to schedule, attendance not taken)
//  and the next 30 days.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \AttendanceRecord.date, order: .reverse) private var records: [AttendanceRecord]
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var showingAttendance = false

    private var activePets: [Pet] { pets.filter(\.isActive) }

    // MARK: Today's meds

    private struct MedDue: Identifiable {
        var id: UUID { med.id }
        let pet: Pet
        let med: Medication
        let expected: Int
        let given: Int
        var done: Bool { given >= expected }

        /// Minutes past midnight of the first dose — used for ordering;
        /// meds with no set time sort last.
        var firstDoseMinutes: Int {
            guard let first = med.doseTimes.sorted().first else { return 24 * 60 }
            let comps = Calendar.current.dateComponents([.hour, .minute], from: first)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
    }

    private var medsToday: [MedDue] {
        activePets.flatMap { pet in
            pet.activeMedications.compactMap { med -> MedDue? in
                guard med.frequency != .asNeeded, isDoseDay(med) else { return nil }
                return MedDue(pet: pet, med: med,
                              expected: med.expectedDosesToday,
                              given: med.dosesGivenToday)
            }
        }
        .sorted {
            ($0.done ? 1 : 0, $0.firstDoseMinutes, $0.pet.name)
                < ($1.done ? 1 : 0, $1.firstDoseMinutes, $1.pet.name)
        }
    }

    private func isDoseDay(_ med: Medication) -> Bool {
        let cal = Calendar.current
        if let interval = med.frequency.intervalDays(custom: med.customIntervalDays) {
            let days = cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: med.startDate),
                to: cal.startOfDay(for: .now)
            ).day ?? 0
            return days >= 0 && days % interval == 0
        }
        switch med.frequency {
        case .weekly:
            return cal.component(.weekday, from: .now) == cal.component(.weekday, from: med.startDate)
        case .monthly:
            return cal.component(.day, from: .now) == cal.component(.day, from: med.startDate)
        default:
            return true // daily variants
        }
    }

    // MARK: Today's feedings

    private struct FeedDue: Identifiable {
        var id: UUID { feeding.id }
        let pet: Pet
        let feeding: Feeding
        let expected: Int
        let given: Int
        var done: Bool { given >= expected }

        /// Minutes past midnight of the first scheduled meal — used for
        /// ordering; feedings with no set time sort last.
        var firstMealMinutes: Int {
            guard let first = feeding.times.sorted().first else { return 24 * 60 }
            let comps = Calendar.current.dateComponents([.hour, .minute], from: first)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
    }

    private var feedingsToday: [FeedDue] {
        activePets.flatMap { pet in
            pet.activeFeedings
                .filter(\.isDueToday)
                .map { FeedDue(pet: pet, feeding: $0,
                               expected: $0.expectedMealsToday,
                               given: $0.mealsGivenToday) }
        }
        .sorted {
            ($0.done ? 1 : 0, $0.firstMealMinutes, $0.pet.name)
                < ($1.done ? 1 : 0, $1.firstMealMinutes, $1.pet.name)
        }
    }

    /// Free-fed and as-needed foods never appear in the check-off list, but
    /// a sitter still needs to know they exist.
    private var alwaysAvailableFoods: [(pet: Pet, feeding: Feeding)] {
        activePets.flatMap { pet in
            pet.activeFeedings
                .filter { $0.frequency == .freeFed }
                .map { (pet, $0) }
        }
    }

    // MARK: Today's walks

    private struct WalkDue: Identifiable {
        var id: UUID { schedule.id }
        let pet: Pet
        let schedule: WalkSchedule
        let expected: Int
        let given: Int
        var done: Bool { given >= expected }
    }

    private var walksToday: [WalkDue] {
        activePets.flatMap { pet in
            pet.activeWalkSchedules
                .filter(\.isDueToday)
                .map { WalkDue(pet: pet, schedule: $0,
                               expected: $0.expectedToday,
                               given: $0.completedToday(for: pet)) }
        }
        .sorted {
            ($0.done ? 1 : 0, $0.schedule.firstTimeMinutes, $0.pet.name)
                < ($1.done ? 1 : 0, $1.schedule.firstTimeMinutes, $1.pet.name)
        }
    }

    // MARK: Today at a glance

    private struct RoutineProgress {
        let done: Int
        let total: Int
        var complete: Bool { done >= total }
    }

    private func progress<T>(_ items: [T], expected: (T) -> Int, given: (T) -> Int) -> RoutineProgress {
        RoutineProgress(done: items.reduce(0) { $0 + min(given($1), expected($1)) },
                        total: items.reduce(0) { $0 + expected($1) })
    }

    private var medProgress: RoutineProgress {
        progress(medsToday, expected: { $0.expected }, given: { $0.given })
    }

    private var mealProgress: RoutineProgress {
        progress(feedingsToday, expected: { $0.expected }, given: { $0.given })
    }

    private var walkProgress: RoutineProgress {
        progress(walksToday, expected: { $0.expected }, given: { $0.given })
    }

    // MARK: Alerts

    private struct DashAlert: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        let pet: Pet?
    }

    private var alerts: [DashAlert] {
        var items: [DashAlert] = []
        let cal = Calendar.current
        let soon = cal.date(byAdding: .day, value: 60, to: .now) ?? .now

        for pet in activePets {
            for vax in pet.vaccinations {
                guard let due = vax.nextDue else { continue }
                if due < .now {
                    items.append(DashAlert(
                        icon: "exclamationmark.circle.fill", color: .orange,
                        title: "\(pet.name): \(vax.name) vaccine overdue",
                        subtitle: "Was due \(due.formatted(date: .abbreviated, time: .omitted))",
                        pet: pet))
                } else if due <= soon && pet.upcomingVisits.isEmpty {
                    items.append(DashAlert(
                        icon: "calendar.badge.exclamationmark", color: .yellow,
                        title: "\(pet.name) needs a vet visit scheduled",
                        subtitle: "\(vax.name) due \(due.formatted(date: .abbreviated, time: .omitted)) — nothing on the books",
                        pet: pet))
                }
            }
        }

        let attendanceToday = records.contains { cal.isDateInToday($0.date) }
        if !attendanceToday && !activePets.isEmpty {
            items.append(DashAlert(
                icon: "checklist", color: .teal,
                title: "No attendance taken today",
                subtitle: "Tap to count noses",
                pet: nil))
        }

        return items
    }

    // MARK: Coming up

    private var upcomingVisits: [(pet: Pet, visit: VetVisit)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        return activePets.flatMap { pet in
            pet.upcomingVisits.filter { $0.date <= cutoff }.map { (pet, $0) }
        }
        .sorted { $0.visit.date < $1.visit.date }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var hasRoutines: Bool {
        !medsToday.isEmpty || !feedingsToday.isEmpty || !walksToday.isEmpty
    }

    private var allClear: Bool {
        medsToday.allSatisfy(\.done)
            && feedingsToday.allSatisfy(\.done)
            && walksToday.allSatisfy(\.done)
            && alerts.isEmpty
            && upcomingVisits.isEmpty
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                greetingSection
                if hasRoutines { todaySection }
                if allClear { allClearSection }
                if !medsToday.isEmpty { medsSection }
                if !feedingsToday.isEmpty { feedingsSection }
                if !alwaysAvailableFoods.isEmpty { freeFedSection }
                if !walksToday.isEmpty { walksSection }
                if !alerts.isEmpty { alertsSection }
                if !upcomingVisits.isEmpty { upcomingSection }
                attendanceButtonSection
            }
            .themedSurface(tintTheme)
            .navigationTitle("TailVault")
            .navigationDestination(for: Pet.self) { PetDetailView(pet: $0) }
            .sheet(isPresented: $showingAttendance) {
                NavigationStack { TakeAttendanceView() }
            }
        }
    }

    // MARK: Sections

    private var greetingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting + " 🐾")
                    .font(.title2.bold())
                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        }
    }

    /// The at-a-glance strip: "Meds 2/4 · Meals 1/3 · Walks 0/2".
    private var todaySection: some View {
        Section {
            HStack(spacing: 8) {
                if !medsToday.isEmpty {
                    ProgressChip(icon: "pills.fill", label: "Meds",
                                 done: medProgress.done, total: medProgress.total)
                }
                if !feedingsToday.isEmpty {
                    ProgressChip(icon: "fork.knife", label: "Meals",
                                 done: mealProgress.done, total: mealProgress.total)
                }
                if !walksToday.isEmpty {
                    ProgressChip(icon: "figure.walk", label: "Walks",
                                 done: walkProgress.done, total: walkProgress.total)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 6, trailing: 8))
        }
    }

    private var allClearSection: some View {
        Section {
            ContentUnavailableView(
                "All caught up",
                systemImage: "pawprint.fill",
                description: Text("Everything's fed, dosed, walked, and nothing needs scheduling.")
            )
        }
    }

    private var medsSection: some View {
        Section("Today's meds") {
            ForEach(medsToday) { item in
                RoutineRow(
                    pet: item.pet,
                    title: "\(item.pet.name): \(item.med.displayName)",
                    detail: medDetail(item),
                    note: item.med.instructions,
                    given: item.given,
                    expected: item.expected,
                    actionLabel: "Given",
                    tint: .green
                ) {
                    item.med.logDose()
                    Haptics.success()
                } undo: {
                    if let last = item.med.lastDoseToday { context.delete(last) }
                }
            }
        }
    }

    /// "1 of 2 doses · 8:00 AM, 8:00 PM"
    private func medDetail(_ item: MedDue) -> String {
        let doses = "\(item.given) of \(item.expected) \(item.expected == 1 ? "dose" : "doses")"
        return [doses, item.med.doseTimesDescription]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var feedingsSection: some View {
        Section("Today's feedings") {
            ForEach(feedingsToday) { item in
                RoutineRow(
                    pet: item.pet,
                    title: "\(item.pet.name): \(item.feeding.foodLabel)",
                    detail: feedDetail(item),
                    note: item.feeding.instructions,
                    given: item.given,
                    expected: item.expected,
                    actionLabel: "Fed",
                    tint: .orange
                ) {
                    item.feeding.logMeal()
                    Haptics.success()
                } undo: {
                    if let last = item.feeding.lastMealToday { context.delete(last) }
                }
            }
        }
    }

    /// "1/2 cup · 1 of 2 meals · 8:00 AM, 6:00 PM"
    private func feedDetail(_ item: FeedDue) -> String {
        let meals = "\(item.given) of \(item.expected) \(item.expected == 1 ? "meal" : "meals")"
        return [item.feeding.amountDescription, meals, item.feeding.timesDescription]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var freeFedSection: some View {
        Section {
            ForEach(alwaysAvailableFoods, id: \.feeding.id) { item in
                NavigationLink(value: item.pet) {
                    HStack(spacing: 12) {
                        PetAvatar(pet: item.pet, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.pet.name): \(item.feeding.foodLabel)")
                            Text("Always available — just keep it topped up")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Free-fed")
        }
    }

    private var walksSection: some View {
        Section("Today's walks") {
            ForEach(walksToday) { item in
                RoutineRow(
                    pet: item.pet,
                    title: "\(item.pet.name): \(item.schedule.displayLabel)",
                    detail: walkDetail(item),
                    note: item.schedule.notes,
                    given: item.given,
                    expected: item.expected,
                    actionLabel: "Done",
                    tint: .blue
                ) {
                    item.schedule.logOuting(for: item.pet)
                    Haptics.success()
                } undo: {
                    if let last = item.schedule.lastOutingToday(for: item.pet) {
                        context.delete(last)
                    }
                }
            }
        }
    }

    /// "1 of 2 · 8:00 AM, 6:00 PM · 20 min"
    private func walkDetail(_ item: WalkDue) -> String {
        ["\(item.given) of \(item.expected)",
         item.schedule.timesDescription,
         "\(item.schedule.durationMinutes) min"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var alertsSection: some View {
        Section("Needs attention") {
            ForEach(alerts) { alert in
                Button {
                    if alert.pet == nil { showingAttendance = true }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: alert.icon)
                            .font(.title3)
                            .foregroundStyle(alert.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .foregroundStyle(.primary)
                            Text(alert.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let pet = alert.pet {
                            NavigationLink(value: pet) { EmptyView() }
                                .frame(width: 20)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upcomingSection: some View {
        Section("Coming up (30 days)") {
            ForEach(upcomingVisits, id: \.visit.id) { item in
                NavigationLink(value: item.pet) {
                    HStack(spacing: 12) {
                        PetAvatar(pet: item.pet, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.pet.name): \(item.visit.reason)")
                            Text(item.visit.date.formatted(date: .abbreviated, time: .shortened) +
                                 (item.visit.clinicName.isEmpty ? "" : " · \(item.visit.clinicName)"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var attendanceButtonSection: some View {
        Section {
            Button {
                showingAttendance = true
            } label: {
                Label("Take attendance", systemImage: "checklist")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

// MARK: - Progress chip

/// One tile in the "Today" strip — turns green once the count is met.
private struct ProgressChip: View {
    let icon: String
    let label: String
    let done: Int
    let total: Int

    private var complete: Bool { total > 0 && done >= total }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: complete ? "checkmark.circle.fill" : icon)
                    .font(.caption)
                Text("\(done)/\(total)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(complete ? Color.green : Color.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(complete ? Color.green.opacity(0.14) : Color.secondary.opacity(0.12))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(done) of \(total) done")
    }
}

// MARK: - Routine row

/// A tickable dashboard row: avatar, title, detail line, and a button that
/// logs one completion. Rows with more than one occurrence a day keep the
/// button until every one is logged. Swipe to undo a mis-tap.
private struct RoutineRow: View {
    let pet: Pet
    let title: String
    let detail: String
    let note: String
    let given: Int
    let expected: Int
    let actionLabel: String
    let tint: Color
    let action: () -> Void
    let undo: () -> Void

    private var done: Bool { given >= expected }

    var body: some View {
        HStack(spacing: 12) {
            PetAvatar(pet: pet, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(done ? Color.green : Color.secondary)
                if !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Button(actionLabel) { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .swipeActions(edge: .leading) {
            if given > 0 {
                Button {
                    undo()
                    Haptics.success()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(.gray)
            }
        }
    }
}
