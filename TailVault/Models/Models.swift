//
//  Models.swift
//  TailVault — every pet, one vault
//
//  SwiftData models. Requires iOS 17+.
//

import Foundation
import SwiftData

// MARK: - Species

/// Preset species with emoji; any custom string also works —
/// `Pet.species` is free text, these are just picker suggestions.
enum SpeciesCatalog {
    static let common: [(name: String, emoji: String)] = [
        ("Cat", "🐱"), ("Dog", "🐶"), ("Bird", "🦜"), ("Rabbit", "🐰"),
        ("Guinea Pig", "🐹"), ("Hamster", "🐹"), ("Ferret", "🦡"),
        ("Reptile", "🦎"), ("Snake", "🐍"), ("Turtle", "🐢"),
        ("Fish", "🐠"), ("Horse", "🐴"), ("Goat", "🐐"),
        ("Chicken", "🐔"), ("Pig", "🐷"), ("Other", "🐾")
    ]

    static func emoji(for species: String) -> String {
        common.first { $0.name.caseInsensitiveCompare(species) == .orderedSame }?.emoji ?? "🐾"
    }

    /// SF Symbol for avatar placeholders when a pet has no photo.
    static func symbol(for species: String) -> String {
        switch species.lowercased() {
        case "cat":               return "cat.fill"
        case "dog":               return "dog.fill"
        case "bird", "chicken":   return "bird.fill"
        case "fish":              return "fish.fill"
        case "rabbit":            return "hare.fill"
        case "reptile", "snake":  return "lizard.fill"
        case "turtle":            return "tortoise.fill"
        default:                  return "pawprint.fill"
        }
    }
}

// MARK: - Enums

/// How much a pet likes something (treats, pets, brushing...).
enum Fondness: String, Codable, CaseIterable, Identifiable {
    case loves, likes, tolerates, dislikes, unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loves:     return "Loves it"
        case .likes:     return "Likes it"
        case .tolerates: return "Tolerates it"
        case .dislikes:  return "Dislikes it"
        case .unknown:   return "Unknown"
        }
    }

    var emoji: String {
        switch self {
        case .loves:     return "😍"
        case .likes:     return "🙂"
        case .tolerates: return "😐"
        case .dislikes:  return "🙅"
        case .unknown:   return "❔"
        }
    }
}

enum IndoorOutdoor: String, Codable, CaseIterable, Identifiable {
    case indoor, outdoor, both
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum MedFrequency: String, Codable, CaseIterable, Identifiable {
    case onceDaily, twiceDaily, threeTimesDaily, everyOtherDay, everyNDays,
         weekly, monthly, asNeeded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onceDaily:       return "Once daily"
        case .twiceDaily:      return "Twice daily"
        case .threeTimesDaily: return "3× daily"
        case .everyOtherDay:   return "Every other day"
        case .everyNDays:      return "Every N days"
        case .weekly:          return "Weekly"
        case .monthly:         return "Monthly"
        case .asNeeded:        return "As needed"
        }
    }

    /// Days between doses for interval-style frequencies; nil for the rest.
    func intervalDays(custom: Int) -> Int? {
        switch self {
        case .everyOtherDay: return 2
        case .everyNDays:    return max(custom, 1)
        default:             return nil
        }
    }
}

// MARK: - Food & feeding

/// What kind of food it is — kibble, wet, hay, crickets…
enum FoodKind: String, Codable, CaseIterable, Identifiable {
    case dry, wet, raw, homeCooked, prescription, pellets, hay, seed,
         insects, supplement, treat, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dry:          return "Dry / kibble"
        case .wet:          return "Wet / canned"
        case .raw:          return "Raw"
        case .homeCooked:   return "Home-cooked"
        case .prescription: return "Prescription diet"
        case .pellets:      return "Pellets"
        case .hay:          return "Hay / forage"
        case .seed:         return "Seed"
        case .insects:      return "Insects / live food"
        case .supplement:   return "Supplement"
        case .treat:        return "Treats"
        case .other:        return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .dry:          return "🥣"
        case .wet:          return "🥫"
        case .raw:          return "🥩"
        case .homeCooked:   return "🍲"
        case .prescription: return "🩺"
        case .pellets:      return "🟤"
        case .hay:          return "🌾"
        case .seed:         return "🌻"
        case .insects:      return "🦗"
        case .supplement:   return "💧"
        case .treat:        return "🍬"
        case .other:        return "🍽"
        }
    }
}

/// How much — kept as a value + unit so amounts stay comparable.
enum FoodUnit: String, Codable, CaseIterable, Identifiable {
    case cup, tablespoon, teaspoon, ounce, gram, can, pouch, scoop,
         piece, milliliter, handful

    var id: String { rawValue }

    /// Short form used in summaries ("1/2 cup", "3 oz").
    var abbreviation: String {
        switch self {
        case .cup:        return "cup"
        case .tablespoon: return "tbsp"
        case .teaspoon:   return "tsp"
        case .ounce:      return "oz"
        case .gram:       return "g"
        case .can:        return "can"
        case .pouch:      return "pouch"
        case .scoop:      return "scoop"
        case .piece:      return "piece"
        case .milliliter: return "mL"
        case .handful:    return "handful"
        }
    }

    var label: String {
        switch self {
        case .cup:        return "Cups"
        case .tablespoon: return "Tablespoons"
        case .teaspoon:   return "Teaspoons"
        case .ounce:      return "Ounces"
        case .gram:       return "Grams"
        case .can:        return "Cans"
        case .pouch:      return "Pouches"
        case .scoop:      return "Scoops"
        case .piece:      return "Pieces"
        case .milliliter: return "Milliliters"
        case .handful:    return "Handfuls"
        }
    }

    /// Units that read naturally in the plural ("2 cans", but not "2 ozs").
    private var pluralizes: Bool {
        switch self {
        case .cup, .can, .pouch, .scoop, .piece, .handful: return true
        case .tablespoon, .teaspoon, .ounce, .gram, .milliliter: return false
        }
    }

