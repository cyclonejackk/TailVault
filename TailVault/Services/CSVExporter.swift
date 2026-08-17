//
//  CSVExporter.swift
//  TailVault
//
//  Builds CSV files (pets, attendance, medication log) and writes them
//  to a temp URL suitable for ShareLink — opens straight into
//  Numbers/Excel/Sheets.
//

import Foundation

enum CSVExporter {

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func row(_ fields: [String]) -> String {
        fields.map { escape($0) }.joined(separator: ",")
    }

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func fmt(_ date: Date?) -> String {
        date.map { dateFormat.string(from: $0) } ?? ""
    }

    private static func write(_ csv: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Pets spreadsheet

    static func exportPets(_ pets: [Pet]) -> URL? {
        var lines = [row([
            "Name", "Species", "Status", "DOB", "Gotcha Day", "Age", "Sex", "Breed", "Color/Markings",
            "Microchip", "Rabies Tag", "Collar/Tag #", "Household", "Indoor/Outdoor", "Current Weight (lbs)",
            "Primary Clinic", "Active Conditions", "Allergies", "Current Medications",
            "Food & Feeding", "Feeding Times", "Walk Routine",
            "Treats", "Likes Treats", "Likes Pets",
            "Hiding Spots", "Favorite Toys", "Parents", "Siblings",
            "Next Vet Visit", "Custom Fields", "Sitter Notes"
        ])]

        for pet in pets.sorted(by: { $0.name < $1.name }) {
            let meds = pet.activeMedications
                .map { "\($0.name) \($0.dosage) — \($0.frequencyDescription)" }
                .joined(separator: "; ")
            let nextVisit = pet.upcomingVisits.first
                .map { "\(fmt($0.date)) — \($0.reason)" } ?? ""
            let custom = pet.customFields
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { "\($0.name): \($0.value)" }
                .joined(separator: "; ")
            let feedingTimes = pet.activeFeedings
                .filter { !$0.timesDescription.isEmpty }
                .map { "\($0.foodLabel): \($0.timesDescription)" }
                .joined(separator: "; ")

            lines.append(row([
                pet.name,
                pet.species,
                pet.isActive ? "active" : "inactive",
                fmt(pet.dob), fmt(pet.gotchaDay), pet.ageDescription,
                pet.sex, pet.breed, pet.colorMarkings,
                pet.microchip, pet.rabiesTag, pet.collarTag,
                pet.household?.name ?? "", pet.indoorOutdoor.label,
                pet.currentWeight.map { String(format: "%.1f", $0.pounds) } ?? "",
                pet.primaryClinic?.name ?? "",
                pet.activeConditions.joined(separator: "; "),
                pet.allergies.joined(separator: "; "),
                meds,
                pet.feedingSummary.isEmpty ? pet.currentFood : pet.feedingSummary,
                feedingTimes,
                pet.walkSummary,
                pet.favoriteTreats,
                pet.likesTreats.label, pet.likesPets.label,
                pet.favoriteHidingSpots.joined(separator: "; "),
                pet.favoriteToys.joined(separator: "; "),
                pet.parents.map(\.name).joined(separator: "; "),
                pet.siblings(in: pets).map(\.name).joined(separator: "; "),
                nextVisit,
                custom,
                pet.sitterNotes
            ]))
        }

        return write(lines.joined(separator: "\n"), filename: "Pets \(fmt(.now)).csv")
    }

    // MARK: Medication log spreadsheet

    /// Every logged dose across the given pets — what you hand the vet.
    static func exportMedLogs(_ pets: [Pet]) -> URL? {
        var lines = [row(["Date", "Time", "Pet", "Medication", "Dosage", "Scheduled As", "Given/Skipped", "Notes"])]

        let allLogs: [(pet: Pet, med: Medication, log: MedDoseLog)] = pets.flatMap { pet in
            pet.medications.flatMap { med in
                med.doseLogs.map { (pet, med, $0) }
            }
        }
        .sorted { $0.log.date > $1.log.date }

        for item in allLogs {
            lines.append(row([
                fmt(item.log.date),
                timeFormat.string(from: item.log.date),
                item.pet.name,
                item.med.name,
                item.med.dosage,
                item.med.frequencyDescription,
                item.log.skipped ? "Skipped" : "Given",
                item.log.note
            ]))
        }

        return write(lines.joined(separator: "\n"), filename: "Medication Log \(fmt(.now)).csv")
    }

    // MARK: Expenses spreadsheet

    static func exportExpenses(_ pets: [Pet]) -> URL? {
        var lines = [row(["Date", "Pet", "Category", "Amount", "Note"])]

        let all: [(pet: Pet, expense: Expense)] = pets.flatMap { pet in
            pet.expenses.map { (pet, $0) }
        }
        .sorted { $0.expense.date > $1.expense.date }

        for item in all {
            lines.append(row([
                fmt(item.expense.date),
                item.pet.name,
                item.expense.category.label,
                String(format: "%.2f", item.expense.amount),
                item.expense.note
            ]))
        }

        return write(lines.joined(separator: "\n"), filename: "Pet Expenses \(fmt(.now)).csv")
    }

    // MARK: Walks & enrichment spreadsheet

    static func exportActivityLogs(_ pets: [Pet]) -> URL? {
        var lines = [row(["Date", "Time", "Pet", "Activity", "Duration (min)", "Notes"])]

        let allLogs: [(pet: Pet, log: ActivityLog)] = pets.flatMap { pet in
            pet.activityLogs.map { (pet, $0) }
        }
        .sorted { $0.log.date > $1.log.date }

        for item in allLogs {
            lines.append(row([
                fmt(item.log.date),
                timeFormat.string(from: item.log.date),
                item.pet.name,
                item.log.kind.label,
                String(item.log.durationMinutes),
                item.log.notes
            ]))
        }

        return write(lines.joined(separator: "\n"), filename: "Activity \(fmt(.now)).csv")
    }

    // MARK: Attendance spreadsheet

    static func exportAttendance(_ records: [AttendanceRecord]) -> URL? {
        var lines = [row(["Date", "Time", "Location", "Pet", "Present", "Notes"])]

        for record in records.sorted(by: { $0.date > $1.date }) {
            for entry in record.entries.sorted(by: { ($0.pet?.name ?? "") < ($1.pet?.name ?? "") }) {
                lines.append(row([
                    fmt(record.date),
                    timeFormat.string(from: record.date),
                    record.location,
                    entry.pet?.name ?? "(deleted)",
                    entry.present ? "Yes" : "No",
                    record.notes
                ]))
            }
        }

        return write(lines.joined(separator: "\n"), filename: "Attendance \(fmt(.now)).csv")
    }
}
