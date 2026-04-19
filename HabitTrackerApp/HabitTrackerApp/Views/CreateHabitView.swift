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
                Section("Habit") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Target") {
                    Stepper(value: $targetPerWeek, in: 1...7) {
                        Text("\(targetPerWeek)× per week")
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let ok = await habits.createHabit(
                                name: name.trimmingCharacters(in: .whitespaces),
                                description: description.trimmingCharacters(in: .whitespaces),
                                targetPerWeek: targetPerWeek
                            )
                            if ok { dismiss() }
                        }
                    }
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
}
