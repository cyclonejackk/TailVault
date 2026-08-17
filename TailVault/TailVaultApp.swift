//
//  TailVaultApp.swift
//  TailVault — every pet, one vault
//
//  Entry point. SwiftData container + appearance (dark/light/system).
//

import SwiftUI
import SwiftData

@main
struct TailVaultApp: App {
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    let container: ModelContainer = {
        let schema = Schema([
            Pet.self, CustomField.self, WeightEntry.self, Vaccination.self,
            Medication.self, MedDoseLog.self, Feeding.self, FeedLog.self,
            VetClinic.self, VetVisit.self,
            AttendanceRecord.self, AttendanceEntry.self,
            Household.self, ActivityLog.self, WalkSchedule.self,
            PetDocument.self, Expense.self, JournalEntry.self
        ])
        do {
            let container = try ModelContainer(for: schema)
            let context = ModelContext(container)
            SampleData.seedIfEmpty(context: context)
            SampleData.migrateLegacyFood(context: context)
            return container
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
                .tint(tintTheme.accent)
                .onAppear {
                    NotificationManager.requestPermission()
                    // Top up interval-based med reminders (every-N-days
                    // schedules are finite batches of one-off notifications).
                    let context = ModelContext(container)
                    if let meds = try? context.fetch(FetchDescriptor<Medication>()) {
                        NotificationManager.syncAll(medications: meds)
                    }
                }
        }
        .modelContainer(container)
    }
}

/// User-selectable theme: follows the system, or forces light/dark.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
