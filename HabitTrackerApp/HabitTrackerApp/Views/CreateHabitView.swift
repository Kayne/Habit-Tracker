//
//  CreateHabitView.swift
//  HabitTrackerApp
//
//  Sheet z formularzem utworzenia nowego nawyku.
//

import SwiftUI

struct CreateHabitView: View {
    @Environment(HabitsStore.self) private var habits
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var targetPerWeek: Int = 7

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !habits.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.18))
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nowy nawyk")
                                .font(.headline)
                                .foregroundStyle(Theme.primary)
                            Text("Zdefiniuj co chcesz śledzić.")
                                .font(.caption)
                                .foregroundStyle(Theme.detail)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Theme.highlight.opacity(0.4))
                }

                Section("Nawyk") {
                    TextField("Nazwa", text: $name)
                    TextField("Opis (opcjonalnie)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Cel") {
                    Stepper(value: $targetPerWeek, in: 1...7) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(Theme.secondary)
                            Text("\(targetPerWeek)× na tydzień")
                        }
                    }
                }
            }
            .navigationTitle("Nowy nawyk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .foregroundStyle(Theme.detail)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        Task {
                            let ok = await habits.createHabit(
                                name: name.trimmingCharacters(in: .whitespaces),
                                description: description.trimmingCharacters(in: .whitespaces),
                                targetPerWeek: targetPerWeek
                            )
                            if ok { dismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
                    .disabled(!canSubmit)
                }
            }
            .overlay {
                if habits.isLoading { ProgressView() }
            }
        }
    }
}

#Preview {
    CreateHabitView()
        .environment(HabitsStore(auth: AuthStore()))
        .tint(Theme.primary)
}
