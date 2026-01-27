// BattleLM/Views/Settings/Sheets.swift
import SwiftUI
import UniformTypeIdentifiers

/// 添加 AI 对话框
struct AddAISheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType: AIType = .claude
    @State private var customName: String = ""
    @State private var workingDirectory: String = ""
    @State private var showFolderPicker: Bool = false
    @State private var cliAvailable: Bool? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("Add AI Instance")
                .font(.title2)
                .fontWeight(.bold)
            
            // AI 类型选择
            VStack(alignment: .leading, spacing: 12) {
                Text("Select AI Type")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    ForEach(AIType.allCases) { type in
                        AITypeCard(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                            if customName.isEmpty {
                                customName = type.displayName
                            }
                            checkCLI()
                        }
                    }
                }
                
                // CLI 状态提示
                if let available = cliAvailable {
                    HStack {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(available ? .green : .red)
                        Text(available ? "\(selectedType.displayName) CLI is installed" : "\(selectedType.displayName) CLI not found")
                            .font(.caption)
                            .foregroundColor(available ? .green : .red)
                    }
                }
            }
            
            // 自定义名称
            VStack(alignment: .leading, spacing: 8) {
                Text("Name (Optional)")
                    .font(.headline)
                
                TextField("e.g., Claude for Debug", text: $customName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 工作目录
            VStack(alignment: .leading, spacing: 8) {
                Text("Working Directory")
                    .font(.headline)
                
                HStack {
                    TextField("Select project folder...", text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    Button("Browse...") {
                        showFolderPicker = true
                    }
                }
                
                Text("The AI CLI will run in this directory")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 按钮
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    appState.addAI(
                        type: selectedType,
                        name: customName.isEmpty ? nil : customName,
                        workingDirectory: workingDirectory
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(workingDirectory.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 450)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                workingDirectory = url.path
            }
        }
        .onAppear {
            checkCLI()
        }
    }
    
    private func checkCLI() {
        Task {
            let available = await DependencyChecker.checkAI(selectedType)
            await MainActor.run {
                cliAvailable = available
            }
        }
    }
}

/// AI 类型卡片
struct AITypeCard: View {
    let type: AIType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : Color(hex: type.color))
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 100, height: 100)
            .background(isSelected ? Color(hex: type.color) : Color(.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 创建群聊对话框
struct CreateGroupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var chatName: String = ""
    @State private var selectedAIIds: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("Create Group Chat")
                .font(.title2)
                .fontWeight(.bold)
            
            // 群聊名称
            VStack(alignment: .leading, spacing: 8) {
                Text("Chat Name")
                    .font(.headline)
                
                TextField("e.g., Bug Discussion", text: $chatName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 选择 AI
            VStack(alignment: .leading, spacing: 12) {
                Text("Select AI Participants")
                    .font(.headline)
                
                if appState.aiInstances.isEmpty {
                    Text("No AI instances available. Please add some first.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.aiInstances) { ai in
                            AISelectionRow(
                                ai: ai,
                                isSelected: selectedAIIds.contains(ai.id)
                            ) {
                                if selectedAIIds.contains(ai.id) {
                                    selectedAIIds.remove(ai.id)
                                } else {
                                    selectedAIIds.insert(ai.id)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // 按钮
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") {
                    let name = chatName.isEmpty ? "New Chat" : chatName
                    appState.createGroupChat(
                        name: name,
                        memberIds: Array(selectedAIIds)
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedAIIds.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 400)
    }
}

/// AI 选择行
struct AISelectionRow: View {
    let ai: AIInstance
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Image(systemName: ai.type.iconName)
                    .foregroundColor(ai.color)
                
                Text(ai.name)
                
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Add AI") {
    AddAISheet()
        .environmentObject(AppState())
}

#Preview("Create Group") {
    CreateGroupSheet()
        .environmentObject(AppState())
}
