//
//  ContentView.swift
//  HabitTrackerApp
//
//  Root view — pokazuje LoginView gdy użytkownik niezalogowany,
//  a HabitsListView gdy token jest w Keychainie.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(HabitsStore.self) private var habits

    var body: some View {
        Group {
            if auth.isLoggedIn {
                HabitsListView()
            } else {
                LoginView()
            }
        }
        .task {
            // Jeśli mamy token z Keychaina, sprawdzamy czy jest wciąż ważny.
            // /auth/me zwróci 401 gdy expired — AuthStore wtedy się sam wyloguje.
            if auth.isLoggedIn && auth.currentUser == nil {
                await auth.fetchCurrentUser()
            }
        }
    }
}

#Preview {
    let auth = AuthStore()
    let habits = HabitsStore(auth: auth)
    return ContentView()
        .environment(auth)
        .environment(habits)
}
