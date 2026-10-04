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
    @Query(sort: \Household.name) private var households: [Household]
    @Query(sort: \ChoreTask.name) private var chores: [ChoreTask]
    @Query(sort: \TodoItem.title) private var todos: [TodoItem]
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    @State private var showingAttendance = false
    @State private var showPastMeds = false
    @State private var newTodo: TodoItem?
    /// Kept alongside `newTodo` so the dismiss handler can discard an
    /// add that was abandoned without a title.
    @State private var pendingTodo: TodoItem?

    private var currentLocation: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    private var activePets: [Pet] { pets.filter(\.isActive).at(currentLocation) }

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

    /// Ended (inactive) meds for pets shown here, newest ending first.
    private var pastMeds: [(pet: Pet, med: Medication)] {
        activePets.flatMap { pet in
            pet.medications.filter { !$0.isActive }.map { (pet, $0) }
        }
        .sorted { ($0.med.endDate ?? .distantPast) > ($1.med.endDate ?? .distantPast) }
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

    // MARK: Today's cleaning

    private struct ChoreDue: Identifiable {
        var id: UUID { chore.id }
        let chore: ChoreTask
        let count: Int
        var done: Bool { chore.completedToday }
    }

    /// Chores at the current location that are due (or already done today,
    /// so the checked row sticks around). Chores with no matching animals
    /// stay hidden.
    private var choresToday: [ChoreDue] {
        chores.compactMap { chore -> ChoreDue? in
            guard chore.household == nil || chore.household?.id == currentLocation?.id
            else { return nil }
            let count = chore.matchingPets(in: pets).count
            guard count > 0, chore.isDue(count: count) || chore.completedToday
            else { return nil }
            return ChoreDue(chore: chore, count: count)
        }
        .sorted { ($0.done ? 1 : 0, $0.chore.name) < ($1.done ? 1 : 0, $1.chore.name) }
    }

    // MARK: Today's to-dos

    private struct TodoDue: Identifiable {
        var id: UUID { todo.id }
        let todo: TodoItem
        /// Checked state: a closed one-off, or a repeating to-do already
        /// done today.
        var done: Bool { !todo.isOpen || todo.completedToday }
    }

    /// To-dos visible here that are due, undated, or done today (so the
    /// checked row sticks around until tomorrow).
    private var todosToday: [TodoDue] {
        todos.compactMap { todo -> TodoDue? in
            guard todo.isVisible(at: currentLocation),
                  todo.isDueNow || todo.completedToday
            else { return nil }
            return TodoDue(todo: todo)
        }
        .sorted {
            ($0.done ? 1 : 0, $0.todo.nextDue ?? .distantFuture, $0.todo.title)
                < ($1.done ? 1 : 0, $1.todo.nextDue ?? .distantFuture, $1.todo.title)
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

        let attendanceToday = records.contains {
            cal.isDateInToday($0.date)
                && (currentLocation == nil || $0.location == currentLocation?.name)
        }
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
            || !choresToday.isEmpty || !todosToday.isEmpty
    }

    private var allClear: Bool {
        medsToday.allSatisfy(\.done)
            && feedingsToday.allSatisfy(\.done)
            && walksToday.allSatisfy(\.done)
            && choresToday.allSatisfy(\.done)
            && todosToday.allSatisfy(\.done)
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
                if !medsToday.isEmpty || !pastMeds.isEmpty { medsSection }
                if !feedingsToday.isEmpty { feedingsSection }
                if !alwaysAvailableFoods.isEmpty { freeFedSection }
                if !walksToday.isEmpty { walksSection }
                if !choresToday.isEmpty { choresSection }
                todosSection
                if !alerts.isEmpty { alertsSection }
                if !upcomingVisits.isEmpty { upcomingSection }
                attendanceButtonSection
            }
            .themedSurface(tintTheme)
            .navigationTitle("TailVault")
            .onAppear {
                // Seed default chores for any species newly present at a
                // location, then refresh their reminder notifications.
                ChoreDefaults.autoCreate(context: context)
                NotificationManager.syncAllChores(chores, pets: pets)
                NotificationManager.syncAllTodos(todos)
            }
            .toolbar {
                ToolbarItem(placement: .trailingBar) { LocationMenu() }
            }
            .navigationDestination(for: Pet.self) { PetDetailView(pet: $0) }
            .sheet(isPresented: $showingAttendance) {
                NavigationStack { TakeAttendanceView() }
            }
            .sheet(item: $newTodo, onDismiss: {
                // Abandoned without a title → don't keep an empty row.
                if let todo = pendingTodo,
                   todo.title.trimmingCharacters(in: .whitespaces).isEmpty {
                    NotificationManager.removeTodoReminder(id: todo.id)
                    context.delete(todo)
                }
                pendingTodo = nil
            }) { todo in
                NavigationStack { TodoEditView(todo: todo) }
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
                if !choresToday.isEmpty {
                    ProgressChip(icon: "sparkles", label: "Cleaning",
                                 done: choresToday.filter(\.done).count,
                                 total: choresToday.count)
                }
                if !todosToday.isEmpty {
                    ProgressChip(icon: "checklist", label: "To-dos",
                                 done: todosToday.filter(\.done).count,
                                 total: todosToday.count)
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
            if !pastMeds.isEmpty {
                Button {
                    withAnimation { showPastMeds.toggle() }
                } label: {
                    HStack {
                        Text("Past meds")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showPastMeds ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                if showPastMeds {
                    ForEach(pastMeds, id: \.med.id) { item in
                        HStack(spacing: 12) {
                            PetAvatar(pet: item.pet, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.pet.name): \(item.med.displayName)")
                                    .font(.subheadline.weight(.medium))
                                Text(pastMedDetail(item.med))
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.6)
                    }
                }
            }
        }
    }

    /// "Twice daily · Ended Aug 12, 2026"
    private func pastMedDetail(_ med: Medication) -> String {
        let ended = med.endDate.map {
            "Ended \($0.formatted(date: .abbreviated, time: .omitted))"
        } ?? "Ended"
        return [med.frequencyDescription, ended]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
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

    private var choresSection: some View {
        Section {
            ForEach(choresToday) { item in
                ChoreRow(chore: item.chore, count: item.count) {
                    item.chore.markDone()
                    NotificationManager.syncChoreReminder(for: item.chore, count: item.count)
                    Haptics.success()
                } undo: {
                    item.chore.undoDone()
                    NotificationManager.syncChoreReminder(for: item.chore, count: item.count)
                }
            }
        } header: {
            Text("Cleaning due")
        } footer: {
            Text("Frequency scales with the animal count here — edit any chore in Settings → Cleaning reminders.")
        }
    }

    private var todosSection: some View {
        Section {
            ForEach(todosToday) { item in
                NavigationLink {
                    TodoEditView(todo: item.todo)
                } label: {
                    TodoRow(todo: item.todo, done: item.done) {
                        item.todo.markDone()
                        NotificationManager.syncTodoReminder(for: item.todo)
                        Haptics.success()
                    }
                }
                .swipeActions(edge: .leading) {
                    if item.todo.completedToday {
                        Button {
                            item.todo.undoDone()
                            NotificationManager.syncTodoReminder(for: item.todo)
                            Haptics.success()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.gray)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        NotificationManager.removeTodoReminder(id: item.todo.id)
                        context.delete(item.todo)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
                let todo = TodoItem()
                context.insert(todo)
                pendingTodo = todo
                newTodo = todo
            } label: {
                Label("Add to-do", systemImage: "plus.circle")
            }
        } header: {
            Text("To-do")
        }
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

// MARK: - Chore row

/// A tickable cleaning chore: icon, name, "3 cats · every 2 days" detail,
/// and a Done button that stamps the completion and reschedules the
/// reminder. Swipe to undo a mis-tap.
private struct ChoreRow: View {
    let chore: ChoreTask
    let count: Int
    let action: () -> Void
    let undo: () -> Void

    private var done: Bool { chore.completedToday }

    private var detail: String {
        if done { return "Done today · next \(chore.nextDue(count: count).formatted(date: .abbreviated, time: .omitted))" }
        let due = chore.isOverdue(count: count)
            ? "overdue since \(chore.nextDue(count: count).formatted(date: .abbreviated, time: .omitted))"
            : "due today"
        return [chore.countDescription(count: count),
                chore.intervalDescription(count: count).lowercased(),
                due]
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.teal.opacity(0.18))
                Text(SpeciesCatalog.emoji(for: chore.species))
                    .font(.title3)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(done ? Color.green : (chore.isOverdue(count: count) ? Color.orange : Color.secondary))
                if !chore.notes.isEmpty {
                    Text(chore.notes)
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
                Button("Done") { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .swipeActions(edge: .leading) {
            if done {
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

// MARK: - To-do row

/// A tickable to-do: pet avatar (when attached to a pet) or a checklist
/// bubble, title, "Milo · due today" detail, and a Done button. The row
/// itself navigates to the editor.
private struct TodoRow: View {
    let todo: TodoItem
    let done: Bool
    let action: () -> Void

    private var detail: String {
        if done, let last = todo.lastCompleted {
            return "Done \(Calendar.current.isDateInToday(last) ? "today" : last.formatted(date: .abbreviated, time: .omitted))"
        }
        let parts = [todo.attachmentDescription, todo.dueDescription]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "No due date" : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let pet = todo.pet {
                PetAvatar(pet: pet, size: 40)
            } else {
                ZStack {
                    Circle().fill(Color.indigo.opacity(0.18))
                    Image(systemName: todo.household == nil ? "checklist" : "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(done ? Color.green : (todo.isOverdue ? Color.orange : Color.secondary))
                if !todo.notes.isEmpty {
                    Text(todo.notes)
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
                Button("Done") { action() }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .font(.caption)
            }
        }
        .buttonStyle(.borderless)
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
