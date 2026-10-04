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
            Household.self, ActivityLog.self, WalkSchedule.self, ChoreTask.self,
            TodoItem.self,
            PetDocument.self, Expense.self, JournalEntry.self
        ])
        // iCloud sync (CloudKit private database). Existing on-device data
        // is uploaded on first launch after the entitlement is added.
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.nateohrt.tailvault")
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            #if os(iOS)
            // Never seed on the Mac: its store starts empty until the first
            // iCloud sync lands, and seeding there would duplicate every
            // sample record once the iPhone's data arrives.
            SampleData.seedIfEmpty(context: context)
            #endif
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
                    // Seed cleaning chores for any new species/location
                    // pairs, then refresh their one-off reminders.
                    ChoreDefaults.autoCreate(context: context)
                    if let chores = try? context.fetch(FetchDescriptor<ChoreTask>()),
                       let pets = try? context.fetch(FetchDescriptor<Pet>()) {
                        NotificationManager.syncAllChores(chores, pets: pets)
                    }
                    if let todos = try? context.fetch(FetchDescriptor<TodoItem>()) {
                        NotificationManager.syncAllTodos(todos)
                    }
                }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1080, height: 720)
        #endif
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