    func description(for value: Double) -> String {
        (pluralizes && value != 1) ? abbreviation + "s" : abbreviation
    }
}

enum FeedFrequency: String, Codable, CaseIterable, Identifiable {
    case onceDaily, twiceDaily, threeTimesDaily, fourTimesDaily,
         everyOtherDay, everyNDays, weekly, freeFed, asNeeded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onceDaily:       return "Once daily"
        case .twiceDaily:      return "Twice daily"
        case .threeTimesDaily: return "3× daily"
        case .fourTimesDaily:  return "4× daily"
        case .everyOtherDay:   return "Every other day"
        case .everyNDays:      return "Every N days"
        case .weekly:          return "Weekly"
        case .freeFed:         return "Free-fed (always available)"
        case .asNeeded:        return "As needed"
        }
    }

    /// Meals per day for daily schedules; nil when it isn't a daily count.
    var mealsPerDay: Int? {
        switch self {
        case .onceDaily:       return 1
        case .twiceDaily:      return 2
        case .threeTimesDaily: return 3
        case .fourTimesDaily:  return 4
        default:               return nil
        }
    }

    /// Days between meals for interval-style frequencies; nil for the rest.
    func intervalDays(custom: Int) -> Int? {
        switch self {
        case .everyOtherDay: return 2
        case .everyNDays:    return max(custom, 1)
        default:             return nil
        }
    }

    /// Free-fed and as-needed have no clock times to show.
    var isScheduled: Bool {
        self != .freeFed && self != .asNeeded
    }
}

/// One food a pet gets: what it is, how much, and how often.
/// A pet can have several (dry in the morning, wet at night, a weekly
/// supplement…), which is why this isn't a flat field on `Pet`.
@Model
final class Feeding {
    var id: UUID = UUID()
    var kind: FoodKind = FoodKind.dry
    var brand: String = ""            // "Royal Canin", "Purina Pro Plan"
    var product: String = ""          // "Renal Support A", "Chicken pâté"
    var amountValue: Double = 0       // 0 = amount not specified
    var amountUnit: FoodUnit = FoodUnit.cup
    var frequency: FeedFrequency = FeedFrequency.onceDaily
    var customIntervalDays: Int = 3   // used when frequency == .everyNDays
    var times: [Date] = []            // times of day (only hour/minute used)
    var instructions: String = ""     // "warm 10 sec", "puzzle feeder", "feed alone"
    var startDate: Date = Date.now
    var endDate: Date?                // set when a food is discontinued
    var sortOrder: Int = 0
    var pet: Pet?

    /// Which meals actually got served — the check-off history.
    @Relationship(deleteRule: .cascade, inverse: \FeedLog.feeding)
    var feedLogs: [FeedLog] = []

    init(
        kind: FoodKind = .dry,
        brand: String = "",
        product: String = "",
        amountValue: Double = 0,
        amountUnit: FoodUnit = .cup,
        frequency: FeedFrequency = .onceDaily,
        customIntervalDays: Int = 3,
        times: [Date] = [],
        instructions: String = "",
        startDate: Date = .now,
        endDate: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.kind = kind
        self.brand = brand
        self.product = product
        self.amountValue = amountValue
        self.amountUnit = amountUnit
        self.frequency = frequency
        self.customIntervalDays = customIntervalDays
        self.times = times
        self.instructions = instructions
        self.startDate = startDate
        self.endDate = endDate
        self.sortOrder = sortOrder
    }

    var isActive: Bool {
        guard let endDate else { return true }
        return endDate >= .now
    }

    /// "Royal Canin Renal Support A" — falls back to the food kind.
    var foodLabel: String {
        let name = [brand, product]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? kind.label : name
    }

    /// "1/2 cup", "3 oz", "" when no amount was entered.
    var amountDescription: String {
        guard amountValue > 0 else { return "" }
        return "\(Feeding.formatAmount(amountValue)) \(amountUnit.description(for: amountValue))"
    }

    var frequencyDescription: String {
        frequency == .everyNDays ? "Every \(customIntervalDays) days" : frequency.label
    }

