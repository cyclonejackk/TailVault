//
//  SitterSummary.swift
//  TailVault
//
//  Text builders for sharing:
//  - SitterSummary: pet-sitter handoff (one pet or whole household)
//  - VetReport: medication administration history for the vet
//

import Foundation

enum SitterSummary {

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    static func text(for pet: Pet, allPets: [Pet]) -> String {
        var s = "\(pet.speciesEmoji) \(pet.name.uppercased())\n"
        s += String(repeating: "—", count: 24) + "\n"

        var identity: [String] = [pet.species]
        if !pet.breed.isEmpty { identity.append(pet.breed) }
        if !pet.colorMarkings.isEmpty { identity.append(pet.colorMarkings) }
        if !pet.sex.isEmpty { identity.append(pet.sex) }
        if let dob = pet.dob { identity.append("born \(dateFormat.string(from: dob)) (\(pet.ageDescription))") }
        s += identity.joined(separator: " · ") + "\n"

        if let w = pet.currentWeight {
            s += "Weight: \(String(format: "%.1f", w.pounds)) lbs\n"
        }
        if !pet.microchip.isEmpty { s += "Microchip: \(pet.microchip)\n" }
        if !pet.collarTag.isEmpty { s += "Collar/tag #: \(pet.collarTag)\n" }
        if let household = pet.household { s += "Household: \(household.name)\n" }

        let feedings = pet.activeFeedings
        if !feedings.isEmpty {
            s += "\n🍽 FEEDING\n"
            for feeding in feedings {
                s += "• \(feeding.foodLabel)"
                if !feeding.amountDescription.isEmpty { s += " — \(feeding.amountDescription)" }
                s += ", \(feeding.frequencyDescription.lowercased())"
                if !feeding.timesDescription.isEmpty { s += " at \(feeding.timesDescription)" }
                if !feeding.instructions.isEmpty { s += " (\(feeding.instructions))" }
                s += "\n"
            }
        } else if !pet.currentFood.isEmpty {
            s += "\n🍽 Food: \(pet.currentFood)\n"
        }
        if !pet.favoriteTreats.isEmpty { s += "Treats: \(pet.favoriteTreats)\n" }
        s += "Likes treats: \(pet.likesTreats.emoji) \(pet.likesTreats.label)\n"
        s += "Likes pets: \(pet.likesPets.emoji) \(pet.likesPets.label)\n"

        if !pet.favoriteHidingSpots.isEmpty {
            s += "\n🫣 Hiding spots: \(pet.favoriteHidingSpots.joined(separator: ", "))\n"
        }
        if !pet.favoriteToys.isEmpty {
            s += "🧸 Favorite toys: \(pet.favoriteToys.joined(separator: ", "))\n"
        }
        if !pet.temperamentNotes.isEmpty {
            s += "\n😼 Temperament: \(pet.temperamentNotes)\n"
        }

        let meds = pet.activeMedications
        if !meds.isEmpty {
            s += "\n💊 MEDICATIONS\n"
            for med in meds {
                s += "• \(med.name)"
                if !med.dosage.isEmpty { s += " — \(med.dosage)" }
                s += ", \(med.frequencyDescription.lowercased())"
                if !med.doseTimesDescription.isEmpty { s += " at \(med.doseTimesDescription)" }
                if !med.instructions.isEmpty { s += " (\(med.instructions))" }
                s += "\n"
            }
        }

        let walks = pet.activeWalkSchedules
        if !walks.isEmpty {
            s += "\n🚶 WALK ROUTINE\n"
            for walk in walks {
                s += "• \(walk.displayLabel) — \(walk.summary)"
                if !walk.notes.isEmpty { s += " (\(walk.notes))" }
                s += "\n"
            }
        }

        if !pet.activeConditions.isEmpty {
            s += "\n⚕️ Conditions: \(pet.activeConditions.joined(separator: ", "))\n"
        }
        if !pet.allergies.isEmpty {
            s += "⚠️ Allergies: \(pet.allergies.joined(separator: ", "))\n"
        }

        if let clinic = pet.primaryClinic {
            s += "\n🏥 Vet: \(clinic.name)"
            if !clinic.phone.isEmpty { s += " · \(clinic.phone)" }
            s += "\n"
        }
        if let next = pet.upcomingVisits.first {
            s += "📅 Next visit: \(dateFormat.string(from: next.date)) — \(next.reason)\n"
        }

        let family = familyLine(for: pet, allPets: allPets)
        if !family.isEmpty { s += "\n👨‍👩‍👧 \(family)\n" }

        let custom = pet.customFields.sorted { $0.sortOrder < $1.sortOrder }
        if !custom.isEmpty {
            s += "\nℹ️ MORE\n"
            for field in custom {
                s += "• \(field.name): \(field.value)\n"
            }
        }

        if !pet.sitterNotes.isEmpty {
            s += "\n📝 SITTER NOTES\n\(pet.sitterNotes)\n"
        }

        return s
    }

