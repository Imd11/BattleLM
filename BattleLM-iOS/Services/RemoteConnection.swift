import Foundation
import Combine
import BattleLMShared
import CFNetwork

#if canImport(UIKit)
import UIKit
#endif

/// iOS 远程连接管理
@MainActor
class RemoteConnection: ObservableObject {
    @Published var state: ConnectionState = .disconnected
    /// Once connected, keep UI stable during transient reconnects.
    @Published private(set) var hasEverConnected: Bool = false
    @Published private(set) var messagesByAI: [UUID: [MessageDTO]] = [:]
    /// 1:1 Chat: show a "thinking" indicator after sending until we receive a non-user message.
    @Published private(set) var pendingAIResponses: Set<UUID> = []
    @Published var aiList: [AIInfoDTO] = []
    @Published var groupChats: [GroupChatDTO] = []
    @Published var groupChatErrorMessage: String?
    @Published var pairedDevices: [PairedDevice] = []
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var currentEndpoint: String?
    private var hasPairingCode: Bool = false
    private var pairingCode: String?
    private var lastSeq = 0
    private var authTimeoutTask: Task<Void, Never>?
    private var lastConnectionUsedProxyBypass = false
    private var pairingFallbackEndpoint: String?
    private var pairingUsedFallback = false
    private var reconnectLocalEndpoint: String?  // Local endpoint for reconnection fallback
    private var autoReconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private var lastConnectedDevice: PairedDevice?
    private var keepAliveTask: Task<Void, Never>?
    private let keepAliveIntervalSeconds: Double = 25
    