    /// "8:00 AM, 6:00 PM"
    var timesDescription: String {
        guard frequency.isScheduled, !times.isEmpty else { return "" }
        return times.sorted().map {
            $0.formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
    }

    /// "1/2 cup · twice daily · 8:00 AM, 6:00 PM"
    var summary: String {
        [amountDescription, frequencyDescription.lowercased(), timesDescription]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Meals expected today, or nil if this food isn't on a daily clock.
    var mealsToday: Int? {
        guard frequency.isScheduled else { return nil }
        return times.isEmpty ? frequency.mealsPerDay : times.count
    }

    /// Is this food due today, given interval/weekly schedules?
    var isDueToday: Bool {
        guard isActive, frequency.isScheduled else { return false }
        let cal = Calendar.current
        if let interval = frequency.intervalDays(custom: customIntervalDays) {
            let days = cal.dateComponents([.day],
                                          from: cal.startOfDay(for: startDate),
                                          to: cal.startOfDay(for: .now)).day ?? 0
            return days >= 0 && days % interval == 0
        }
        if frequency == .weekly {
            return cal.component(.weekday, from: .now) == cal.component(.weekday, from: startDate)
        }
        return true
    }

    /// Meals expected today for check-off purposes — always at least 1
    /// for a scheduled food, so it can be ticked off even with no set times.
    var expectedMealsToday: Int { max(mealsToday ?? 1, 1) }

    /// Meals actually served today (skips don't count as served).
    var mealsGivenToday: Int {
        feedLogs.filter { Calendar.current.isDateInToday($0.date) && !$0.skipped }.count
    }

    var isFedForToday: Bool { mealsGivenToday >= expectedMealsToday }

    /// The next scheduled meal time still ahead of us today, if any.
    var nextMealTime: Date? {
        guard frequency.isScheduled, !times.isEmpty else { return nil }
        let cal = Calendar.current
        let today = times.compactMap { time -> Date? in
            let comps = cal.dateComponents([.hour, .minute], from: time)
            return cal.date(bySettingHour: comps.hour ?? 0,
                            minute: comps.minute ?? 0, second: 0, of: .now)
        }
        return today.sorted().first { $0 >= .now }
    }

    /// Records a meal right now (or a skip) and returns the log entry.
    @discardableResult
    func logMeal(at date: Date = .now, skipped: Bool = false, note: String = "") -> FeedLog {
        let log = FeedLog(date: date, skipped: skipped, note: note)
        feedLogs.append(log)
        return log
    }

    /// The most recent meal logged today — the one an "undo" should remove.
    /// Returned rather than deleted so the caller can use the model context.
    var lastMealToday: FeedLog? {
        feedLogs
            .filter { Calendar.current.isDateInToday($0.date) && !$0.skipped }
            .max(by: { $0.date < $1.date })
    }

    /// Renders 0.5 as "1/2" and 2.0 as "2" — kitchen-friendly amounts.
    static func formatAmount(_ value: Double) -> String {
        let fractions: [(Double, String)] = [
            (0.125, "1/8"), (0.25, "1/4"), (1.0 / 3.0, "1/3"), (0.5, "1/2"),
            (2.0 / 3.0, "2/3"), (0.75, "3/4")
        ]
        let whole = floor(value)
        let remainder = value - whole
        if let match = fractions.first(where: { abs(remainder - $0.0) < 0.02 }) {
            return whole == 0 ? match.1 : "\(Int(whole)) \(match.1)"
        }
        if remainder < 0.02 { return String(Int(whole)) }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "0$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
}

// MARK: - Feed log

/// One served meal. Mirrors `MedDoseLog` — the dashboard writes these when
/// a meal is checked off, and they double as a feeding history for exports
/// ("did anyone feed the cat this morning?" is the whole point).
@Model
final class FeedLog {
    var id: UUID = UUID()
    var date: Date = Date.now
    var skipped: Bool = false     // true = meal intentionally skipped
    var note: String = ""         // "only ate half", "fed by the sitter"
    var feeding: Feeding?

    init(date: Date = .now, skipped: Bool = false, note: String = "") {
        self.id = UUID()
        self.date = date
        self.skipped = skipped
        self.note = note
    }
}

// MARK: - Pet

// NOTE: all models are CloudKit-compatible — no unique constraints,
// every attribute has a default, every to-one relationship is optional.
// Enabling iCloud sync is then just an entitlement, no code changes.
@Model
final class Pet {
    var id: UUID = UUID()
    var name: String = ""
    var formerName: String = ""
    var species: String = "Cat"    // "Cat", "Dog", "Bearded Dragon", anything
    @Attribute(.externalStorage) var photoData: Data?

    // Identity / vitals
    var dob: Date?
    var gotchaDay: Date?
    var sex: String = ""           // "M (neutered)", "F (spayed)", ...
    var breed: String = ""
    var colorMarkings: String = ""
    var microchip: String = ""
    var rabiesTag: String = ""
    var collarTag: String = ""     // collar/tag # for tracked animals
    var indoorOutdoor: IndoorOutdoor = IndoorOutdoor.indoor
    var isActive: Bool = true      // false = passed away / rehomed

    // Health
    var activeConditions: [String] = []
    var allergies: [String] = []
    var healthNotes: String = ""

    // Personality & care
    var favoriteHidingSpots: [String] = []
    var favoriteToys: [String] = []
    /// Legacy free-text food note. Superseded by `feedings` — kept so old
    /// data isn't lost, and migrated into a Feeding on first launch.
    var currentFood: String = ""
    var favoriteTreats: String = ""
    var likesTreats: Fondness = Fondness.unknown
    var likesPets: Fondness = Fondness.unknown
    var temperamentNotes: String = ""
    var sitterNotes: String = ""   // "feed at 6am/6pm", "hides from strangers", etc.

    // Family links. parents/children is a real bidirectional relationship;
    // siblings are stored as IDs (SwiftData doesn't support symmetric
    // self-inverse relationships) and kept in sync by helpers below.
    var children: [Pet] = []
    @Relationship(inverse: \Pet.children) var parents: [Pet] = []
    var siblingIDs: [UUID] = []

    // Household (multi-house support / pet-sitter mode)
    var household: Household?

    // Vet
    var primaryClinic: VetClinic?

    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet)
    var weightLog: [WeightEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Vaccination.pet)
    var vaccinations: [Vaccination] = []

    @Relationship(deleteRule: .cascade, inverse: \Medication.pet)
    var medications: [Medication] = []

    @Relationship(deleteRule: .cascade, inverse: \Feeding.pet)
    var feedings: [Feeding] = []

    @Relationship(deleteRule: .cascade, inverse: \VetVisit.pet)
    var vetVisits: [VetVisit] = []

    @Relationship(deleteRule: .cascade, inverse: \ActivityLog.pet)
    var activityLogs: [ActivityLog] = []

    @Relationship(deleteRule: .cascade, inverse: \WalkSchedule.pet)
    var walkSchedules: [WalkSchedule] = []

    @Relationship(deleteRule: .cascade, inverse: \PetDocument.pet)
    var documents: [PetDocument] = []

    @Relationship(deleteRule: .cascade, inverse: \Expense.pet)
    var expenses: [Expense] = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.pet)
    var observations: [JournalEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \TodoItem.pet)
    var todos: [TodoItem] = []

    // "Notion for pets" — arbitrary user-defined fields
    // (Insurance policy #, groomer, harness size, favorite word...).
    @Relationship(deleteRule: .cascade, inverse: \CustomField.pet)
    var customFields: [CustomField] = []

    init(
        name: String,
        species: String = "Cat",
        formerName: String = "",
        dob: Date? = nil,
        gotchaDay: Date? = nil,
        sex: String = "",
        breed: String = "",
        colorMarkings: String = "",
        microchip: String = "",
        rabiesTag: String = "",
        indoorOutdoor: IndoorOutdoor = .indoor,
        activeConditions: [String] = [],
        allergies: [String] = [],
        healthNotes: String = "",
        favoriteHidingSpots: [String] = [],
        favoriteToys: [String] = [],
        currentFood: String = "",
        favoriteTreats: String = "",
        likesTreats: Fondness = .unknown,
        likesPets: Fondness = .unknown,
        temperamentNotes: String = "",
        sitterNotes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.formerName = formerName
        self.dob = dob
        self.gotchaDay = gotchaDay
        self.sex = sex
        self.breed = breed
        self.colorMarkings = colorMarkings
        self.microchip = microchip
        self.rabiesTag = rabiesTag
        self.indoorOutdoor = indoorOutdoor
        self.isActive = true
        self.activeConditions = activeConditions
        self.allergies = allergies
        self.healthNotes = healthNotes
        self.favoriteHidingSpots = favoriteHidingSpots
        self.favoriteToys = favoriteToys
        self.currentFood = currentFood
        self.favoriteTreats = favoriteTreats
        self.likesTreats = likesTreats
        self.likesPets = likesPets
        self.temperamentNotes = temperamentNotes
        self.sitterNotes = sitterNotes
        self.siblingIDs = []
    }

    // MARK: Derived

    var speciesEmoji: String { SpeciesCatalog.emoji(for: species) }

    var currentWeight: WeightEntry? {
        weightLog.max(by: { $0.date < $1.date })
    }

    var ageDescription: String {
        guard let dob else { return "Age unknown" }
        let comps = Calendar.current.dateComponents([.year, .month], from: dob, to: .now)
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        return years > 0 ? "\(years)y \(months)m" : "\(months)m"
    }

    var upcomingVisits: [VetVisit] {
        vetVisits.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
    }

    var activeMedications: [Medication] {
        medications.filter { $0.isActive }
    }

    var activeFeedings: [Feeding] {
        feedings.filter(\.isActive)
            .sorted { ($0.sortOrder, $0.foodLabel) < ($1.sortOrder, $1.foodLabel) }
    }

    var activeWalkSchedules: [WalkSchedule] {
        walkSchedules.filter(\.isActive)
            .sorted { ($0.sortOrder, $0.firstTimeMinutes) < ($1.sortOrder, $1.firstTimeMinutes) }
    }

    /// One-line walk/outing summary for the sitter profile.
    /// "Morning walk — 8:00 AM, 20 min; Evening walk — 6:00 PM, 30 min"
    var walkSummary: String {
        activeWalkSchedules.map { schedule in
            let detail = [schedule.timesDescription, "\(schedule.durationMinutes) min"]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            return "\(schedule.displayLabel) — \(detail)"
        }
        .joined(separator: "; ")
    }

    /// One-line diet summary for exports and lists.
    /// "Royal Canin Renal Support A — 1/2 cup, twice daily"
    var feedingSummary: String {
        activeFeedings.map { feeding in
            let detail = [feeding.amountDescription, feeding.frequencyDescription.lowercased()]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            return detail.isEmpty ? feeding.foodLabel : "\(feeding.foodLabel) — \(detail)"
        }
        .joined(separator: "; ")
    }

    func siblings(in allPets: [Pet]) -> [Pet] {
        allPets.filter { siblingIDs.contains($0.id) }
    }

    /// Keeps sibling links symmetric.
    static func linkSiblings(_ a: Pet, _ b: Pet) {
        if !a.siblingIDs.contains(b.id) { a.siblingIDs.append(b.id) }
        if !b.siblingIDs.contains(a.id) { b.siblingIDs.append(a.id) }
    }

    static func unlinkSiblings(_ a: Pet, _ b: Pet) {
        a.siblingIDs.removeAll { $0 == b.id }
        b.siblingIDs.removeAll { $0 == a.id }
    }
}

// MARK: - Custom field ("Notion for pets")

@Model
final class CustomField {
    var name: String = ""    // "Insurance policy", "Groomer", "Harness size"...
    var value: String = ""
    var sortOrder: Int = 0
    var pet: Pet?

