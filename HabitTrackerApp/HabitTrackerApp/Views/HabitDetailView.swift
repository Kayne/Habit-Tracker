//
//  HabitDetailView.swift
//  HabitTrackerApp
//
//  Szczegóły nawyku:
//    - statystyki (streak, total, completion rate 7d)
//    - przycisk "Log today" (POST /habits/{id}/logs)
//    - historia wpisów
//    - edycja (PATCH)
//

import SwiftUI

struct HabitDetailView: View {
    @Environment(HabitsStore.self) private var habits

    let habitId: UUID

    @State private var showEdit: Bool = false

    private var habit: Habit? {
        habits.habits.first(where: { $0.id == habitId })
    }

    var body: some View {
        List {
            if let habit {
                Section("Habit") {
                    LabeledContent("Name", value: habit.name)
                    if let desc = habit.description, !desc.isEmpty {
                        LabeledContent("Description", value: desc)
                    }
                    LabeledContent("Target", value: "\(habit.targetPerWeek)× / week")
                }
            }

            Section("Stats") {
                if let stats = habits.stats[habitId] {
                    LabeledContent("Total logs", value: "\(stats.totalLogs)")
                    LabeledContent("Current streak", value: "\(stats.currentStreakDays) days")
                    LabeledContent("Longest streak", value: "\(stats.longestStreakDays) days")
                    LabeledContent(
                        "Last 7 days",
                        value: "\(Int((stats.completionRate7d * 100).rounded()))%"
                    )
                    LabeledContent(
                        "Last logged",
                        value: stats.lastLoggedOn ?? "—"
                    )
                } else if habits.isLoading {
                    ProgressView()
                } else {
                    Text("No stats yet.").foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await habits.logToday(habitId: habitId) }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log today")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(habits.isLoading)
                .listRowBackground(Color.clear)
            }

            Section("History") {
                let allLogs = habits.logs[habitId] ?? []
                if allLogs.isEmpty {
                    Text("No logs yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(allLogs) { log in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.loggedOn).font(.body)
                            if let note = log.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(habit?.name ?? "Habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
                    .disabled(habit == nil)
            }
        }
        .sheet(isPresented: $showEdit) {
            if let habit {
                EditHabitView(habit: habit)
                    .environment(habits)
            }
        }
        .task {
            await habits.loadStats(habitId: habitId)
            await habits.loadLogs(habitId: habitId)
        }
        .refreshable {
            await habits.loadStats(habitId: habitId)
            await habits.loadLogs(habitId: habitId)
        }
    }
}

// MARK: - Edit sheet

private struct EditHabitView: View {
    @Environment(HabitsStore.self) private var habits
    @Environment(\.dismiss) private var dismiss

    let habit: Habit

    @State private var name: String
    @State private var description: String
    @State private var targetPerWeek: Int

    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _description = State(initialValue: habit.description ?? "")
        _targetPerWeek = State(initialValue: habit.targetPerWeek)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !habits.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Target") {
                    Stepper(value: $targetPerWeek, in: 1...7) {
                        Text("\(targetPerWeek)× per week")
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            // PATCH — wysyłamy tylko to, co się faktycznie zmieniło.
                            let trimmedName = name.trimmingCharacters(in: .whitespaces)
                            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
                            let ok = await habits.updateHabit(
                                id: habit.id,
                                name: trimmedName == habit.name ? nil : trimmedName,
                                description: trimmedDesc == (habit.description ?? "") ? nil : trimmedDesc,
                                targetPerWeek: targetPerWeek == habit.targetPerWeek ? nil : targetPerWeek
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habitId: UUID())
            .environment(HabitsStore(auth: AuthStore()))
    }
}
