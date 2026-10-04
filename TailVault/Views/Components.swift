//
//  Components.swift
//  TailVault
//
//  Shared small views: pet avatar, fondness picker, tag editor.
//

import SwiftUI
import SwiftData

// MARK: - Avatar

struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    var body: some View {
        Group {
            if let data = pet.photoData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(placeholderColor.gradient)
                    Image(systemName: SpeciesCatalog.symbol(for: pet.species))
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            // Subtle accent ring — skipped in mono for the stock look.
            if tintTheme != .mono {
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [tintTheme.accent.opacity(0.7), tintTheme.accent.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.5, size * 0.035)
                )
            }
        }
    }

    /// Stable color per pet so placeholders are tell-apart-able.
    private var placeholderColor: Color {
        let palette: [Color] = [.orange, .indigo, .teal, .pink, .brown, .purple, .mint, .blue]
        let index = abs(pet.name.hashValue) % palette.count
        return palette[index]
    }
}

// MARK: - Fondness picker row

struct FondnessPicker: View {
    let title: String
    @Binding var value: Fondness

    var body: some View {
        Picker(title, selection: $value) {
            ForEach(Fondness.allCases) { f in
                Text("\(f.emoji) \(f.label)").tag(f)
            }
        }
    }
}

// MARK: - Editable string-list ("tags") field

/// Edits an array of strings as comma-separated text — used for
/// hiding spots, toys, conditions, allergies.
struct TagListField: View {
    let title: String
    let prompt: String
    @Binding var items: [String]

    var body: some View {
        TextField(
            title,
            text: Binding(
                get: { items.joined(separator: ", ") },
                set: { newValue in
                    items = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            ),
            prompt: Text(prompt),
            axis: .vertical
        )
    }
}

// MARK: - Labeled detail row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

// MARK: - Location switching

/// The one location you're working in right now, stored as the Household's
/// UUID string. Resolution falls back to the first location alphabetically,
/// so once locations exist the app is never "nowhere".
enum CurrentLocation {
    static let key = "currentLocationID"

    static func resolve(from households: [Household], idString: String) -> Household? {
        households.first { $0.id.uuidString == idString } ?? households.first
    }
}

extension Array where Element == Pet {
    /// Pets visible at a location. Pets with no location assigned show
    /// everywhere, so nothing silently disappears when you switch.
    func at(_ location: Household?) -> [Pet] {
        guard let location else { return self }
        return filter { $0.household == nil || $0.household?.id == location.id }
    }
}

/// Toolbar dropdown that switches the app's current location from any
/// main page. Hidden until a location exists (Settings → Locations).
struct LocationMenu: View {
    @Query(sort: \Household.name) private var households: [Household]
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""

    private var current: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    var body: some View {
        if !households.isEmpty {
            Menu {
                Picker("Location", selection: Binding(
                    get: { current?.id.uuidString ?? "" },
                    set: { currentLocationID = $0 }
                )) {
                    ForEach(households) { h in
                        Text(h.name).tag(h.id.uuidString)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(current?.name ?? "Location")
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.medium))
            }
        }
    }
}

// MARK: - To-do editor

/// Shared editor for a `TodoItem` — reached from the Dashboard and
/// Schedule tabs. Reschedules the reminder on the way out.
struct TodoEditView: View {
    @Bindable var todo: TodoItem
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Household.name) private var households: [Household]

    var body: some View {
        Form {
            Section {
                TextField("What needs doing?", text: $todo.title, axis: .vertical)
                TextField("Notes", text: $todo.notes, axis: .vertical)
            }

            Section {
                Toggle("Due date", isOn: Binding(
                    get: { todo.dueDate != nil },
                    set: { todo.dueDate = $0 ? Calendar.current.startOfDay(for: .now) : nil }
                ))
                if todo.dueDate != nil {
                    DatePicker("Due", selection: Binding(
                        get: { todo.dueDate ?? .now },
                        set: { todo.dueDate = $0 }
                    ), displayedComponents: .date)
                }
                Toggle("Repeats", isOn: Binding(
                    get: { todo.repeatDays > 0 },
                    set: { todo.repeatDays = $0 ? 7 : 0 }
                ))
                if todo.repeatDays > 0 {
                    Stepper(value: $todo.repeatDays, in: 1...365) {
                        LabeledContent("Interval",
                                       value: todo.repeatDays == 1
                                           ? "Daily"
                                           : "Every \(todo.repeatDays) days")
                    }
                }
            } header: {
                Text("When")
            } footer: {
                Text(todo.repeatDays > 0
                     ? "Checking it off schedules the next one \(todo.repeatDays == 1 ? "a day" : "\(todo.repeatDays) days") later."
                     : "No due date means it just stays on the list until done.")
            }

            if !pets.isEmpty || !households.isEmpty {
                Section {
                    Picker("Attach to", selection: attachment) {
                        Text("Nothing — show everywhere").tag("")
                        if !pets.isEmpty {
                            // Include the attached pet even if inactive, so
                            // the picker selection never dangles.
                            ForEach(pets.filter { $0.isActive || $0.id == todo.pet?.id }) { pet in
                                Text("\(pet.speciesEmoji) \(pet.name)")
                                    .tag("pet:\(pet.id.uuidString)")
                            }
                        }
                        if !households.isEmpty {
                            ForEach(households) { h in
                                Text("📍 \(h.name)").tag("loc:\(h.id.uuidString)")
                            }
                        }
                    }
                } footer: {
                    Text("A pet to-do follows that pet's location. A location to-do only shows when you're there.")
                }
            }

            Section {
                Toggle("Remind me", isOn: $todo.remindersEnabled)
            } footer: {
                Text("Reminders arrive at 9 AM on the due day, then daily while overdue. Needs a due date (or a repeat).")
            }

            if let last = todo.lastCompleted {
                Section {
                    LabeledContent("Last done",
                                   value: last.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .navigationTitle(todo.title.isEmpty ? "To-do" : todo.title)
        .inlineNavigationTitle()
        .onDisappear {
            NotificationManager.syncTodoReminder(for: todo)
        }
    }

    /// One picker over both pets and locations, encoded as "pet:<id>" /
    /// "loc:<id>" / "" — a to-do attaches to at most one of them.
    private var attachment: Binding<String> {
        Binding(
            get: {
                if let pet = todo.pet { return "pet:\(pet.id.uuidString)" }
                if let home = todo.household { return "loc:\(home.id.uuidString)" }
                return ""
            },
            set: { value in
                if value.hasPrefix("pet:") {
                    todo.pet = pets.first { "pet:\($0.id.uuidString)" == value }
                    todo.household = nil
                } else if value.hasPrefix("loc:") {
                    todo.household = households.first { "loc:\($0.id.uuidString)" == value }
                    todo.pet = nil
                } else {
                    todo.pet = nil
                    todo.household = nil
                }
            }
        )
    }
}
