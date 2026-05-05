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
                    EmptyHabitsView()
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
            .navigationTitle("Moje nawyki")
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
                        Button("Wyloguj", role: .destructive) {
                            auth.logout()
                            habits.reset()
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateHabitView()
                    .environment(habits)
            }
            .task {
                await habits.loadHabits()
                if auth.currentUser == nil {
                    await auth.fetchCurrentUser()
                }
            }
            .alert(
                "Błąd",
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

    /// Deterministyczny kolor leaf-ikonki per nawyk — bierzemy hash UUID-a
    /// i mapujemy na jeden z kolorów palety. Dzięki temu każdy nawyk
    /// ma swój "własny" kolor ale zawsze ten sam między restartami.
    private var accent: Color {
        let palette: [Color] = [Theme.primary, Theme.secondary, Theme.accent, Theme.detail]
        let idx = abs(habit.id.hashValue) % palette.count
        return palette[idx]
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                Image(systemName: "leaf.fill")
                    .foregroundStyle(accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(Theme.primary)

                if let desc = habit.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text(habit.frequencyType.targetLabel(habit.targetPerFrequency))
                        .font(.caption)
                }
                .foregroundStyle(Theme.detail)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Theme.highlight.opacity(0.5))
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty state

private struct EmptyHabitsView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.highlight.opacity(0.7))
                    .frame(width: 120, height: 120)
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(Theme.secondary)
            }

            Text("Brak nawyków")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.primary)

            Text("Dodaj swój pierwszy nawyk przyciskiem + u góry.")
                .font(.subheadline)
                .foregroundStyle(Theme.detail)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HabitsListView()
        .environment(AuthStore())
        .environment(HabitsStore(auth: AuthStore()))
        .tint(Theme.primary)
}