    init(name: String, value: String, sortOrder: Int = 0) {
        self.name = name
        self.value = value
        self.sortOrder = sortOrder
    }
}

// MARK: - Weight

@Model
final class WeightEntry {
    var date: Date = Date.now
    var pounds: Double = 0
    var note: String = ""
    var pet: Pet?

    init(date: Date, pounds: Double, note: String = "") {
        self.date = date
        self.pounds = pounds
        self.note = note
    }
}

// MARK: - Vaccination

@Model
final class Vaccination {
    var name: String = ""     // Rabies, FVRCP, DHPP...
    var lastGiven: Date?
    var nextDue: Date?
    var pet: Pet?

    init(name: String, lastGiven: Date? = nil, nextDue: Date? = nil) {
        self.name = name
        self.lastGiven = lastGiven
        self.nextDue = nextDue
    }

    var isOverdue: Bool {
        guard let nextDue else { return false }
        return nextDue < .now
    }
}

// MARK: - Medication

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""            // "2.5 mg", "1/2 tablet"
    var frequency: MedFrequency = MedFrequency.onceDaily
    var customIntervalDays: Int = 3    // used when frequency == .everyNDays
    var doseTimes: [Date] = []         // times of day (only hour/minute used)
    var instructions: String = ""      // "with food", "in pill pocket"
    var startDate: Date = Date.now
    var endDate: Date?
    var remindersEnabled: Bool = false
    var pet: Pet?

    /// Administration history — the record you send to the vet.
    @Relationship(deleteRule: .cascade, inverse: \MedDoseLog.medication)
    var doseLogs: [MedDoseLog] = []

    init(
        name: String,
        dosage: String = "",
        frequency: MedFrequency = .onceDaily,
        customIntervalDays: Int = 3,
        doseTimes: [Date] = [],
        instructions: String = "",
        startDate: Date = .now,
        endDate: Date? = nil,
        remindersEnabled: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.customIntervalDays = customIntervalDays
        self.doseTimes = doseTimes
        self.instructions = instructions
        self.startDate = startDate
        self.endDate = endDate
        self.remindersEnabled = remindersEnabled
    }

