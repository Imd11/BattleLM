import Foundation
import Combine

/// Headless session coordinator.
///
/// The old tmux-backed terminal path has been removed. This manager now keeps
/// lightweight session state for the UI and remote sync layer only.
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    private let headlessToken = "__headless__"

    /// Active sessions keyed by AI id.
    @Published var activeSessions: [UUID: String] = [:]

    /// Session status for UI badges and remote sync.
    @Published var sessionStatus: [UUID: SessionStatus] = [:]

    private init() {}

    func broadcastToRemote(aiId: UUID, message: MessageDTO, isStreaming: Bool) {
        Task { @MainActor in
            let payload = AIResponsePayload(aiId: aiId, message: message, isStreaming: isStreaming)
            RemoteHostServer.shared.broadcast(type: "aiResponse", payload: payload)
        }
    }

    // MARK: - Session Lifecycle

    func startSession(for ai: AIInstance) async throws {
        await MainActor.run {
            sessionStatus[ai.id] = .starting
        }
        await registerHeadlessSession(for: ai)
    }

    func stopSession(for ai: AIInstance) async throws {
        await unregisterHeadlessSession(for: ai)
    }

    func registerHeadlessSession(for ai: AIInstance) async {
        await MainActor.run {
            activeSessions[ai.id] = headlessToken
            sessionStatus[ai.id] = .running
        }
    }

    func unregisterHeadlessSession(for ai: AIInstance) async {
        await MainActor.run {
            activeSessions.removeValue(forKey: ai.id)
            sessionStatus[ai.id] = .stopped
        }
    }

    func sendEscapeToSessions(for aiIds: Set<UUID>? = nil) async {
        // No tmux layer remains. Headless processes are cancelled directly by AIStreamEngine.
    }

    func clearPendingMessages(for aiIds: Set<UUID>) async {
        // No legacy tmux pending state remains.
    }
}

enum SessionStatus: String {
    case starting
    case running
    case stopped
    case error
}

enum SessionError: LocalizedError {
    case commandFailed(String)
    case noActiveSession
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .noActiveSession:
            return "No active session"
        case .unsupported(let message):
            return message
        }
    }
}
