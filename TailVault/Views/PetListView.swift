//
//  PetListView.swift
//  TailVault
//
//  Home tab: all pets, search (name or species), add,
//  export-to-spreadsheet, share whole-household sitter guide.
//

import SwiftUI
import SwiftData

enum PetSort: String, CaseIterable, Identifiable {
    case name, age, species, weight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .name:    return "Name"
        case .age:     return "Age (oldest first)"
        case .species: return "Species"
        case .weight:  return "Weight (heaviest first)"
        }
    }
}

struct PetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Household.name) private var households: [Household]

    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky
    @AppStorage(CurrentLocation.key) private var currentLocationID = ""
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var exportURL: URL?
    @State private var petsToDelete: [Pet] = []

    // Sort & filter
    @State private var sortBy: PetSort = .name
    @State private var speciesFilter: String?
    @State private var sexFilter: String?        // "M" / "F"
    @State private var showInactive = true

    private var currentLocation: Household? {
        CurrentLocation.resolve(from: households, idString: currentLocationID)
    }

    /// Everything at the current location — the base set for this page.
    private var localPets: [Pet] { pets.at(currentLocation) }

    /// Species present in the list, for the filter menu.
    private var speciesPresent: [String] {
        Array(Set(pets.map(\.species))).sorted()
    }

    private var filtersActive: Bool {
        speciesFilter != nil || sexFilter != nil || !showInactive
    }

    private var filteredPets: [Pet] {
        var result = localPets

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.species.localizedCaseInsensitiveContains(searchText) ||
                $0.breed.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let speciesFilter {
            result = result.filter { $0.species == speciesFilter }
        }
        if let sexFilter {
            result = result.filter { $0.sex.uppercased().hasPrefix(sexFilter) }
        }
        if !showInactive {
            result = result.filter(\.isActive)
        }

        switch sortBy {
        case .name:
            result.sort { $0.name < $1.name }
        case .age:
            result.sort { ($0.dob ?? .distantFuture) < ($1.dob ?? .distantFuture) }
        case .species:
            result.sort { ($0.species, $0.name) < ($1.species, $1.name) }
        case .weight:
            result.sort { ($0.currentWeight?.pounds ?? 0) > ($1.currentWeight?.pounds ?? 0) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPets.filter(\.isActive)) { pet in
                    NavigationLink(value: pet) {
                        PetRow(pet: pet)
                    }
                }
                .onDelete(perform: delete)

                // Inactive pets live in their own quiet section.
                let remembered = filteredPets.filter { !$0.isActive }
                if !remembered.isEmpty {
                    Section("Remembered 🌈") {
                        ForEach(remembered) { pet in
                            NavigationLink(value: pet) {
                                PetRow(pet: pet)
                            }
                        }
                    }
                }
            }
            .themedSurface(tintTheme)
            .navigationTitle(filtersActive ? "Pets (\(filteredPets.count)/\(localPets.count))" : "Pets (\(localPets.count))")
            .navigationDestination(for: Pet.self) { PetDetailView(pet: $0) }
            .searchable(text: $searchText, prompt: "Search pets")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .trailingBar) {
                    Menu {
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(PetSort.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)

                        Picker("Species", selection: $speciesFilter) {
                            Text("All species").tag(nil as String?)
                            ForEach(speciesPresent, id: \.self) { s in
                                Text("\(SpeciesCatalog.emoji(for: s)) \(s)").tag(s as String?)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Sex", selection: $sexFilter) {
                            Text("All sexes").tag(nil as String?)
                            Text("Male").tag("M" as String?)
                            Text("Female").tag("F" as String?)
                        }
                        .pickerStyle(.menu)

                        Toggle("Show inactive pets", isOn: $showInactive)

                        if filtersActive {
                            Button("Clear filters") {
                                speciesFilter = nil
                                sexFilter = nil
                                showInactive = true
                            }
                        }
                    } label: {
                        Image(systemName: filtersActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .leadingBar) {
                    LocationMenu()
                }
                ToolbarItem(placement: .leadingBar) {
                    Menu {
                        Button {
                            exportURL = CSVExporter.exportPets(localPets)
                        } label: {
                            Label("Export all to spreadsheet (CSV)", systemImage: "tablecells")
                        }
                        ShareLink(
                            item: SitterSummary.householdText(pets: localPets.filter(\.isActive), allPets: pets)
                        ) {
                            Label("Share household sitter guide", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { PetEditView(pet: nil) }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .alert(deleteAlertTitle, isPresented: deleteAlertPresented) {
                Button("Delete", role: .destructive) {
                    for pet in petsToDelete { context.delete(pet) }
                    petsToDelete = []
                }
                Button("Cancel", role: .cancel) { petsToDelete = [] }
            } message: {
                Text("This permanently removes the profile plus all medications, dose logs, vet visits, weights, and activity history. Attendance records keep their other pets.")
            }
        }
    }

    private var deleteAlertTitle: String {
        "Delete \(petsToDelete.map(\.name).joined(separator: ", "))?"
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { !petsToDelete.isEmpty },
            set: { if !$0 { petsToDelete = [] } }
        )
    }

    /// Swipe-to-delete only stages the pet — the alert above confirms.
    /// Offsets index into the active-pets ForEach, not filteredPets.
    private func delete(at offsets: IndexSet) {
        let active = filteredPets.filter(\.isActive)
        petsToDelete = offsets.map { active[$0] }
    }
}

// MARK: - Row

private struct PetRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            PetAvatar(pet: pet, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pet.name).font(.headline)
                    Text(pet.speciesEmoji).font(.subheadline)
                    if !pet.isActive {
                        Text("inactive")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(
                    [pet.colorMarkings, pet.ageDescription, pet.household.map { "🏠 \($0.name)" } ?? ""]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    if !pet.activeMedications.isEmpty {
                        Label("\(pet.activeMedications.count)", systemImage: "pills.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let next = pet.upcomingVisits.first {
                        Label(next.date.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "stethoscope")
                            .font(.caption).foregroundStyle(.teal)
                    }
                    if !pet.activeConditions.isEmpty {
                        Image(systemName: "heart.text.square")
                            .font(.caption).foregroundStyle(.pink)
                            .accessibilityLabel("\(pet.activeConditions.count) active conditions")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Share helpers

/// Makes URL usable with .sheet(item:). @retroactive acknowledges this
/// conformance belongs to us, not Foundation.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if os(iOS)
/// UIKit share sheet wrapper — used for file URLs (CSV) so the
/// receiving app treats them as spreadsheet files.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#else
/// macOS stand-in for the iOS share sheet, presented from the same
/// `.sheet` call sites: share, reveal the file in Finder, or close.
struct ShareSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(url.lastPathComponent)
                .font(.headline)
            HStack(spacing: 12) {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(minWidth: 320)
    }
}
#endif
