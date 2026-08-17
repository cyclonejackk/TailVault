//
//  NotificationManager.swift
//  TailVault
//
//  Local notifications for medication dose times and day-before
//  vet visit reminders.
//
//  Daily/weekly/monthly meds use repeating calendar triggers.
//  Interval meds (every other day / every N days) can't be expressed
//  as a repeating trigger, so we schedule the next 15 occurrences as
//  one-off notifications and top them up on every app launch via
//  syncAll(medications:).
//

import Foundation
import UserNotifications

@MainActor
enum NotificationManager {

    static func requestPermission() {
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Call at app launch to refresh interval-based schedules.
    static func syncAll(medications: [Medication]) {
        for med in medications { syncReminders(for: med) }
    }

    // MARK: Medications

    /// Reschedules all reminders for a medication. Call after any edit.
    /// Async work runs in a Task that stays on the main actor, so the
    /// SwiftData model is never touched from another thread.
    static func syncReminders(for med: Medication) {
        Task {
            let center = UNUserNotificationCenter.current()
            let prefix = "med-\(med.id.uuidString)"
            let pending = await center.pendingNotificationRequests()
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            guard med.remindersEnabled, med.isActive, med.frequency != .asNeeded else { return }

            let content = doseContent(for: med)

            if let interval = med.frequency.intervalDays(custom: med.customIntervalDays) {
                scheduleIntervalDoses(med: med, everyDays: interval, content: content,
                                      prefix: prefix, center: center)
            } else {
                scheduleRepeatingDoses(med: med, content: content,
                                       prefix: prefix, center: center)
            }
        }
    }

    private static func doseContent(for med: Medication) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "💊 \(med.pet?.name ?? "Pet"): \(med.displayName)"
        content.body = [med.dosage, med.instructions]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
        if content.body.isEmpty { content.body = "Time for a dose — log it in TailVault." }
        content.sound = .default
        return content
    }

    /// Daily / twice daily / 3× daily / weekly / monthly → repeating calendar triggers.
    private static func scheduleRepeatingDoses(
        med: Medication, content: UNMutableNotificationContent,
        prefix: String, center: UNUserNotificationCenter
    ) {
        for (index, time) in med.doseTimes.enumerated() {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            if med.frequency == .weekly {
                comps.weekday = Calendar.current.component(.weekday, from: med.startDate)
            } else if med.frequency == .monthly {
                comps.day = Calendar.current.component(.day, from: med.startDate)
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "\(prefix)-\(index)",
                                             content: content, trigger: trigger))
        }
    }

    /// Every other day / every N days → next 15 one-off notifications per dose time,
    /// stepped from the medication's start date so the cycle stays anchored.
    private static func scheduleIntervalDoses(
        med: Medication, everyDays: Int, content: UNMutableNotificationContent,
        prefix: String, center: UNUserNotificationCenter
    ) {
        let calendar = Calendar.current
        for (timeIndex, time) in med.doseTimes.enumerated() {
            let timeComps = calendar.dateComponents([.hour, .minute], from: time)
            var doseDay = calendar.startOfDay(for: med.startDate)
            var scheduled = 0

            while scheduled < 15 {
                if let fireDate = calendar.date(bySettingHour: timeComps.hour ?? 8,
                                                minute: timeComps.minute ?? 0,
                                                second: 0, of: doseDay),
                   fireDate > .now {
                    if let end = med.endDate, fireDate > end { break }
                    let comps = calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    center.add(UNNotificationRequest(
                        identifier: "\(prefix)-\(timeIndex)-\(scheduled)",
                        content: content, trigger: trigger))
                    scheduled += 1
                }
                guard let next = calendar.date(byAdding: .day, value: everyDays, to: doseDay) else { break }
                doseDay = next
            }
        }
    }

    // MARK: Vet visits

    /// Schedules a reminder at 9 AM the day before the visit.
    static func syncReminder(for visit: VetVisit) {
        let center = UNUserNotificationCenter.current()
        let identifier = "visit-\(visit.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard visit.reminderEnabled, visit.isUpcoming else { return }
        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: visit.date),
              let fireDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore),
              fireDate > .now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "🏥 Vet tomorrow: \(visit.pet?.name ?? "Pet")"
        content.body = "\(visit.reason)" + (visit.clinicName.isEmpty ? "" : " — \(visit.clinicName)")
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
