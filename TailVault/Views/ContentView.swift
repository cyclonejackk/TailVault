//
//  ContentView.swift
//  TailVault
//

import SwiftUI

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

#Preview {
    ContentView()
}