    var isActive: Bool {
        guard let endDate else { return true }
        return endDate >= .now
    }

    var frequencyDescription: String {
        frequency == .everyNDays ? "Every \(customIntervalDays) days" : frequency.label
    }

    /// "Gabapentin 100 mg" — the dosage matters when the same drug is given
    /// at two strengths in one day, so it belongs next to the name everywhere.
    var displayName: String {
        let dose = dosage.trimmingCharacters(in: .whitespaces)
        return dose.isEmpty ? name : "\(name) \(dose)"
    }

    /// "8:00 AM, 8:00 PM"
    var doseTimesDescription: String {
        guard !doseTimes.isEmpty else { return "" }
        return doseTimes.sorted().map {
            $0.formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
    }

    /// Doses expected today — at least one for a scheduled med.
    var expectedDosesToday: Int { max(doseTimes.count, 1) }

    var dosesGivenToday: Int {
        doseLogs.filter { Calendar.current.isDateInToday($0.date) && !$0.skipped }.count
    }

    /// The most recent dose logged today — what an "undo" should remove.
    var lastDoseToday: MedDoseLog? {
        doseLogs
            .filter { Calendar.current.isDateInToday($0.date) && !$0.skipped }
            .max(by: { $0.date < $1.date })
    }

    var lastDose: MedDoseLog? {
        doseLogs.filter { !$0.skipped }.max(by: { $0.date < $1.date })
    }

    /// Records a dose right now (or a skip) and returns the log entry.
    @discardableResult
    func logDose(at date: Date = .now, skipped: Bool = false, note: String = "") -> MedDoseLog {
        let log = MedDoseLog(date: date, skipped: skipped, note: note)
        doseLogs.append(log)
        return log
    }
}

// MARK: - Med dose log

@Model
final class MedDoseLog {
    var date: Date = Date.now
    var skipped: Bool = false     // true = dose was intentionally skipped/missed
    var note: String = ""         // "spit out half", "gave in churu"
    var medication: Medication?

    init(date: Date = .now, skipped: Bool = false, note: String = "") {
        self.date = date
        self.skipped = skipped
        self.note = note
    }
}

// MARK: - Vet clinic

@Model
final class VetClinic {
    var id: UUID = UUID()
    var name: String = ""
    var phone: String = ""
    var address: String = ""
    var email: String = ""
    var notes: String = ""

    @Relationship(inverse: \Pet.primaryClinic) var patients: [Pet] = []

    init(name: String, phone: String = "", address: String = "", email: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.phone = phone
        self.address = address
        self.email = email
        self.notes = notes
    }
}

// MARK: - Vet visit (past record or upcoming appointment)

@Model
final class VetVisit {
    var id: UUID = UUID()
    var date: Date = Date.now
    var reason: String = ""            // "Annual exam", "URI recheck"
    var clinicName: String = ""
    var outcomeNotes: String = ""      // findings, treatments, weight taken...
    var reminderEnabled: Bool = false  // day-before local notification
    var pet: Pet?

    init(date: Date, reason: String, clinicName: String = "", outcomeNotes: String = "", reminderEnabled: Bool = false) {
        self.id = UUID()
        self.date = date
        self.reason = reason
        self.clinicName = clinicName
        self.outcomeNotes = outcomeNotes
        self.reminderEnabled = reminderEnabled
    }

    var isUpcoming: Bool { date >= Calendar.current.startOfDay(for: .now) }
}

// MARK: - Household

/// A place pets live — supports multiple houses (or a pet sitter
/// tracking clients' homes).
@Model
final class Household {
    var id: UUID = UUID()
    var name: String = ""     // "Home", "Barn", "The Hendersons"...
    var address: String = ""
    var notes: String = ""    // door codes go in your head, not here

    @Relationship(inverse: \Pet.household) var pets: [Pet] = []

    /// Cleaning chores tied to this location — deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \ChoreTask.household)
    var chores: [ChoreTask] = []

    /// To-dos tied to this location — deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \TodoItem.household)
    var todos: [TodoItem] = []

    init(name: String, address: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.notes = notes
    }
}

// MARK: - Activity (walks & enrichment)

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case walk, play, enrichment, training, grooming, other

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .walk:       return "🚶"
        case .play:       return "🪀"
        case .enrichment: return "🧠"
        case .training:   return "🎯"
        case .grooming:   return "🪮"
        case .other:      return "⭐️"
        }
    }
}

@Model
final class ActivityLog {
    var date: Date = Date.now
    var kind: ActivityKind = ActivityKind.walk
    var durationMinutes: Int = 15
    var notes: String = ""
    /// Set when this log came from checking off a `WalkSchedule`, so the
    /// dashboard knows which scheduled outing has already been done.
    /// Nil for ad-hoc logs. Stored as an ID rather than a relationship so
    /// deleting a schedule never orphans or deletes real history.
    var scheduleID: UUID?
    var pet: Pet?

    init(date: Date = .now, kind: ActivityKind = .walk, durationMinutes: Int = 15,
         notes: String = "", scheduleID: UUID? = nil) {
        self.date = date
        self.kind = kind
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.scheduleID = scheduleID
    }
}

// MARK: - Walk schedule

/// A recurring outing — the morning walk, the evening potty break, the
/// midday enrichment session. Unlike `ActivityLog` (which records what
/// already happened) this is the plan, so the dashboard can show what's
/// still owed today and a sitter can see the routine at a glance.
@Model
final class WalkSchedule {
    var id: UUID = UUID()
    var label: String = ""                          // "Morning walk", "Lunch potty break"
    var kind: ActivityKind = ActivityKind.walk
    var times: [Date] = []                          // times of day (only hour/minute used)
    var durationMinutes: Int = 20
    /// Calendar weekdays (1 = Sunday … 7 = Saturday). Empty means every day.
    var daysOfWeek: [Int] = []
    var notes: String = ""                          // "harness, not collar", "avoid the dog park"
    var endDate: Date?                              // set when a routine is retired
    var sortOrder: Int = 0
    var pet: Pet?

