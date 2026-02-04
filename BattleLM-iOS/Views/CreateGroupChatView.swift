import SwiftUI
import BattleLMShared

struct CreateGroupChatView: View {
    @EnvironmentObject var connection: RemoteConnection
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedMemberIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Chat Name") {
                    TextField("e.g., Model Comparison", text: $name)
                }

                Section("Select Members") {
                    if connection.aiList.isEmpty {
                        Text("No AI instances")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(connection.aiList) { ai in
                            Button {
                                toggle(ai.id)
                            } label: {
                                HStack {
                                    Text(ai.name)
                                    Spacer()
                                    if selectedMemberIds.contains(ai.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Create Group Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        create()
                    }
                    .disabled(trimmedName.isEmpty || selectedMemberIds.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = defaultName()
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggle(_ id: UUID) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
    }

    private func create() {
        let memberIds = Array(selectedMemberIds)
        let chatName = trimmedName
        Task {
            try? await connection.createGroupChat(name: chatName, memberIds: memberIds)
            dismiss()
        }
    }

    private func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Group \(formatter.string(from: Date()))"
    }
}

