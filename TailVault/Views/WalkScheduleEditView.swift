//
//  WalkScheduleEditView.swift
//  TailVault
//
//  Create/edit one recurring outing: what it is, what times, how long,
//  which days. This is the routine — the actual walks that happen get
//  written to ActivityLog when they're ticked off on the dashboard.
//

import SwiftUI
import SwiftData

struct WalkScheduleEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// nil = creating a new schedule
    let schedule: WalkSchedule?

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var label = ""
    @State private var kind: ActivityKind = .walk
    @State private var times: [Date] = []
    @State private var durationMinutes = 20
    @State private var everyDay = true
    @State private var selectedDays: Set<Int> = []
    @State private var notes = ""
    @State private var hasEndDate = false
    @State private var endDate = Date.now

    /// Sunday-first weekday numbers matching `Calendar.component(.weekday:)`.
    private var weekdays: [(number: Int, symbol: String)] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (1...7).map { ($0, symbols[$0 - 1]) }
    }

    private var previewLine: String {
        let timeText = times.isEmpty
            ? ""
            : times.sorted().map { $0.formatted(date: .omitted, time: .shortened) }
                .joined(separator: ", ")
        let dayText = everyDay || selectedDays.isEmpty
            ? "every day"
            : selectedDays.sorted()
                .map { Calendar.current.shortWeekdaySymbols[$0 - 1] }
                .joined(separator: ", ")
        return [timeText, "\(durationMinutes) min", dayText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        Form {
            Section("Outing") {
                TextField("Name (e.g. Morning walk)", text: $label)
                Picker("Type", selection: $kind) {
                    ForEach(ActivityKind.allCases) { k in
                        Text("\(k.emoji) \(k.label)").tag(k)
                    }
                }
                Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 5...240, step: 5)
            }

            Section {
                ForEach(times.indices, id: \.self) { index in
                    DatePicker("Time \(index + 1)", selection: $times[index],
                               displayedComponents: .hourAndMinute)
                }
                .onDelete { times.remove(atOffsets: $0) }
                Button {
                    times.append(defaultTime())
                } label: {
                    Label("Add time", systemImage: "plus.circle")
                }
            } header: {
                Text("Times")
            } footer: {
                Text("Each time is one outing to tick off. Two times means the dashboard expects two walks that day.")
            }

            Section {
                Toggle("Every day", isOn: $everyDay)
                if !everyDay {
                    HStack(spacing: 6) {
                        ForEach(weekdays, id: \.number) { day in
                            Button {
                                if selectedDays.contains(day.number) {
                                    selectedDays.remove(day.number)
                                } else {
                                    selectedDays.insert(day.number)
                                }
                            } label: {
                                Text(day.symbol)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedDays.contains(day.number)
                                                  ? tintTheme.accent.opacity(0.85)
                                                  : Color.secondary.opacity(0.15))
                                    )
                                    .foregroundStyle(selectedDays.contains(day.number)
                                                     ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Days")
            } footer: {
                Text("Preview: \(previewLine)")
            }

            Section("Notes") {
                TextField("Harness not collar, avoid the dog park, short route if hot…",
                          text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Toggle("Retired", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Stopped on", selection: $endDate, displayedComponents: .date)
                }
            } footer: {
                Text("Retired routines stay on the record but drop off the dashboard and the sitter profile.")
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle(schedule == nil ? "New Routine" : "Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: load)
    }

    /// A routine with no days selected would never come due.
    private var canSave: Bool { everyDay || !selectedDays.isEmpty }

    private func defaultTime() -> Date {
        let hour = times.isEmpty ? 8 : 18
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }

    private func load() {
        guard let schedule else {
            times = [defaultTime()]
            return
        }
        label = schedule.label
        kind = schedule.kind
        times = schedule.times
        durationMinutes = schedule.durationMinutes
        everyDay = schedule.isEveryDay
        selectedDays = Set(schedule.daysOfWeek)
        notes = schedule.notes
        if let end = schedule.endDate { hasEndDate = true; endDate = end }
    }

    private func save() {
        let target = schedule ?? WalkSchedule()
        target.label = label.trimmingCharacters(in: .whitespaces)
        target.kind = kind
        target.times = times.sorted()
        target.durationMinutes = durationMinutes
        target.daysOfWeek = everyDay ? [] : selectedDays.sorted()
        target.notes = notes
        target.endDate = hasEndDate ? endDate : nil

        if schedule == nil {
            target.sortOrder = (pet.walkSchedules.map(\.sortOrder).max() ?? -1) + 1
            pet.walkSchedules.append(target)
        }

        dismiss()
    }
}
