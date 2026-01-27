// BattleLM/Services/SessionManager.swift
import Foundation
import Combine

/// tmux 会话管理器
class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    /// 活跃的会话 [AI ID: tmux session name]
    @Published var activeSessions: [UUID: String] = [:]
    
    /// 会话状态
    @Published var sessionStatus: [UUID: SessionStatus] = [:]
    
    private init() {}
    
    // MARK: - Session Lifecycle
    
    /// 为 AI 创建并启动 tmux 会话
    func startSession(for ai: AIInstance) async throws {
        let sessionName = ai.tmuxSession
        
        // 检查会话是否已存在
        let exists = try await sessionExists(sessionName)
        
        if !exists {
            // 创建新会话
            try await runTmux(["new-session", "-d", "-s", sessionName])
        }
        
        // 启动 AI CLI
        try await sendToSession(sessionName, text: ai.type.cliCommand)
        
        // 记录会话
        await MainActor.run {
            activeSessions[ai.id] = sessionName
            sessionStatus[ai.id] = .running
        }
        
        print("✅ Session started: \(sessionName) for \(ai.name)")
    }
    
    /// 停止 tmux 会话
    func stopSession(for ai: AIInstance) async throws {
        guard let sessionName = activeSessions[ai.id] else { return }
        
        // 杀死会话
        _ = try? await runTmux(["kill-session", "-t", sessionName])
        
        await MainActor.run {
            activeSessions.removeValue(forKey: ai.id)
            sessionStatus[ai.id] = .stopped
        }
        
        print("🛑 Session stopped: \(sessionName)")
    }
    
    /// 检查会话是否存在
    func sessionExists(_ name: String) async throws -> Bool {
        let result = try await runTmux(["has-session", "-t", name])
        return result.exitCode == 0
    }
    
    // MARK: - Message Sending
    
    /// 发送消息到 AI 会话
    func sendMessage(_ message: String, to ai: AIInstance) async throws {
        guard let sessionName = activeSessions[ai.id] else {
            throw SessionError.sessionNotFound(ai.name)
        }
        
        try await sendToSession(sessionName, text: message)
    }
    
    /// 发送文本到 tmux 会话
    private func sendToSession(_ session: String, text: String) async throws {
        try await runTmux(["send-keys", "-t", session, text, "Enter"])
    }
    
    // MARK: - Output Capture
    
    /// 捕获 AI 会话的输出
    func captureOutput(from ai: AIInstance, lines: Int = 100) async throws -> String {
        guard let sessionName = activeSessions[ai.id] else {
            throw SessionError.sessionNotFound(ai.name)
        }
        
        let result = try await runTmux([
            "capture-pane", "-t", sessionName, "-p", "-S", "-\(lines)"
        ])
        
        return result.stdout
    }
    
    /// 等待 AI 响应完成（输出稳定）
    func waitForResponse(from ai: AIInstance, 
                         stableSeconds: Double = 3.0,
                         maxWait: Double = 60.0) async throws -> String {
        let startTime = Date()
        var lastContent = ""
        var lastChangeTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWait {
            let content = try await captureOutput(from: ai, lines: 50)
            
            if content != lastContent {
                lastContent = content
                lastChangeTime = Date()
            } else {
                // 检查是否稳定足够时间
                if Date().timeIntervalSince(lastChangeTime) >= stableSeconds {
                    return extractResponse(from: content)
                }
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        }
        
        throw SessionError.timeout
    }
    
    // MARK: - Response Extraction
    
    /// 从 tmux 输出中提取 AI 响应
    private func extractResponse(from content: String) -> String {
        // 移除 ANSI 转义码
        let cleaned = content.replacingOccurrences(
            of: "\\x1B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~])",
            with: "",
            options: .regularExpression
        )
        
        let lines = cleaned.split(separator: "\n")
        var responseLines: [String] = []
        var inResponse = false
        
        // AI 响应前缀
        let responsePrefixes = ["✦", "•", "+", "*"]
        let boxChars = Set("╭╮╰╯│─┌┐└┘├┤┬┴┼━┃┏┓┗┛┣┫┳┻╋║═╔╗╚╝╠╣╦╩╬")
        
        for line in lines {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            
            // 跳过边框字符
            if trimmed.contains(where: { boxChars.contains($0) }) {
                if inResponse { break }
                continue
            }
            
            // 检测响应开始
            for prefix in responsePrefixes {
                if trimmed.hasPrefix(prefix) {
                    inResponse = true
                    let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        responseLines.append(text)
                    }
                    break
                }
            }
            
            // 收集响应内容
            if inResponse && !trimmed.isEmpty && !responsePrefixes.contains(where: { trimmed.hasPrefix($0) }) {
                // 停止条件
                if trimmed.hasPrefix(">") || trimmed.hasPrefix("$") {
                    break
                }
                responseLines.append(trimmed)
            }
        }
        
        return responseLines.joined(separator: "\n")
    }
    
    // MARK: - Tmux Helper
    
    @discardableResult
    private func runTmux(_ args: [String]) async throws -> CommandResult {
        try await runCommand("/usr/bin/tmux", args: args)
    }
    
    private func runCommand(_ command: String, args: [String]) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: command)
            task.arguments = args
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                
                let result = CommandResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: task.terminationStatus
                )
                
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Supporting Types

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum SessionStatus: String {
    case starting
    case running
    case stopped
    case error
}

enum SessionError: LocalizedError {
    case sessionNotFound(String)
    case timeout
    case commandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let name):
            return "Session not found for \(name)"
        case .timeout:
            return "Waiting for response timed out"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        }
    }
}