    init(
        label: String = "",
        kind: ActivityKind = .walk,
        times: [Date] = [],
        durationMinutes: Int = 20,
        daysOfWeek: [Int] = [],
        notes: String = "",
        endDate: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.label = label
        self.kind = kind
        self.times = times
        self.durationMinutes = durationMinutes
        self.daysOfWeek = daysOfWeek
        self.notes = notes
        self.endDate = endDate
        self.sortOrder = sortOrder
    }

    var isActive: Bool {
        guard let endDate else { return true }
        return endDate >= .now
    }

    /// Falls back to the activity kind when no name was given.
    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.label : trimmed
    }

    /// Runs on every day of the week?
    var isEveryDay: Bool { daysOfWeek.isEmpty || daysOfWeek.count >= 7 }

    var isDueToday: Bool {
        guard isActive else { return false }
        if isEveryDay { return true }
        return daysOfWeek.contains(Calendar.current.component(.weekday, from: .now))
    }

    /// Outings expected today — at least one, even with no times set.
    var expectedToday: Int { max(times.count, 1) }

    /// "8:00 AM, 6:00 PM"
    var timesDescription: String {
        guard !times.isEmpty else { return "" }
        return times.sorted().map {
            $0.formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
    }

    /// "Mon, Wed, Fri" — empty when it runs daily.
    var daysDescription: String {
        guard !isEveryDay else { return "" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return daysOfWeek.sorted()
            .compactMap { $0 >= 1 && $0 <= symbols.count ? symbols[$0 - 1] : nil }
            .joined(separator: ", ")
    }

    /// "8:00 AM, 6:00 PM · 20 min · Mon, Wed, Fri"
    var summary: String {
        [timesDescription, "\(durationMinutes) min", daysDescription]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Minutes past midnight of the first outing — used for ordering.
    var firstTimeMinutes: Int {
        guard let first = times.sorted().first else { return 24 * 60 }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: first)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// How many of today's outings are already logged against this schedule.
    func completedToday(for pet: Pet) -> Int {
        let cal = Calendar.current
        return pet.activityLogs.filter {
            $0.scheduleID == id && cal.isDateInToday($0.date)
        }.count
    }

    /// Records an outing now and returns the log entry.
    @discardableResult
    func logOuting(for pet: Pet, at date: Date = .now, note: String = "") -> ActivityLog {
        let log = ActivityLog(date: date, kind: kind,
                              durationMinutes: durationMinutes,
                              notes: note.isEmpty ? displayLabel : note,
                              scheduleID: id)
        pet.activityLogs.append(log)
        return log
    }

    /// The most recent outing logged today against this schedule.
    func lastOutingToday(for pet: Pet) -> ActivityLog? {
        let cal = Calendar.current
        return pet.activityLogs
            .filter { $0.scheduleID == id && cal.isDateInToday($0.date) }
            .max(by: { $0.date < $1.date })
    }
}

// MARK: - Documents (vaccine certificates, adoption papers, insurance cards)

@Model
final class PetDocument {
    var name: String = "Document"
    var date: Date = Date.now
    var notes: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var pet: Pet?

    init(name: String = "Document", date: Date = .now, notes: String = "", imageData: Data? = nil) {
        self.name = name
        self.date = date
        self.notes = notes
        self.imageData = imageData
    }
}

// MARK: - Expenses

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case vet, food, supplies, grooming, insurance, boarding, other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .vet:       return "🩺"
        case .food:      return "🍽"
        case .supplies:  return "🧸"
        case .grooming:  return "🪮"
        case .insurance: return "🛡"
        case .boarding:  return "🏨"
        case .other:     return "💳"
        }
    }
}

@Model
final class Expense {
    var date: Date = Date.now
    var amount: Double = 0
    var category: ExpenseCategory = ExpenseCategory.other
    var note: String = ""
    var pet: Pet?

    init(date: Date = .now, amount: Double = 0, category: ExpenseCategory = .other, note: String = "") {
        self.date = date
        self.amount = amount
        self.category = category
        self.note = note
    }
}

// MARK: - Journal (symptoms & observations, optionally with a photo)
// Named JournalEntry, NOT Observation — that name collides with Apple's
// Observation framework and breaks every @Model macro expansion.

@Model
final class JournalEntry {
    var date: Date = Date.now
    var note: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var pet: Pet?

    init(date: Date = .now, note: String = "", photoData: Data? = nil) {
        self.date = date
        self.note = note
        self.photoData = photoData
    }
}

// MARK: - Attendance

@Model
final class AttendanceRecord {
    var id: UUID = UUID()
    var date: Date = Date.now
    var location: String = ""     // "House", "Barn"...
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \AttendanceEntry.record)
    var entries: [AttendanceEntry] = []

    init(date: Date = .now, location: String = "", notes: String = "") {
        self.id = UUID()
        self.date = date
        self.location = location
        self.notes = notes
    }

    var presentCount: Int { entries.filter(\.present).count }
}

@Model
final class AttendanceEntry {
    var present: Bool = false
    var pet: Pet?
    var record: AttendanceRecord?

    init(pet: Pet?, present: Bool = false) {
        self.pet = pet
        self.present = present
    }
}

// MARK: - Cleaning chores

/// A recurring "change the dirty thing" reminder — litter box, tank water,
/// cage bedding, stall hay. Tied to a species and (optionally) a location;
/// the interval shrinks as more matching animals live there, because three
/// cats dirty a litter box three times as fast as one.
@Model
final class ChoreTask {
    var id: UUID = UUID()
    var name: String = ""              // "Litter box change"
    var species: String = ""           // "" = counts every animal at the location
    /// Days between cleanings *for one animal*. The effective interval is
    /// this divided by the animal count, never less than daily.
    var baseIntervalDays: Int = 3
    var remindersEnabled: Bool = true
    var notes: String = ""
    var startDate: Date = Date.now
    var lastCompleted: Date?
    /// The completion before `lastCompleted` — lets a mis-tap be undone
    /// without keeping a full log.
    var previousCompleted: Date?
    /// Non-empty when this chore was auto-created from `ChoreDefaults`,
    /// so seeding never duplicates it.
    var sourceKey: String = ""
    var sortOrder: Int = 0
    /// Nil = applies wherever you are (no location filter).
    var household: Household?