    static func householdText(pets: [Pet], allPets: [Pet]) -> String {
        var s = "🏠 PET HOUSEHOLD GUIDE — \(pets.count) pets\n"
        s += "Generated \(dateFormat.string(from: .now)) from TailVault\n\n"
        s += pets.sorted { $0.name < $1.name }
            .map { text(for: $0, allPets: allPets) }
            .joined(separator: "\n\n" + String(repeating: "=", count: 24) + "\n\n")
        return s
    }

    private static func familyLine(for pet: Pet, allPets: [Pet]) -> String {
        var parts: [String] = []
        if !pet.parents.isEmpty {
            parts.append("Parents: \(pet.parents.map(\.name).joined(separator: ", "))")
        }
        if !pet.children.isEmpty {
            parts.append("Offspring: \(pet.children.map(\.name).joined(separator: ", "))")
        }
        let sibs = pet.siblings(in: allPets)
        if !sibs.isEmpty {
            parts.append("Siblings: \(sibs.map(\.name).joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Vet report (medication administration history)

enum VetReport {

    private static let dateTimeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    /// Administration history for one pet — formatted to hand to a vet.
    static func medicationHistory(for pet: Pet, since: Date? = nil) -> String {
        var s = "MEDICATION ADMINISTRATION RECORD\n"
        s += "Patient: \(pet.name) (\(pet.species)"
        if !pet.breed.isEmpty { s += ", \(pet.breed)" }
        s += ")\n"
        if let dob = pet.dob { s += "DOB: \(dateFormat.string(from: dob))\n" }
        if !pet.microchip.isEmpty { s += "Microchip: \(pet.microchip)\n" }
        if let w = pet.currentWeight {
            s += "Weight: \(String(format: "%.1f", w.pounds)) lbs (\(dateFormat.string(from: w.date)))\n"
        }
        if let since {
            s += "Period: \(dateFormat.string(from: since)) – \(dateFormat.string(from: .now))\n"
        }
        s += "Generated \(dateFormat.string(from: .now)) from TailVault\n"

        for med in pet.medications.sorted(by: { $0.name < $1.name }) {
            let logs = med.doseLogs
                .filter { since == nil || $0.date >= since! }
                .sorted { $0.date > $1.date }
            guard !logs.isEmpty || med.isActive else { continue }

            s += "\n" + String(repeating: "—", count: 32) + "\n"
            s += "\(med.name)"
            if !med.dosage.isEmpty { s += " — \(med.dosage)" }
            s += "\nPrescribed: \(med.frequencyDescription)"
            if !med.instructions.isEmpty { s += " · \(med.instructions)" }
            s += "\nStatus: \(med.isActive ? "active" : "ended")\n"

            let given = logs.filter { !$0.skipped }.count
            let skipped = logs.count - given
            s += "Doses logged: \(given) given"
            if skipped > 0 { s += ", \(skipped) skipped" }
            s += "\n"

            for log in logs {
                s += "  • \(dateTimeFormat.string(from: log.date))"
                s += log.skipped ? " — SKIPPED" : " — given"
                if !log.note.isEmpty { s += " (\(log.note))" }
                s += "\n"
            }
        }

        if pet.medications.allSatisfy({ $0.doseLogs.isEmpty }) {
            s += "\nNo doses logged yet.\n"
        }

        return s
    }
}
