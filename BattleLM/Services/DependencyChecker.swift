// BattleLM/Services/DependencyChecker.swift
import Foundation

/// 依赖检查器 - 检查运行所需的依赖项
struct DependencyChecker {
    
    // MARK: - Dependency Definitions
    
    struct Dependency: Hashable {
        let name: String
        let command: String
        let installHint: String
    }
    
    /// 必需的依赖
    static let required: [Dependency] = [
        Dependency(
            name: "tmux",
            command: "tmux",
            installHint: "brew install tmux"
        )
    ]
    
    /// AI CLI 依赖
    static let aiCLIs: [AIType: Dependency] = [
        .claude: Dependency(
            name: "Claude CLI",
            command: "claude",
            installHint: "npm install -g @anthropic-ai/claude-code"
        ),
        .gemini: Dependency(
            name: "Gemini CLI",
            command: "gemini",
            installHint: "npm install -g @google/gemini-cli"
        ),
        .codex: Dependency(
            name: "Codex CLI",
            command: "codex",
            installHint: "npm install -g @openai/codex"
        ),
        .qwen: Dependency(
            name: "Qwen CLI",
            command: "qwen",
            installHint: "pip install qwen-cli"
        ),
        .kimi: Dependency(
            name: "Kimi CLI",
            command: "kimi",
            installHint: "uv tool install kimi-cli"
        )
    ]
    
    // MARK: - Check Methods
    
    /// 检查所有必需依赖
    static func checkRequired() async -> [Dependency: Bool] {
        var results: [Dependency: Bool] = [:]
        
        for dep in required {
            results[dep] = await check(dep)
        }
        
        return results
    }
    
    /// 检查特定 AI 的 CLI 是否可用
    static func checkAI(_ type: AIType) async -> Bool {
        guard let dep = aiCLIs[type] else { return false }
        return await check(dep)
    }
    
    /// 检查单个依赖
    static func check(_ dep: Dependency) async -> Bool {
        do {
            let result = try await runWhich(dep.command)
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    /// 获取缺失的依赖
    static func getMissingDependencies() async -> [Dependency] {
        var missing: [Dependency] = []
        
        let results = await checkRequired()
        for (dep, available) in results {
            if !available {
                missing.append(dep)
            }
        }
        
        return missing
    }
    
    /// 获取可用的 AI 类型
    static func getAvailableAITypes() async -> [AIType] {
        var available: [AIType] = []
        
        for type in AIType.allCases {
            if await checkAI(type) {
                available.append(type)
            }
        }
        
        return available
    }
    
    // MARK: - Private Helpers
    
    private static func runWhich(_ command: String) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            task.arguments = [command]
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = CommandResult(
                    stdout: String(data: data, encoding: .utf8) ?? "",
                    stderr: "",
                    exitCode: task.terminationStatus
                )
                
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Dependency Check Result

struct DependencyCheckResult {
    let requiredMissing: [DependencyChecker.Dependency]
    let availableAIs: [AIType]
    
    var isReady: Bool {
        requiredMissing.isEmpty && !availableAIs.isEmpty
    }
}
