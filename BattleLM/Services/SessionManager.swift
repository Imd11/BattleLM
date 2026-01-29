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
        let workDir = ai.workingDirectory.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : ai.workingDirectory
        
        // 检查会话是否已存在
        let exists = try await sessionExists(sessionName)
        
        if !exists {
            // 创建新会话，设置工作目录
            try await runTmux([
                "new-session", 
                "-d", 
                "-s", sessionName,
                "-c", workDir
            ])
            
            // 设置无限滚动历史缓冲区（0 = 无限制）
            try await runTmux([
                "set-option", "-t", sessionName,
                "history-limit", "0"
            ])
            
            // 等待 shell 完全准备就绪（需要足够时间让 shell 初始化）
            try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5s
        }
        
        // 启动 AI CLI
        print("🚀 Sending CLI command: \(ai.type.cliCommand) to session: \(sessionName)")
        try await sendToSession(sessionName, text: ai.type.cliCommand)
        
        // 记录会话
        await MainActor.run {
            activeSessions[ai.id] = sessionName
            sessionStatus[ai.id] = .running
        }
        
        print("✅ Session started: \(sessionName) for \(ai.name) in \(workDir)")
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
        // 对于包含换行的多行文本，使用 tmux buffer 机制确保完整发送
        // 否则 send-keys 会把 \n 当作 Enter 键，导致 prompt 被拆成多次提交
        
        if text.contains("\n") {
            // 多行文本：写入临时文件 → load-buffer → paste-buffer
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("battlelm_prompt_\(UUID().uuidString).txt")
            
            do {
                try text.write(to: tempFile, atomically: true, encoding: .utf8)
                
                // 加载到 tmux buffer
                try await runTmux(["load-buffer", tempFile.path])
                
                // 粘贴到目标 session
                try await runTmux(["paste-buffer", "-t", session])
                
                // 稍等一下确保文本被粘贴
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                
                // 发送 Enter 键提交
                try await runTmux(["send-keys", "-t", session, "Enter"])
                
                // 清理临时文件
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                try? FileManager.default.removeItem(at: tempFile)
                throw error
            }
        } else {
            // 单行文本：使用原有的 send-keys -l 方式
            try await runTmux(["send-keys", "-t", session, "-l", text])
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            try await runTmux(["send-keys", "-t", session, "Enter"])
        }
    }
    
    // MARK: - Output Capture
    
    /// 捕获 AI 会话的输出
    func captureOutput(from ai: AIInstance, lines: Int = 10000) async throws -> String {
        guard let sessionName = activeSessions[ai.id] else {
            throw SessionError.sessionNotFound(ai.name)
        }
        
        let result = try await runTmux([
            "capture-pane", "-t", sessionName, "-p", "-S", "-\(lines)"
        ])
        
        return result.stdout
    }
    
    /// 流式获取 AI 响应，实时回调更新
    /// - Parameters:
    ///   - ai: AI 实例
    ///   - onUpdate: 每次内容变化时的回调，参数为 (当前内容, 是否正在思考, 是否已完成)
    ///   - stableSeconds: 判定完成的稳定时间（秒）
    ///   - maxWait: 最大等待时间（秒）
    func streamResponse(from ai: AIInstance,
                        onUpdate: @escaping (String, Bool, Bool) -> Void,
                        stableSeconds: Double = 4.0,
                        maxWait: Double = 120.0) async throws {
        let startTime = Date()
        var lastContent = ""
        var lastChangeTime = Date()
        var responseStarted = false
        
        while Date().timeIntervalSince(startTime) < maxWait {
            let rawContent = try await captureOutput(from: ai)
            let response = extractResponse(from: rawContent)
            
            // 检测是否正在思考（Thinking 状态）
            let isThinking = response.lowercased().contains("thinking") || 
                             response.lowercased().contains("envisioning") ||  // Claude 新版
                             response.contains("⁝") ||
                             response.contains("context:")
            
            // 检测响应是否已开始（检查原始输出是否包含响应前缀）
            let hasResponsePrefix = rawContent.contains("✦ ") || 
                                    rawContent.contains("• ") || 
                                    rawContent.contains("+ ")
            
            if hasResponsePrefix && !response.isEmpty {
                responseStarted = true
            }
            
            // 检查内容是否变化
            if response != lastContent {
                lastContent = response
                lastChangeTime = Date()
                
                // 回调更新（未完成）
                await MainActor.run {
                    onUpdate(response, isThinking, false)
                }
            } else if responseStarted && !isThinking {
                // 响应已开始且不是思考状态，检查稳定性
                if Date().timeIntervalSince(lastChangeTime) >= stableSeconds {
                    // 稳定足够时间，判定完成
                    await MainActor.run {
                        onUpdate(response, false, true)
                    }
                    return
                }
            }
            
            // 轮询间隔 300ms
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        
        // 超时，返回当前内容
        await MainActor.run {
            onUpdate(lastContent, false, true)
        }
    }
    
    /// 等待 AI 响应完成（输出稳定）
    func waitForResponse(from ai: AIInstance, 
                         stableSeconds: Double = 3.0,
                         maxWait: Double = 60.0) async throws -> String {
        let startTime = Date()
        var lastContent = ""
        var lastChangeTime = Date()
        
        while Date().timeIntervalSince(startTime) < maxWait {
            let content = try await captureOutput(from: ai, lines: 10000)
            
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
    
    /// 从 tmux 输出中提取最新的 AI 响应
    private func extractResponse(from content: String) -> String {
        // 移除 ANSI 转义码
        let cleaned = content.replacingOccurrences(
            of: "\\x1B(?:[@-Z\\\\-_]|\\[[0-?]*[ -/]*[@-~])",
            with: "",
            options: .regularExpression
        )
        
        // 保留空行（否则 split 默认会丢弃空子序列，导致段落空行消失）
        let lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        
        // AI 响应前缀
        let responsePrefixes = ["✦", "•", "+"]
        let boxChars = Set("╭╮╰╯│─┌┐└┘├┤┬┴┼━┃┏┓┗┛┣┫┳┻╋║═╔╗╚╝╠╣╦╩╬")
        
        // 第一步：从后往前找最后一个用户输入行（以 > 开头或包含 yang✦）
        var lastUserInputIndex: Int? = nil
        
        for i in stride(from: lines.count - 1, through: 0, by: -1) {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            
            // 跳过空行和终端提示（注意：实际可能有多余空格）
            if trimmed.isEmpty || trimmed.contains("Type your message") {
                continue
            }
            
            // 找到用户输入行
            if trimmed.hasPrefix(">") || 
               (trimmed.contains("✦") && !trimmed.hasPrefix("✦")) {  // yang✦ 格式但不是 ✦ 响应
                lastUserInputIndex = i
                break
            }
        }
        
        // 如果没找到用户输入，从开头开始
        let searchStartIndex = (lastUserInputIndex ?? -1) + 1
        
        // 第二步：从用户输入之后找响应前缀行
        var responseStartIndex: Int? = nil
        
        for i in searchStartIndex..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            
            // 找到以响应前缀开头的行
            for prefix in responsePrefixes {
                if trimmed.hasPrefix(prefix) {
                    responseStartIndex = i
                    break
                }
            }
            
            if responseStartIndex != nil {
                break
            }
        }
        
        guard let startIndex = responseStartIndex else {
            return ""
        }
        
        // 从找到的起始位置收集响应（收集所有行，不仅仅是前缀行）
        var responseLines: [String] = []
        
        // 终端元数据模式（不是 AI 响应内容）
        let terminalMetaPatterns = [
            // Claude
            "Envisioning",          // Claude 思考状态
            "Thinking",             // Claude 思考状态
            "(esc to interrupt)",   // Claude 思考提示
            // Gemini
            "Using:",           // 半角冒号
            "Using：",          // 全角冒号
            "Ask Gemini",
            ".md file",
            // Codex
            "context left",
            "for shortcuts",
            "Type your message",
            "Explain this codebase",
            "Summarize recent commits",
            "% context",
            // Kimi
            "Welcome to Kimi",
            "Send /help",
            "upgrade kimi-cli",
            "context:",         // Kimi 底部状态如 context: 3.0%
            "New version available"
        ]
        
        for i in startIndex..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            
            // 停止条件：遇到边框字符
            if trimmed.contains(where: { boxChars.contains($0) }) {
                break
            }
            
            // 停止条件：遇到新的用户提示符或 Codex 提示（以 > 开头）
            if trimmed.hasPrefix(">") {
                print("🔍 Found > prefix line: \(trimmed.prefix(50))")
                break
            }
            
            // 停止条件：遇到终端元数据
            if terminalMetaPatterns.contains(where: { trimmed.contains($0) }) {
                break
            }
            
            // 保留空行以维持段落格式
            if trimmed.isEmpty {
                responseLines.append("")
                continue
            }
            
            // 移除响应前缀符号（如果有的话）
            var line = trimmed
            for prefix in responsePrefixes {
                if line.hasPrefix(prefix) {
                    line = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            
            if !line.isEmpty {
                responseLines.append(line)
            }
        }
        
        return responseLines.joined(separator: "\n")
    }
    
    // MARK: - Tmux Helper
    
    /// BattleLM 使用独立的 tmux server socket，避免影响用户自己的 tmux
    private let tmuxSocket = "battlelm"
    
    @discardableResult
    private func runTmux(_ args: [String]) async throws -> CommandResult {
        // 使用独立 socket (-L battlelm) 隔离用户的 tmux 配置
        let tmuxCommand = (["/opt/homebrew/bin/tmux", "-L", tmuxSocket] + args).joined(separator: " ")
        return try await runShellCommand(tmuxCommand)
    }
    
    private func runShellCommand(_ command: String) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe
            
            // 设置环境变量确保能找到 homebrew
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            task.environment = environment
            
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
