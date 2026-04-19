//
//  HabitTrackerAppApp.swift
//  HabitTrackerApp
//
//  Entry point: tworzymy AuthStore i HabitsStore raz, na poziomie App,
//  i wstrzykujemy je jako @Environment do całej hierarchii.
//

import SwiftUI

@main
struct HabitTrackerAppApp: App {

    @State private var auth: AuthStore
    @State private var habits: HabitsStore

    init() {
        let auth = AuthStore()
        self._auth = State(wrappedValue: auth)
        self._habits = State(wrappedValue: HabitsStore(auth: auth))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(habits)
                // Jedno miejsce które koloruje wszystkie natywne controlsy
                // (buttony, ProgressView, toggle, nav tint) — patrz Theme.swift.
                .tint(Theme.primary)
        }
    }
}