    init(
        name: String,
        species: String = "",
        baseIntervalDays: Int = 3,
        remindersEnabled: Bool = true,
        notes: String = "",
        sourceKey: String = "",
        household: Household? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.baseIntervalDays = baseIntervalDays
        self.remindersEnabled = remindersEnabled
        self.notes = notes
        self.startDate = .now
        self.sourceKey = sourceKey
        self.household = household
    }

    /// Active pets this chore covers: at its location (unassigned pets count
    /// everywhere, matching how the location switcher shows them), and of
    /// its species. Empty species matches every animal.
    func matchingPets(in allPets: [Pet]) -> [Pet] {
        allPets.filter { pet in
            guard pet.isActive else { return false }
            if let location = household,
               let petHome = pet.household,
               petHome.id != location.id { return false }
            guard !species.isEmpty else { return true }
            return pet.species.caseInsensitiveCompare(species) == .orderedSame
        }
    }

    /// Base interval ÷ animal count, rounded, never below 1 day.
    func effectiveIntervalDays(count: Int) -> Int {
        guard count > 1 else { return max(baseIntervalDays, 1) }
        let days = (Double(baseIntervalDays) / Double(count)).rounded()
        return max(Int(days), 1)
    }

    /// Midnight of the day the next cleaning is owed.
    func nextDue(count: Int) -> Date {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: lastCompleted ?? startDate)
        return cal.date(byAdding: .day, value: effectiveIntervalDays(count: count),
                        to: anchor) ?? anchor
    }

    /// Due today or overdue.
    func isDue(count: Int) -> Bool {
        nextDue(count: count) <= .now || Calendar.current.isDateInToday(nextDue(count: count))
    }

    func isOverdue(count: Int) -> Bool {
        nextDue(count: count) < Calendar.current.startOfDay(for: .now)
    }

    var completedToday: Bool {
        guard let lastCompleted else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }

    /// "Every 2 days" / "Daily".
    func intervalDescription(count: Int) -> String {
        let days = effectiveIntervalDays(count: count)
        return days == 1 ? "Daily" : "Every \(days) days"
    }

    /// "3 cats" / "1 hamster" / "2 animals" (empty species).
    func countDescription(count: Int) -> String {
        let noun = species.isEmpty ? "animal" : species.lowercased()
        return "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    func markDone(at date: Date = .now) {
        previousCompleted = lastCompleted
        lastCompleted = date
    }

    /// Reverts the most recent `markDone`.
    func undoDone() {
        lastCompleted = previousCompleted
        previousCompleted = nil
    }
}

// MARK: - Chore defaults & auto-creation

/// Built-in "things that get dirty" per species. `baseIntervalDays` is for
/// a single animal; the live interval scales down with the head count.
enum ChoreDefaults {
    struct Preset {
        let key: String        // stable identity for seed-once bookkeeping
        let species: String
        let name: String
        let baseIntervalDays: Int
    }

    static let all: [Preset] = [
        Preset(key: "cat.litter",        species: "Cat",        name: "Litter box change",       baseIntervalDays: 4),
        Preset(key: "dog.bedding",       species: "Dog",        name: "Wash bedding & bowls",    baseIntervalDays: 7),
        Preset(key: "fish.water",        species: "Fish",       name: "Partial water change",    baseIntervalDays: 7),
        Preset(key: "hamster.bedding",   species: "Hamster",    name: "Cage sawdust change",     baseIntervalDays: 7),
        Preset(key: "guineapig.bedding", species: "Guinea Pig", name: "Cage bedding change",     baseIntervalDays: 4),
        Preset(key: "rabbit.hutch",      species: "Rabbit",     name: "Hutch & litter clean",    baseIntervalDays: 3),
        Preset(key: "bird.liner",        species: "Bird",       name: "Cage liner change",       baseIntervalDays: 2),
        Preset(key: "ferret.bedding",    species: "Ferret",     name: "Cage & litter clean",     baseIntervalDays: 3),
        Preset(key: "reptile.enclosure", species: "Reptile",    name: "Enclosure spot clean",    baseIntervalDays: 7),
        Preset(key: "snake.enclosure",   species: "Snake",      name: "Enclosure spot clean",    baseIntervalDays: 7),
        Preset(key: "turtle.tank",       species: "Turtle",     name: "Tank water change",       baseIntervalDays: 7),
        Preset(key: "horse.stall",       species: "Horse",      name: "Fresh hay & muck stall",  baseIntervalDays: 1),
        Preset(key: "goat.pen",          species: "Goat",       name: "Pen clean & fresh hay",   baseIntervalDays: 2),
        Preset(key: "chicken.coop",      species: "Chicken",    name: "Coop bedding refresh",    baseIntervalDays: 7),
        Preset(key: "pig.pen",           species: "Pig",        name: "Pen clean",               baseIntervalDays: 2)
    ]

    private static let seededKey = "seededChoreKeys"

    /// Auto-creates a chore per matching preset, per location, the first
    /// time animals of that species are seen there. Seeding is remembered
    /// in UserDefaults, so deleting a chore never resurrects it. Call on
    /// launch and when the dashboard appears — cheap and idempotent.
    static func autoCreate(context: ModelContext) {
        #if os(macOS)
        // Chore seeding stays iPhone-only. The seed bookkeeping below lives
        // in per-device UserDefaults, so seeding on the Mac would duplicate
        // chores that already exist in iCloud — and resurrect ones deleted
        // on the iPhone. Synced chores still show and work normally here.
        return
        #else
        autoCreateBody(context: context)
        #endif
    }

