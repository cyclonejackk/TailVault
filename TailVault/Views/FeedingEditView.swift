//
//  FeedingEditView.swift
//  TailVault
//
//  Create/edit one food a pet gets: type, brand/product, amount,
//  how often, and what times.
//

import SwiftUI
import SwiftData

struct FeedingEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// nil = creating a new feeding
    let feeding: Feeding?

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    @State private var kind: FoodKind = .dry
    @State private var brand = ""
    @State private var product = ""
    @State private var amountText = ""
    @State private var amountUnit: FoodUnit = .cup
    @State private var frequency: FeedFrequency = .onceDaily
    @State private var customIntervalDays = 3
    @State private var times: [Date] = []
    @State private var instructions = ""
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now

    /// Accepts "0.5" and "1/2" — people measure food in fractions.
    private var amountValue: Double {
        FeedingEditView.parseAmount(amountText)
    }

    private var previewLine: String {
        let amount = amountValue > 0
            ? "\(Feeding.formatAmount(amountValue)) \(amountUnit.description(for: amountValue))"
            : ""
        let freq = frequency == .everyNDays ? "every \(customIntervalDays) days"
                                            : frequency.label.lowercased()
        return [amount, freq].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        Form {
            Section("Food") {
                Picker("Type", selection: $kind) {
                    ForEach(FoodKind.allCases) { k in
                        Text("\(k.emoji) \(k.label)").tag(k)
                    }
                }
                TextField("Brand (e.g. Royal Canin)", text: $brand)
                TextField("Product / flavor (e.g. Renal Support A)", text: $product)
            }

            Section {
                HStack {
                    TextField("Amount (e.g. 1/2 or 0.5)", text: $amountText)
                        .keyboardType(.numbersAndPunctuation)
                    Divider()
                    Picker("Unit", selection: $amountUnit) {
                        ForEach(FoodUnit.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                }
                Picker("How often", selection: $frequency) {
                    ForEach(FeedFrequency.allCases) { Text($0.label).tag($0) }
                }
                if frequency == .everyNDays {
                    Stepper("Every \(customIntervalDays) days", value: $customIntervalDays, in: 2...90)
                }
            } header: {
                Text("Amount & frequency")
            } footer: {
                if !previewLine.isEmpty {
                    Text("Per meal: \(previewLine)")
                }
            }

            if frequency.isScheduled {
                Section {
                    ForEach(times.indices, id: \.self) { index in
                        DatePicker("Meal \(index + 1)", selection: $times[index],
                                   displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }
                    Button {
                        times.append(defaultMealTime())
                    } label: {
                        Label("Add feeding time", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Feeding times")
                } footer: {
                    Text("Optional — e.g. 7 AM and 6 PM for twice daily. Interval schedules (every other day, every N days) count from the start date.")
                }
            }

            Section("Notes") {
                TextField("Instructions (warm 10 sec, puzzle feeder, feed alone…)",
                          text: $instructions, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                DatePicker("Started", selection: $startDate, displayedComponents: .date)
                Toggle("Discontinued", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Stopped on", selection: $endDate, displayedComponents: .date)
                }
            } header: {
                Text("Dates")
            } footer: {
                Text("Discontinued foods stay on the record but drop off the sitter profile and today's feedings.")
            }
        }
        .themedSurface(tintTheme)
        .navigationTitle(feeding == nil ? "New Food" : "Edit Food")
        .inlineNavigationTitle()
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

    /// Something has to identify the food — brand, product, or a non-generic type.
    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            || !product.trimmingCharacters(in: .whitespaces).isEmpty
            || kind != .other
    }

    private func defaultMealTime() -> Date {
        let hour = times.isEmpty ? 7 : 18
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }

    static func parseAmount(_ text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        // "1 1/2" → 1.5, "1/2" → 0.5, "0.5" → 0.5
        let parts = trimmed.split(separator: " ")
        var total = 0.0
        for part in parts {
            if part.contains("/") {
                let nums = part.split(separator: "/").compactMap { Double($0) }
                if nums.count == 2, nums[1] != 0 { total += nums[0] / nums[1] }
            } else if let value = Double(part) {
                total += value
            }
        }
        return total
    }

    private func load() {
        guard let feeding else {
            times = [defaultMealTime()]
            return
        }
        kind = feeding.kind
        brand = feeding.brand
        product = feeding.product
        amountText = feeding.amountValue > 0 ? Feeding.formatAmount(feeding.amountValue) : ""
        amountUnit = feeding.amountUnit
        frequency = feeding.frequency
        customIntervalDays = feeding.customIntervalDays
        times = feeding.times
        instructions = feeding.instructions
        startDate = feeding.startDate
        if let end = feeding.endDate { hasEndDate = true; endDate = end }
    }

    private func save() {
        let target = feeding ?? Feeding()
        target.kind = kind
        target.brand = brand.trimmingCharacters(in: .whitespaces)
        target.product = product.trimmingCharacters(in: .whitespaces)
        target.amountValue = amountValue
        target.amountUnit = amountUnit
        target.frequency = frequency
        target.customIntervalDays = customIntervalDays
        target.times = frequency.isScheduled ? times.sorted() : []
        target.instructions = instructions
        target.startDate = startDate
        target.endDate = hasEndDate ? endDate : nil

        if feeding == nil {
            target.sortOrder = (pet.feedings.map(\.sortOrder).max() ?? -1) + 1
            pet.feedings.append(target)
        }

        dismiss()
    }
}
