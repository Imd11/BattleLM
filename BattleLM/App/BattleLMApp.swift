// BattleLM/App/BattleLMApp.swift
import SwiftUI

@main
struct BattleLMApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            
            // 自定义菜单
            CommandGroup(after: .newItem) {
                Button("New Group Chat") {
                    appState.showCreateGroupSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Add AI Instance") {
                    appState.showAddAISheet = true
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
    }
}
