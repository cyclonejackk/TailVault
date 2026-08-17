//
//  SampleData.swift
//  TailVault
//
//  Seeds the database on first launch with Nate's 8 cats,
//  pulled from the Obsidian vault profiles (2026-07).
//  Delete or edit freely — this only runs when the store is empty.
//

import Foundation
import SwiftData

enum SampleData {

    static func seedIfEmpty(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Pet>())) ?? 0
        guard existing == 0 else { return }

        func date(_ s: String) -> Date? {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "America/Chicago")
            return f.date(from: s)
        }

        // Clinics
        let waukee = VetClinic(name: "Waukee–Clive Veterinary Clinic")
        let ankeny = VetClinic(name: "Ankeny Animal & Avian Clinic")
        let broderick = VetClinic(name: "Broderick Animal Clinic")
        [waukee, ankeny, broderick].forEach { context.insert($0) }

        // Pets (all cats today — TailVault handles any species)
        let atwood = Pet(
            name: "Atwood", dob: date("2013-04-13"), gotchaDay: date("2013-04-13"),
            sex: "M (neutered)", breed: "Domestic Short Hair", colorMarkings: "Solid black",
            microchip: "4C36221E79", rabiesTag: "669377",
            activeConditions: ["Renal disease (IRIS stage 2)", "Periodontal disease grade 2", "Overgrooming / acral lick"],
            healthNotes: "CKD dx 2026-04-03; renal diet only, no ongoing meds."
        )

        let callen = Pet(
            name: "Callen", dob: date("2015-08-18"), gotchaDay: date("2015-12-16"),
            sex: "M (neutered)", breed: "Domestic Short Hair", colorMarkings: "Black and white tuxedo",
            microchip: "985112006763407", rabiesTag: "373225"
        )

        let dice = Pet(
            name: "Dice", formerName: "Olive Oyl", dob: date("2013-03-27"), gotchaDay: date("2013-07-01"),
            sex: "F (spayed)", breed: "Domestic Short Hair", colorMarkings: "White (solid)",
            microchip: "0A136A5E36", rabiesTag: "669378",
            activeConditions: ["Hyperthyroidism", "Periodontal disease grade 2", "Osteoarthritis", "Cardiac murmur grade 2", "Weight loss"],
            healthNotes: "On methimazole; gabapentin before vet visits."
        )

        let fergus = Pet(
            name: "Fergus", sex: "F", colorMarkings: "Gray (smaller, ear-tipped)",
            healthNotes: "Limited records — ear-tipped, likely former community cat."
        )

        let gothi = Pet(
            name: "Gothi", dob: date("2019-07-30"), gotchaDay: date("2023-11-03"),
            sex: "M (neutered)", breed: "Domestic Shorthair", colorMarkings: "Dark gray (solid)",
            microchip: "981020035638915", rabiesTag: "526172"
        )

        let hermione = Pet(
            name: "Hermione", dob: date("2019-06-02"),
            sex: "F (spayed)", breed: "Domestic Shorthair", colorMarkings: "Gray and white",
            microchip: "985113005358153", rabiesTag: "326092",
            activeConditions: ["Allergic dermatitis", "Psychogenic alopecia", "Superficial pyoderma", "Overweight"],
            healthNotes: "ISU Dermatology referral; gabapentin before vet visits."
        )

        let midas = Pet(
            name: "Midas", dob: date("2019-09-04"), gotchaDay: date("2021-02-12"),
            sex: "M (neutered)", breed: "Domestic Longhair / Mediumhair", colorMarkings: "Orange (long-haired / fluffy)",
            microchip: "985113004896767", rabiesTag: "424037",
            activeConditions: ["Upper respiratory infection", "Psychogenic alopecia"],
            temperamentNotes: "Sensitive at vet — hides face during exams, warms up once comfortable."
        )

        let watson = Pet(
            name: "Watson", dob: date("2020-04-08"), gotchaDay: date("2021-05-03"),
            sex: "F (spayed)", breed: "Domestic Short Hair", colorMarkings: "Gray tabby with white markings",
            rabiesTag: "470931",
            healthNotes: "From farm colony via Timothy Williams; prior care at Advanced Pet Care Clinic, Cedar Falls IA."
        )

        let pets = [atwood, callen, dice, fergus, gothi, hermione, midas, watson]
        pets.forEach { context.insert($0) }

        // Clinics
        atwood.primaryClinic = waukee
        callen.primaryClinic = waukee
        dice.primaryClinic = waukee
        watson.primaryClinic = waukee
        gothi.primaryClinic = broderick
        hermione.primaryClinic = ankeny
        midas.primaryClinic = ankeny

        // Weights
        atwood.weightLog.append(WeightEntry(date: .now, pounds: 12.6))
        callen.weightLog.append(WeightEntry(date: .now, pounds: 13.6))
        dice.weightLog.append(WeightEntry(date: .now, pounds: 8.6))
        gothi.weightLog.append(WeightEntry(date: .now, pounds: 10.89))
        hermione.weightLog.append(WeightEntry(date: .now, pounds: 15.8))
        watson.weightLog.append(WeightEntry(date: .now, pounds: 11.3))
        midas.weightLog.append(WeightEntry(date: date("2026-06-12") ?? .now, pounds: 16.1,
                                           note: "URI visit; 3 lb loss in 3 months"))
        midas.weightLog.append(WeightEntry(date: date("2026-03-26") ?? .now, pounds: 18.9))

        // Vaccines (Midas, from vault)
        midas.vaccinations.append(Vaccination(name: "Rabies", lastGiven: date("2026-03-26"), nextDue: date("2027-03-26")))
        midas.vaccinations.append(Vaccination(name: "FVRCP", lastGiven: date("2026-03-26"), nextDue: date("2027-03-26")))

        // Feeding — renal diet for the CKD cats, regular adult food otherwise
        func feed(_ pet: Pet, _ feedings: [Feeding]) {
            for (index, feeding) in feedings.enumerated() {
                feeding.sortOrder = index
                pet.feedings.append(feeding)
            }
        }

        func mealTime(_ hour: Int) -> Date {
            Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        }

        feed(atwood, [
            Feeding(kind: .prescription, brand: "Royal Canin", product: "Renal Support A (dry)",
                    amountValue: 0.25, amountUnit: .cup, frequency: .twiceDaily,
                    times: [mealTime(7), mealTime(18)],
                    instructions: "Renal diet only — no regular kibble."),
            Feeding(kind: .wet, brand: "Royal Canin", product: "Renal Support (loaf)",
                    amountValue: 0.5, amountUnit: .can, frequency: .onceDaily,
                    times: [mealTime(18)],
                    instructions: "Extra moisture for kidney support.")
        ])

        feed(dice, [
            Feeding(kind: .dry, brand: "Purina Pro Plan", product: "Adult Chicken & Rice",
                    amountValue: 0.5, amountUnit: .cup, frequency: .twiceDaily,
                    times: [mealTime(7), mealTime(18)],
                    instructions: "Weight loss — feed separately so others don't steal it.")
        ])

        feed(hermione, [
            Feeding(kind: .dry, brand: "Hill's Science Diet", product: "Perfect Weight",
                    amountValue: 0.33, amountUnit: .cup, frequency: .twiceDaily,
                    times: [mealTime(7), mealTime(18)],
                    instructions: "Measured portions — overweight.")
        ])

        for cat in [callen, fergus, gothi, midas, watson] {
            feed(cat, [
                Feeding(kind: .dry, brand: "Purina Pro Plan", product: "Adult Chicken & Rice",
                        amountValue: 0.5, amountUnit: .cup, frequency: .twiceDaily,
                        times: [mealTime(7), mealTime(18)])
            ])
        }

        // Medications
        let methimazole = Medication(
            name: "Methimazole (Felimazole)", dosage: "2.5 mg", frequency: .twiceDaily,
            doseTimes: [mealTime(7), mealTime(19)],
            instructions: "Hyperthyroidism — give with food."
        )
        dice.medications.append(methimazole)

        // A tapering dose: same drug, two strengths in one day. This is
        // exactly why the dashboard shows dosage next to the name.
        atwood.medications.append(Medication(
            name: "Prednisolone", dosage: "5 mg", frequency: .onceDaily,
            doseTimes: [mealTime(7)],
            instructions: "Morning dose — with breakfast."
        ))
        atwood.medications.append(Medication(
            name: "Prednisolone", dosage: "2.5 mg", frequency: .onceDaily,
            doseTimes: [mealTime(19)],
            instructions: "Evening half dose — tapering."
        ))

        // Walk / enrichment routines
        hermione.walkSchedules.append(WalkSchedule(
            label: "Leash walk", kind: .walk,
            times: [mealTime(9)], durationMinutes: 20,
            notes: "Harness only — slips a collar. Back yard loop."
        ))
        dice.walkSchedules.append(WalkSchedule(
            label: "Wand play", kind: .play,
            times: [mealTime(8), mealTime(20)], durationMinutes: 10,
            notes: "Weight loss plan — two sessions a day."
        ))
        midas.walkSchedules.append(WalkSchedule(
            label: "Puzzle feeder", kind: .enrichment,
            times: [mealTime(17)], durationMinutes: 15,
            daysOfWeek: [2, 4, 6],
            notes: "Every other weekday so he doesn't get bored of it."
        ))

        // Visit history
        midas.vetVisits.append(VetVisit(
            date: date("2026-06-12") ?? .now, reason: "URI — congestion, sneezing, coughing",
            clinicName: "Ankeny Animal & Avian Clinic",
            outcomeNotes: "Convenia injection. 16.1 lb (3 lb loss in 3 mo). Dental cleaning recommended once recovered."
        ))

        // Custom field example ("Notion for pets")
        midas.customFields.append(CustomField(name: "Carrier", value: "Gray soft-side, hall closet"))
    }

    /// One-time move of the old free-text `Pet.currentFood` note into a
    /// real `Feeding` record. Clearing the field makes this idempotent.
    static func migrateLegacyFood(context: ModelContext) {
        guard let pets = try? context.fetch(FetchDescriptor<Pet>()) else { return }
        for pet in pets {
            let legacy = pet.currentFood.trimmingCharacters(in: .whitespaces)
            guard !legacy.isEmpty else { continue }
            if pet.feedings.isEmpty {
                pet.feedings.append(Feeding(
                    kind: .other,
                    product: legacy,
                    frequency: .asNeeded,
                    instructions: "Imported from the old food note — add amount and schedule."
                ))
            }
            pet.currentFood = ""
        }
        try? context.save()
    }
}
