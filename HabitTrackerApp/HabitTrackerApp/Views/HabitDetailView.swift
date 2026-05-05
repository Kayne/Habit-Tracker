//
//  HabitDetailView.swift
//  HabitTrackerApp
//
//  Szczegóły nawyku:
//    - kafelki ze statystykami (streak w copper, longest w ochre,
//      completion w sage z paskiem, total w forest)
//    - przycisk "Zaloguj dzisiaj" w copper
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
        ScrollView {
            VStack(spacing: 20) {
                if let habit { habitCard(habit) }

                statsGrid

                logTodayButton

                historySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Theme.highlight.opacity(0.15))
        .navigationTitle(habit?.name ?? "Nawyk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edytuj") { showEdit = true }
                    .disabled(habit == nil)
                    .foregroundStyle(Theme.primary)
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

    // MARK: - Header card

    @ViewBuilder
    private func habitCard(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.secondary)
                Text(habit.name)
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
                Spacer()
                Label(habit.frequencyType.targetLabel(habit.targetPerFrequency), systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(Theme.detail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.highlight.opacity(0.7)))
            }

            if let desc = habit.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Stats grid

    @ViewBuilder
    private var statsGrid: some View {
        let stats = habits.stats[habitId]
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            StatTile(
                icon: "flame.fill",
                label: "Obecny streak",
                value: stats.map { "\($0.currentStreakDays) dni" } ?? "—",
                color: Theme.accent
            )
            StatTile(
                icon: "trophy.fill",
                label: "Najdłuższy",
                value: stats.map { "\($0.longestStreakDays) dni" } ?? "—",
                color: Theme.detail
            )
            StatTile(
                icon: "chart.bar.fill",
                label: "Łącznie",
                value: stats.map { "\($0.totalLogs)" } ?? "—",
                color: Theme.primary
            )
            CompletionTile(
                rate: stats?.completionRateCurrentPeriod ?? 0,
                frequencyType: habit?.frequencyType ?? .weekly,
                hasData: stats != nil
            )
        }
    }

    // MARK: - Log today button

    private var logTodayButton: some View {
        Button {
            Task { await habits.logToday(habitId: habitId) }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Zaloguj dzisiaj")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .controlSize(.large)
        .disabled(habits.isLoading)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Theme.secondary)
                Text("Historia")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
            }

            let allLogs = habits.logs[habitId] ?? []
            if allLogs.isEmpty {
                Text("Jeszcze nic nie zalogowano.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allLogs.enumerated()), id: \.element.id) { idx, log in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Theme.secondary)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.loggedOn)
                                    .font(.body)
                                    .foregroundStyle(Theme.primary)
                                if let note = log.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)

                        if idx < allLogs.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }
}

// MARK: - Stat tiles

private struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct CompletionTile: View {
    let rate: Double       // 0.0 ... 1.0
    let frequencyType: FrequencyType
    let hasData: Bool

    private var percent: Int { Int((rate * 100).rounded()) }

    private var periodLabel: String {
        switch frequencyType {
        case .daily:   return "Ostatnie 7 dni"
        case .weekly:  return "Ostatnie 7 dni"
        case .monthly: return "Ostatnie 30 dni"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Theme.secondary)
                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(hasData ? "\(percent)%" : "—")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.secondary)

            // Mini-pasek postępu w kolorze sage.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.secondary.opacity(0.2))
                    Capsule()
                        .fill(Theme.secondary)
                        .frame(width: geo.size.width * max(0, min(1, rate)))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Edit sheet

private struct EditHabitView: View {
    @Environment(HabitsStore.self) private var habits
    @Environment(\.dismiss) private var dismiss

    let habit: Habit

    @State private var name: String
    @State private var description: String
    @State private var frequencyType: FrequencyType
    @State private var targetPerFrequency: Int

    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _description = State(initialValue: habit.description ?? "")
        _frequencyType = State(initialValue: habit.frequencyType)
        _targetPerFrequency = State(initialValue: habit.targetPerFrequency)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !habits.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nawyk") {
                    TextField("Nazwa", text: $name)
                    TextField("Opis", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Częstotliwość") {
                    Picker("Okres", selection: $frequencyType) {
                        ForEach(FrequencyType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: frequencyType) { _, newType in
                        targetPerFrequency = min(targetPerFrequency, newType.maxTarget)
                        if targetPerFrequency < 1 { targetPerFrequency = newType.defaultTarget }
                    }

                    Stepper(value: $targetPerFrequency, in: 1...frequencyType.maxTarget) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(Theme.secondary)
                            Text(frequencyType.targetLabel(targetPerFrequency))
                        }
                    }
                }
            }
            .navigationTitle("Edycja nawyku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .foregroundStyle(Theme.detail)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        Task {
                            let trimmedName = name.trimmingCharacters(in: .whitespaces)
                            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
                            let ok = await habits.updateHabit(
                                id: habit.id,
                                name: trimmedName == habit.name ? nil : trimmedName,
                                description: trimmedDesc == (habit.description ?? "") ? nil : trimmedDesc,
                                frequencyType: frequencyType == habit.frequencyType ? nil : frequencyType,
                                targetPerFrequency: targetPerFrequency == habit.targetPerFrequency ? nil : targetPerFrequency
                            )
                            if ok { dismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
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
            .tint(Theme.primary)
    }
}
