//
//  MedLogView.swift
//  TailVault
//
//  Per-pet medication administration log: log doses (given or skipped,
//  now or backdated), review history, and share the record with the
//  vet as text or CSV.
//

import SwiftUI
import SwiftData

struct MedLogView: View {
    @Environment(\.modelContext) private var context
    @Bindable var pet: Pet
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var exportURL: URL?
    @State private var loggingMed: Medication?

    private var allLogs: [(med: Medication, log: MedDoseLog)] {
        pet.medications
            .flatMap { med in med.doseLogs.map { (med, $0) } }
            .sorted { $0.log.date > $1.log.date }
    }

    var body: some View {
        List {
            Section("Log a dose") {
                ForEach(pet.activeMedications.sorted { $0.displayName < $1.displayName }) { med in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.displayName)
                            Text([med.frequencyDescription, med.doseTimesDescription]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Given ✓") {
                            med.logDose()
                            Haptics.success()
                        }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        Button {
                            loggingMed = med
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .buttonStyle(.borderless) // keep row tap from swallowing buttons
                }
            }

            Section("History (\(allLogs.count))") {
                if allLogs.isEmpty {
                    Text("No doses logged yet. Tap “Given ✓” above when you give a med.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(allLogs, id: \.log.persistentModelID) { item in
                    HStack {
                        Image(systemName: item.log.skipped ? "xmark.circle" : "checkmark.circle.fill")
                            .foregroundStyle(item.log.skipped ? .red : .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.med.displayName)
                            Text(item.log.date.formatted(date: .abbreviated, time: .shortened) +
                                 (item.log.note.isEmpty ? "" : " — \(item.log.note)"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.log.skipped {
                            Text("skipped").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(allLogs[index].log) }
                }
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle("\(pet.name) — Med Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: VetReport.medicationHistory(for: pet)) {
                        Label("Send report to vet (text)", systemImage: "cross.case")
                    }
                    Button {
                        exportURL = CSVExporter.exportMedLogs([pet])
                    } label: {
                        Label("Export log (CSV)", systemImage: "tablecells")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(allLogs.isEmpty)
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(url: url)
        }
        .sheet(item: $loggingMed) { med in
            NavigationStack { LogDoseSheet(medication: med) }
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Detailed dose entry (backdate, skip, note)

private struct LogDoseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let medication: Medication

    @State private var date = Date.now
    @State private var skipped = false
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Medication", value: medication.displayName)
                DatePicker("When", selection: $date)
                Toggle("Dose was skipped/missed", isOn: $skipped)
                TextField("Note (spit out half, gave in churu…)", text: $note, axis: .vertical)
            } footer: {
                Text("Use this for backdated doses or skips; the “Given ✓” button logs right now.")
            }
        }
        .navigationTitle("Log Dose")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    medication.logDose(at: date, skipped: skipped, note: note)
                    dismiss()
                }
            }
        }
    }
}