    private static func autoCreateBody(context: ModelContext) {
        guard let pets = try? context.fetch(FetchDescriptor<Pet>()),
              let households = try? context.fetch(FetchDescriptor<Household>()),
              let existing = try? context.fetch(FetchDescriptor<ChoreTask>())
        else { return }

        var seeded = Set(UserDefaults.standard.stringArray(forKey: seededKey) ?? [])
        var changed = false

        // Presets already covering everywhere as a global chore (seeded
        // before any location existed) — never re-seed those per location,
        // or the first added location would duplicate every chore.
        let globalKeys = Set(existing.compactMap {
            $0.household == nil && !$0.sourceKey.isEmpty ? $0.sourceKey : nil
        })

        // With no locations set up, chores are global (household nil).
        let locations: [Household?] = households.isEmpty ? [nil] : households

        for location in locations {
            let locationTag = location?.id.uuidString ?? "global"
            for preset in all {
                let seedKey = "\(locationTag)|\(preset.key)"
                guard !seeded.contains(seedKey) else { continue }
                if location != nil, globalKeys.contains(preset.key) {
                    seeded.insert(seedKey)
                    changed = true
                    continue
                }

                let hasAnimals = pets.contains { pet in
                    guard pet.isActive,
                          pet.species.caseInsensitiveCompare(preset.species) == .orderedSame
                    else { return false }
                    if let location, let home = pet.household { return home.id == location.id }
                    return true
                }
                guard hasAnimals else { continue }

                context.insert(ChoreTask(
                    name: preset.name,
                    species: preset.species,
                    baseIntervalDays: preset.baseIntervalDays,
                    sourceKey: preset.key,
                    household: location
                ))
                seeded.insert(seedKey)
                changed = true
            }
        }

        if changed {
            UserDefaults.standard.set(Array(seeded), forKey: seededKey)
            // Explicit save — the launch-time context has no autosave.
            try? context.save()
        }
    }
}

// MARK: - To-dos

/// A free-form task — one-off ("fix the barn gate") or repeating on a
/// fixed interval ("flea treatment every 30 days"). Optionally attached
/// to a pet (follows the pet around) or a location (only shows there);
/// attached to neither, it shows everywhere.
@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    /// Nil = no deadline; the to-do just sits on the list until done.
    /// For a repeating to-do this always holds the next occurrence.
    var dueDate: Date?
    /// 0 = one-off. Above 0, checking it off schedules the next occurrence
    /// this many days out.
    var repeatDays: Int = 0
    var remindersEnabled: Bool = true
    var startDate: Date = Date.now
    var lastCompleted: Date?
    /// Pre-completion state, so a mis-tap can be undone: the previous
    /// completion stamp and the due date that was in force.
    var previousCompleted: Date?
    var previousDueDate: Date?
    var sortOrder: Int = 0
    var pet: Pet?
    var household: Household?

    init(
        title: String = "",
        notes: String = "",
        dueDate: Date? = nil,
        repeatDays: Int = 0,
        remindersEnabled: Bool = true,
        pet: Pet? = nil,
        household: Household? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.repeatDays = repeatDays
        self.remindersEnabled = remindersEnabled
        self.startDate = .now
        self.pet = pet
        self.household = household
    }

    var isRepeating: Bool { repeatDays > 0 }

    /// One-offs close for good once completed; repeating to-dos never close.
    var isOpen: Bool { isRepeating || lastCompleted == nil }

    var completedToday: Bool {
        guard let lastCompleted else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }

    /// When it's next owed. Nil only for an undated one-off.
    var nextDue: Date? {
        if let dueDate { return dueDate }
        guard isRepeating else { return nil }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: lastCompleted ?? startDate)
        return cal.date(byAdding: .day, value: repeatDays, to: anchor)
    }

    var isOverdue: Bool {
        guard isOpen, let nextDue else { return false }
        return nextDue < Calendar.current.startOfDay(for: .now)
    }

    /// Belongs on today's checklist: open and either undated or due by the
    /// end of today. (Completed-today rows are kept by the views themselves.)
    var isDueNow: Bool {
        guard isOpen else { return false }
        guard let nextDue else { return true }
        let cal = Calendar.current
        return nextDue < cal.startOfDay(for: .now) || cal.isDateInToday(nextDue)
    }

    /// Visible at a location: pet-attached follows the pet, location-attached
    /// sticks to its location, unattached shows everywhere. Mirrors
    /// `Array<Pet>.at(_:)` — unassigned pets are visible at every location.
    func isVisible(at location: Household?) -> Bool {
        if let pet {
            guard let location, let home = pet.household else { return true }
            return home.id == location.id
        }
        if let household {
            guard let location else { return true }
            return household.id == location.id
        }
        return true
    }

    /// "Milo" / "Barn" / "" — who or where this belongs to.
    var attachmentDescription: String {
        pet?.name ?? household?.name ?? ""
    }

    /// "Due today" / "Overdue since Aug 20" / "Due Sep 3" / "Repeats every 30 days".
    var dueDescription: String {
        let cal = Calendar.current
        var parts: [String] = []
        if let nextDue {
            if nextDue < cal.startOfDay(for: .now), isOpen {
                parts.append("Overdue since \(nextDue.formatted(date: .abbreviated, time: .omitted))")
            } else if cal.isDateInToday(nextDue) {
                parts.append("Due today")
            } else {
                parts.append("Due \(nextDue.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        if isRepeating {
            parts.append(repeatDays == 1 ? "repeats daily" : "repeats every \(repeatDays) days")
        }
        return parts.joined(separator: " · ")
    }

    func markDone(at date: Date = .now) {
        previousCompleted = lastCompleted
        previousDueDate = dueDate
        lastCompleted = date
        if isRepeating {
            let cal = Calendar.current
            dueDate = cal.date(byAdding: .day, value: repeatDays,
                               to: cal.startOfDay(for: date))
        }
    }

    /// Reverts the most recent `markDone`, due date included.
    func undoDone() {
        lastCompleted = previousCompleted
        dueDate = previousDueDate
        previousCompleted = nil
        previousDueDate = nil
    }
}
