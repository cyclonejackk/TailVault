//
//  ContentView.swift
//  TailVault
//
//  iOS: bottom tab bar. macOS: sidebar — the same five sections,
//  each hosting its own NavigationStack.
//

import SwiftUI

#if os(iOS)
struct ContentView: View {
    var body: some View {
        // Rounded type everywhere — softer without losing the minimal look.
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            PetListView()
                .tabItem { Label("Pets", systemImage: "pawprint.fill") }

            AttendanceView()
                .tabItem { Label("Attendance", systemImage: "checklist") }

            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar.badge.clock") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .fontDesign(.rounded)
    }
}
#else
struct ContentView: View {
    enum AppSection: String, CaseIterable, Identifiable {
        case home, pets, attendance, schedule, settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .home:       return "Home"
            case .pets:       return "Pets"
            case .attendance: return "Attendance"
            case .schedule:   return "Schedule"
            case .settings:   return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .home:       return "house.fill"
            case .pets:       return "pawprint.fill"
            case .attendance: return "checklist"
            case .schedule:   return "calendar.badge.clock"
            case .settings:   return "gearshape.fill"
            }
        }
    }

    @State private var section: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { s in
                Label(s.label, systemImage: s.symbol).tag(s)
            }
            .navigationTitle("TailVault")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            // Each section keeps its own NavigationStack (defined inside
            // the view), so push navigation works the same as on iOS.
            switch section ?? .home {
            case .home:       DashboardView()
            case .pets:       PetListView()
            case .attendance: AttendanceView()
            case .schedule:   ScheduleView()
            case .settings:   SettingsView()
            }
        }
        .fontDesign(.rounded)
    }
}
#endif

#Preview {
    ContentView()
}