    init() {
        loadPairedDevices()
    }
    
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case authenticating
        case connected
        case error(String)
    }
    
    struct PairedDevice: Codable, Identifiable {
        let id: String
        let name: String
        let endpoint: String          // Primary: wss tunnel
        let endpointLocal: String?    // Fallback: local ws://192.168.x.x
        let lastConnected: Date
    }
    
    // MARK: - Pairing Storage
    
    private let pairedDevicesKey = "pairedDevices"
    
    private func loadPairedDevices() {
        guard let data = UserDefaults.standard.data(forKey: pairedDevicesKey),
              let devices = try? JSONDecoder().decode([PairedDevice].self, from: data) else {
            return
        }
        // Sanitize legacy data:
        // - historically `id` could be a deviceId (not unique across endpoints) which breaks `ForEach`.
        // - we now use `endpoint` as the unique identifier.
        var seenEndpoints: Set<String> = []
        let normalized = devices.compactMap { device -> PairedDevice? in
            guard !device.endpoint.isEmpty else { return nil }
            guard !seenEndpoints.contains(device.endpoint) else { return nil }
            seenEndpoints.insert(device.endpoint)
            return PairedDevice(
                id: device.endpoint,
                name: device.name,
                endpoint: device.endpoint,
                endpointLocal: device.endpointLocal,
                lastConnected: device.lastConnected
            )
        }
        pairedDevices = normalized

        if let normalizedData = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(normalizedData, forKey: pairedDevicesKey)
        }
    }
    
    private func savePairedDevice(_ device: PairedDevice) {
        var devices = pairedDevices
        // Deduplicate by endpoint (same Mac = same endpoint), not by id
        devices.removeAll { $0.endpoint == device.endpoint }
        devices.insert(device, at: 0)
        pairedDevices = devices
        
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: pairedDevicesKey)
        }
    }
    
    /// Remove a paired device from the list
    func removePairedDevice(_ device: PairedDevice) {
        pairedDevices.removeAll { $0.endpoint == device.endpoint }
        
        if let data = try? JSONEncoder().encode(pairedDevices) {
            UserDefaults.standard.set(data, forKey: pairedDevicesKey)
        }
    }
    
    // MARK: - Connection
    
    /// 扫码连接（首次配对）
    func connectWithPairing(_ payload: PairingQRPayload) async throws {
        currentEndpoint = payload.endpointWss
        pairingCode = payload.pairingCode
        hasPairingCode = true
        pairingFallbackEndpoint = payload.endpointWsLocal
        pairingUsedFallback = false
        do {
            try await connectWithAutoProxyBypass(to: payload.endpointWss)
        } catch {
            handleTransportFailure(error)
            throw error
        }
    }
    
    /// Reconnect to paired device (try local first, then wss)
    func reconnect(to device: PairedDevice) async throws {
        hasPairingCode = false
        pairingCode = nil
        reconnectLocalEndpoint = device.endpointLocal
        
        // Try local endpoint first (more stable than tunnel)
        if let localEndpoint = device.endpointLocal {
            currentEndpoint = localEndpoint
            do {
                try await connect(to: localEndpoint, bypassSystemProxy: false)
                return
            } catch {
                // Local failed, try wss tunnel
                disconnect()
            }
        }
        
        // Fall back to wss tunnel
        currentEndpoint = device.endpoint
        try await connectWithAutoProxyBypass(to: device.endpoint)
    }
    
    private func connectWithAutoProxyBypass(to endpoint: String) async throws {
        do {
            lastConnectionUsedProxyBypass = false
            try await connect(to: endpoint, bypassSystemProxy: false)
        } catch {
            // 尽量减少用户操作：若 TLS 失败且检测到系统代理启用，自动重试一次直连（禁用代理）。
            if isTLSSecureConnectionFailure(error), isSystemProxyEnabled() {
                disconnect()
                lastConnectionUsedProxyBypass = true
                do {
                    try await connect(to: endpoint, bypassSystemProxy: true)
                    return
                } catch {
                    state = .error(presentableError(error))
                    throw error
                }
            }

            state = .error(presentableError(error))
            throw error
        }
    }

    private func connect(to endpoint: String, bypassSystemProxy: Bool) async throws {
        authTimeoutTask?.cancel()
        state = .connecting
        
        guard let url = URL(string: endpoint) else {
            throw AuthError.invalidQRCode
        }
        
        let shouldBypassProxy = bypassSystemProxy || shouldBypassProxyForEndpoint(endpoint)
        session = URLSession(configuration: makeSessionConfiguration(bypassSystemProxy: shouldBypassProxy))
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()
        
        state = .authenticating
        let deviceName = localDeviceDisplayName()
        
        // 根据是否有配对码选择认证方式
        if hasPairingCode, let code = pairingCode {
            // 首次配对：直接发 pairRequest（跳过 authHello → authDenied 往返）
            let request = PairRequest(
                pairingCode: code,
                phonePublicKey: DeviceIdentity.shared.publicKeyBase64,
                phoneName: deviceName
            )
            try await send(request)
        } else {
            // 重连：发 authHello
            let hello = AuthHello(
                phonePublicKey: DeviceIdentity.shared.publicKeyBase64,
                phoneName: deviceName
            )
            try await send(hello)
        }
        
        startReceiving()
        startAuthTimeout()
    }

    private func localDeviceDisplayName() -> String {
        #if canImport(UIKit)
        let rawName = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericNames: Set<String> = ["iPhone", "iPad", "iPod touch", "iPod"]
        if !rawName.isEmpty, !genericNames.contains(rawName) {
            return rawName
        }

        let model = UIDevice.current.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if let identifier = hardwareModelIdentifier() {
            if !model.isEmpty {
                return "\(model) (\(identifier))"
            }
            return identifier
        }

        return model.isEmpty ? "iPhone" : model
        #else
        return "iPhone"
        #endif
    }

    private func hardwareModelIdentifier() -> String? {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return nil }

        let identifier = Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }

        return identifier.isEmpty ? nil : identifier
    }
    
    func disconnect() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        autoReconnectTask?.cancel()
        autoReconnectTask = nil
        stopKeepAlive()
        reconnectAttempts = 0
        pairingFallbackEndpoint = nil
        pairingUsedFallback = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        state = .disconnected
        hasEverConnected = false
        messagesByAI = [:]
        pendingAIResponses = []
        groupChats = []
        groupChatErrorMessage = nil
    }
    
    // MARK: - Receiving
    
    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.reconnectAttempts = 0  // 成功接收，重置重连计数
                    await self?.handleMessage(message)
                    self?.startReceiving()
                case .failure(let error):
                    if self?.state == .connected || self?.state == .authenticating {
                        self?.handleReceiveFailure(error)
                    }
                }
            }
        }
    }
    
    /// 接收失败处理：尝试自动重连
    private func handleReceiveFailure(_ error: Error) {
        print("⚠️ [RemoteConnection] Receive failed: \(error.localizedDescription)")
        
        // 保存当前连接的设备信息用于重连
        if let endpoint = currentEndpoint, let device = pairedDevices.first(where: { $0.endpoint == endpoint }) {
            lastConnectedDevice = device
        }
        
        // 尝试自动重连
        scheduleAutoReconnect()
    }
    
    /// 安排自动重连
    private func scheduleAutoReconnect() {
        autoReconnectTask?.cancel()
        stopKeepAlive()
        
        guard reconnectAttempts < maxReconnectAttempts else {
            // 超过最大重连次数，显示错误
            state = .error("Connection lost. Tap Reconnect to try again.")
            reconnectAttempts = 0
            return
        }
        
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0  // 递增延迟：2s, 4s, 6s
        
        state = .connecting
        print("🔄 [RemoteConnection] Auto-reconnect attempt \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s")
        
        autoReconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            // 优先尝试重连到保存的设备
            if let device = lastConnectedDevice {
                do {
                    try await reconnect(to: device)
                    reconnectAttempts = 0
                    print("✅ [RemoteConnection] Auto-reconnect succeeded")
                } catch {
                    print("❌ [RemoteConnection] Auto-reconnect failed: \(error)")
                    scheduleAutoReconnect()  // 继续尝试
                }
            } else {
                state = .error("No device to reconnect to")
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "authChallenge":
            await handleAuthChallenge(data)
            
        case "authOK":
            handleAuthOK()
            
        case "authDenied":
            await handleAuthDenied(data)
            
        case "pairResponse":
            await handlePairResponse(data)
            
        case "pairComplete":
            handlePairComplete(data)
            
        case "aiResponse":
            handleAIResponse(data)
            
        case "aiStatus":
            handleAIStatus(data)

        case "groupChatsSnapshot":
            handleGroupChatsSnapshot(data)

        case "groupChatError":
            handleGroupChatError(data)
            
        default:
            break
        }
    }
    
    // MARK: - Auth Handlers
    
    private func handleAuthChallenge(_ data: Data) async {
        guard let challenge = try? JSONDecoder().decode(AuthChallenge.self, from: data),
              let challengeData = Data(base64Encoded: challenge.challenge) else {
            return
        }
        
        do {
            let signature = try DeviceIdentity.shared.sign(challengeData)
            let response = AuthResponse(
                phonePublicKey: DeviceIdentity.shared.publicKeyBase64,
                signature: signature.base64EncodedString()
            )
            try await send(response)
        } catch {
            state = .error("Signing failed: \(error.localizedDescription)")
        }
    }
    
    private func handleAuthOK() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        let localEndpoint = reconnectLocalEndpoint ?? pairingFallbackEndpoint
        pairingFallbackEndpoint = nil
        pairingUsedFallback = false
        reconnectLocalEndpoint = nil
        state = .connected
        hasEverConnected = true
        startKeepAliveIfNeeded()
        
        // Save paired device with both endpoints
        if let endpoint = currentEndpoint {
            let device = PairedDevice(
                id: endpoint,
                name: "Mac",
                endpoint: endpoint,
                endpointLocal: localEndpoint,
                lastConnected: Date()
            )
            savePairedDevice(device)
        }
    }
    
    private func handleAuthDenied(_ data: Data) async {
        guard let denied = try? JSONDecoder().decode(AuthDenied.self, from: data) else {
            state = .error(AuthError.notAuthorized.localizedDescription)
            return
        }

        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        pairingFallbackEndpoint = nil
        pairingUsedFallback = false

        if hasPairingCode {
            state = .error("Pairing failed: \(denied.error)")
        } else {
            state = .error(AuthError.notAuthorized.localizedDescription)
        }
    }
    
    private func handlePairResponse(_ data: Data) async {
        guard let response = try? JSONDecoder().decode(PairResponse.self, from: data) else { return }
        
        if response.success, let challengeBase64 = response.challenge,
           let challengeData = Data(base64Encoded: challengeBase64) {
            do {
                let signature = try DeviceIdentity.shared.sign(challengeData)
                let resp = ChallengeResponse(signature: signature.base64EncodedString())
                try await send(resp)
            } catch {
                authTimeoutTask?.cancel()
                authTimeoutTask = nil
                pairingFallbackEndpoint = nil
                pairingUsedFallback = false
                state = .error("Signing failed")
            }
        } else {
            authTimeoutTask?.cancel()
            authTimeoutTask = nil
            pairingFallbackEndpoint = nil
            pairingUsedFallback = false
            state = .error(response.error ?? "Pairing failed")
        }
    }
    
    private func handlePairComplete(_ data: Data) {
        guard let complete = try? JSONDecoder().decode(PairComplete.self, from: data) else { return }
        
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        let localEndpoint = pairingFallbackEndpoint  // Save before clearing
        pairingFallbackEndpoint = nil
        pairingUsedFallback = false
        state = .connected
        hasEverConnected = true
        startKeepAliveIfNeeded()
        
        // Save paired device with both endpoints
        if let endpoint = currentEndpoint {
            let device = PairedDevice(
                id: endpoint,
                name: complete.macDeviceName,
                endpoint: endpoint,
                endpointLocal: localEndpoint,
                lastConnected: Date()
            )
            savePairedDevice(device)
        }
    }
    
    // MARK: - Business Handlers
    
    private func handleAIResponse(_ data: Data) {
        // 解析 RemoteEvent
        guard let event = try? JSONDecoder().decode(RemoteEvent.self, from: data),
              let payloadData = event.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AIResponsePayload.self, from: payloadData) else {
            return
        }
        
        lastSeq = event.seq
        var list = messagesByAI[payload.aiId] ?? []

        if payload.isStreaming,
           let last = list.last,
           last.senderType == payload.message.senderType,
           last.senderId == payload.message.senderId {
            let updated = MessageDTO(
                id: last.id,
                senderId: last.senderId,
                senderType: last.senderType,
                senderName: last.senderName,
                content: payload.message.content,
                timestamp: payload.message.timestamp
            )
            list[list.count - 1] = updated
        } else {
            if let last = list.last,
               last.senderType == payload.message.senderType,
               last.senderId == payload.message.senderId,
               last.content == payload.message.content {
                messagesByAI[payload.aiId] = list
                return
            }
            list.append(payload.message)
        }

        messagesByAI[payload.aiId] = list

        // Clear "thinking" indicator once we receive a non-user message
        // (assistant response or system error) for this AI.
        if payload.message.senderType != "user" {
            pendingAIResponses.remove(payload.aiId)
        }
    }
    
    private func handleAIStatus(_ data: Data) {
        guard let event = try? JSONDecoder().decode(RemoteEvent.self, from: data),
              let payloadData = event.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(AIStatusPayload.self, from: payloadData) else {
            return
        }
        
        lastSeq = event.seq
        
        // 更新 AI 列表
        let info = AIInfoDTO(
            id: payload.aiId,
            name: payload.name,
            provider: payload.provider ?? "",
            isRunning: payload.isRunning,
            workingDirectory: payload.workingDirectory
        )

        if let index = aiList.firstIndex(where: { $0.id == payload.aiId }) {
            aiList[index] = info
        } else {
            aiList.append(info)
        }
    }

    private func handleGroupChatsSnapshot(_ data: Data) {
        guard let event = try? JSONDecoder().decode(RemoteEvent.self, from: data),
              let payloadData = event.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(GroupChatsSnapshotPayload.self, from: payloadData) else {
            return
        }

        lastSeq = event.seq
        groupChats = payload.chats.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func handleGroupChatError(_ data: Data) {
        guard let event = try? JSONDecoder().decode(RemoteEvent.self, from: data),
              let payloadData = event.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(GroupChatErrorPayload.self, from: payloadData) else {
            return
        }

        lastSeq = event.seq
        groupChatErrorMessage = payload.error
    }
    
    // MARK: - Sending
    
    private func send<T: Encodable>(_ message: T) async throws {
        let data = try JSONEncoder().encode(message)
        try await webSocket?.send(.data(data))
    }
    
    private func startAuthTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
            await MainActor.run {
                guard let self else { return }
                if self.state == .authenticating {
                    self.handleTransportFailure(URLError(.timedOut))
                }
            }
        }
    }
    
    private func presentableError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut {
            var lines: [String] = []
            lines.append("Connection timed out.")
            if pairingUsedFallback {
                lines.append("LAN direct connection also timed out. Please ensure iPhone and Mac are on the same Wi‑Fi and the Mac app is running.")
            } else if let hint = pairingFallbackEndpoint {
                lines.append("Will try LAN direct connection: \(hint)")
            } else {
                lines.append("If you are using a tunnel (wss), try scanning the QR code again to get a fresh endpoint.")
            }
            if let proxyHint = currentSystemProxyHint() {
                lines.append(proxyHint)
            }
            lines.append("If you have VPN / Wi‑Fi proxy / packet capture enabled, try disabling and retry.")
            return lines.joined(separator: "\n")
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorNotConnectedToInternet {
            var lines: [String] = []
            lines.append("Network unavailable.")
            lines.append("Please ensure iPhone is connected to Wi-Fi and BattleLM has Local Network access.")
            if pairingUsedFallback, let hint = pairingFallbackEndpoint {
                lines.append("LAN direct address: \(hint)")
            }
            return lines.joined(separator: "\n")
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCannotFindHost {
            var lines: [String] = []
            lines.append("Cannot find server (DNS/network unreachable).")
            if pairingUsedFallback {
                lines.append("LAN direct connection also failed. Please ensure iPhone and Mac are on the same Wi-Fi.")
            } else if let hint = pairingFallbackEndpoint {
                lines.append("Will try LAN direct connection: \(hint)")
            }
            return lines.joined(separator: "\n")
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCannotConnectToHost {
            var lines: [String] = []
            lines.append("Cannot connect to server.")
            if pairingUsedFallback {
                lines.append("LAN direct connection also failed. Please ensure iPhone and Mac are on the same Wi‑Fi and the Mac app is running.")
            } else if let hint = pairingFallbackEndpoint {
                lines.append("Will try LAN direct connection: \(hint)")
            } else {
                lines.append("If you are using a tunnel (wss), try scanning the QR code again to get a fresh endpoint.")
            }
            if let proxyHint = currentSystemProxyHint() {
                lines.append(proxyHint)
            }
            return lines.joined(separator: "\n")
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorSecureConnectionFailed {
            var lines: [String] = []
            lines.append("TLS handshake failed, cannot establish secure connection.")
            if let proxyHint = currentSystemProxyHint() {
                lines.append(proxyHint)
            }
            if lastConnectionUsedProxyBypass {
                lines.append("Tried bypassing system proxy, but still failed.")
            }
            if pairingUsedFallback {
                lines.append("LAN direct connection also failed. Please ensure iPhone and Mac are on the same Wi-Fi.")
            } else if let hint = pairingFallbackEndpoint {
                lines.append("Will try LAN direct connection: \(hint)")
            }
            lines.append("Please check if iPhone has Wi-Fi proxy / VPN / packet capture tools enabled, and try again after disabling.")
            return lines.joined(separator: "\n")
        }
        // -1011: Bad server response (WebSocket handshake failed, typically tunnel expired)
        if nsError.domain == NSURLErrorDomain, nsError.code == -1011 {
            var lines: [String] = []
            lines.append("Server connection failed (tunnel may have expired).")
            if pairingUsedFallback {
                lines.append("LAN direct connection also failed. Please ensure iPhone and Mac are on the same Wi-Fi and the Mac app is running.")
            } else if let hint = pairingFallbackEndpoint {
                lines.append("Will try LAN direct connection: \(hint)")
            } else {
                lines.append("Please try scanning the QR code again to get a fresh connection.")
            }
            return lines.joined(separator: "\n")
        }
        return nsError.localizedDescription
    }

    private func handleTransportFailure(_ error: Error) {
        if hasPairingCode,
           !pairingUsedFallback,
           let fallback = pairingFallbackEndpoint,
           isTransportErrorForFallback(error) {
            pairingUsedFallback = true
            Task {
                resetTransport()
                currentEndpoint = fallback
                do {
                    try await connect(to: fallback, bypassSystemProxy: false)
                } catch {
                    state = .error(presentableError(error))
                }
            }
            return
        }

        state = .error(presentableError(error))
    }

    private func resetTransport() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        stopKeepAlive()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        state = .authenticating
    }

    // MARK: - Keep Alive

    private func startKeepAliveIfNeeded() {
        guard keepAliveTask == nil else { return }
        keepAliveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(keepAliveIntervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.sendKeepAlivePing()
            }
        }
    }

    private func stopKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
    }

    private func sendKeepAlivePing() async {
        guard state == .connected, webSocket != nil else { return }
        webSocket?.sendPing { [weak self] error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    if self.state == .connected || self.state == .authenticating {
                        self.handleReceiveFailure(error)
                    }
                }
            }
        }
    }

    private func isTransportErrorForFallback(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorSecureConnectionFailed,
             -1011:
            return true
        default:
            return false
        }
    }

    private func isTLSSecureConnectionFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorSecureConnectionFailed
    }

    private func shouldBypassProxyForEndpoint(_ endpoint: String) -> Bool {
        guard let url = URL(string: endpoint),
              let host = url.host?.lowercased() else {
            return false
        }

        if url.scheme == "ws" {
            if host == "localhost" || host == "127.0.0.1" {
                return true
            }

            let parts = host.split(separator: ".")
            if parts.count == 4,
               let first = Int(parts[0]),
               let second = Int(parts[1]) {
                if first == 10 || first == 127 {
                    return true
                }
                if first == 192 && second == 168 {
                    return true
                }
                if first == 172 && (16...31).contains(second) {
                    return true
                }
            }
        }

        return false
    }

    private func makeSessionConfiguration(bypassSystemProxy: Bool) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        if bypassSystemProxy {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: 0,
                "HTTPSEnable": 0,
                "SOCKSEnable": 0,
                kCFNetworkProxiesProxyAutoConfigEnable as String: 0
            ]
        }
        return config
    }

    private func currentSystemProxyHint() -> String? {
        guard let cfSettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = cfSettings as? [String: Any] else {
            return nil
        }
        let httpEnabled = (settings[kCFNetworkProxiesHTTPEnable as String] as? Int) ?? 0
        guard httpEnabled != 0 else { return nil }
        
        let httpProxy = settings[kCFNetworkProxiesHTTPProxy as String] as? String
        let httpPort = settings[kCFNetworkProxiesHTTPPort as String] as? Int
        
        guard let httpProxy, let httpPort else { return "System proxy detected." }
        return "System proxy detected: \(httpProxy):\(httpPort)"
    }

    private func isSystemProxyEnabled() -> Bool {
        guard let cfSettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = cfSettings as? [String: Any] else {
            return false
        }

        let httpEnabled = (settings[kCFNetworkProxiesHTTPEnable as String] as? Int) ?? 0
        let pacEnabled = (settings[kCFNetworkProxiesProxyAutoConfigEnable as String] as? Int) ?? 0

        return httpEnabled != 0 || pacEnabled != 0
    }
    
    func sendMessage(_ text: String, to aiId: UUID) async throws {
        guard state == .connected else { return }
        pendingAIResponses.insert(aiId)
        let payload = SendMessagePayload(aiId: aiId, text: text)
        do {
            try await send(payload)
        } catch {
            pendingAIResponses.remove(aiId)
            throw error
        }
    }
    
    func createGroupChat(name: String, memberIds: [UUID]) async throws {
        guard state == .connected else { return }
        let payload = CreateGroupChatPayload(name: name, memberIds: memberIds)
        try await send(payload)
    }

    func sendGroupMessage(_ text: String, to chatId: UUID) async throws {
        guard state == .connected else { return }
        let payload = SendGroupMessagePayload(chatId: chatId, text: text)
        try await send(payload)
    }

    func messages(for aiId: UUID) -> [MessageDTO] {
        messagesByAI[aiId] ?? []
    }

    func isAwaitingResponse(for aiId: UUID) -> Bool {
        pendingAIResponses.contains(aiId)
    }

    func groupChat(for chatId: UUID) -> GroupChatDTO? {
        groupChats.first { $0.id == chatId }
    }
}
