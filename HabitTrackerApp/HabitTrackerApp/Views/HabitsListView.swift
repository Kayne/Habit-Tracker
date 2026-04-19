//
//  HabitsListView.swift
//  HabitTrackerApp
//
//  Główny ekran po zalogowaniu: lista nawyków + przycisk dodania + logout.
//

import SwiftUI

struct HabitsListView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(HabitsStore.self) private var habits

    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if habits.habits.isEmpty && !habits.isLoading {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "checklist",
                        description: Text("Tap + to add your first habit.")
                    )
                } else {
                    List {
                        ForEach(habits.habits) { habit in
                            NavigationLink(value: habit) {
                                HabitRow(habit: habit)
                            }
                        }
                        .onDelete { indexSet in
                            let toDelete = indexSet.map { habits.habits[$0] }
                            Task {
                                for habit in toDelete {
                                    await habits.deleteHabit(id: habit.id)
                                }
                            }
                        }
                    }
                    .refreshable { await habits.loadHabits() }
                }
            }
            .navigationTitle("My Habits")
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habitId: habit.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let user = auth.currentUser {
                            Text(user.displayName)
                            Text(user.email).font(.caption)
                            Divider()
                        }
                        Button("Log out", role: .destructive) {
                            auth.logout()
                            habits.reset()
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateHabitView()
                    .environment(habits)
            }
            .task {
                // Pierwsze wejście — ładujemy listę i dane o userze.
                await habits.loadHabits()
                if auth.currentUser == nil {
                    await auth.fetchCurrentUser()
                }
            }
            .alert(
                "Error",
                isPresented: errorBinding,
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(habits.errorMessage ?? "") }
            )
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { habits.errorMessage != nil },
            set: { if !$0 { habits.errorMessage = nil } }
        )
    }
}

// MARK: - Row

private struct HabitRow: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(habit.name)
                .font(.headline)
            if let desc = habit.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("Target: \(habit.targetPerWeek)×/week")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HabitsListView()
        .environment(AuthStore())
        .environment(HabitsStore(auth: AuthStore()))
}
