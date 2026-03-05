import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';

import '../services/storage_service.dart';
import 'device_identity.dart';
import 'remote_protocol.dart';

enum ConnectionState {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

class RemoteConnection extends ChangeNotifier {
  final StorageService storage;
  final DeviceIdentity identity;

  RemoteConnection({required this.storage, required this.identity}) {
    _loadPairedDevices();
  }

  ConnectionState state = ConnectionState.disconnected;
  String? errorMessage;

  bool hasEverConnected = false;

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _authTimeout;

  String? _currentEndpoint;
  String? _pairingCode;
  bool _hasPairingCode = false;
  String? _pairingFallbackEndpoint;
  bool _pairingUsedFallback = false;
  String? _reconnectLocalEndpoint;

  int lastSeq = 0;

  final Map<String, List<MessageDTO>> messagesByAI = {};
  final Set<String> pendingAIResponses = {};
  TerminalPromptPayload? currentPrompt;

  final List<AIInfoDTO> aiList = [];
  final List<GroupChatDTO> groupChats = [];
  List<PairedDevice> pairedDevices = [];

  // MARK: - Pairing storage

  Future<void> _loadPairedDevices() async {
    final devices = await storage.loadPairedDevices();
    final seen = <String>{};
    pairedDevices = devices.where((d) {
      if (d.endpoint.isEmpty) return false;
      if (seen.contains(d.endpoint)) return false;
      seen.add(d.endpoint);
      return true;
    }).map((d) {
      return PairedDevice(
        id: d.endpoint,
        name: d.name,
        endpoint: d.endpoint,
        endpointLocal: d.endpointLocal,
        lastConnected: d.lastConnected,
      );
    }).toList();
    await storage.savePairedDevices(pairedDevices);
    notifyListeners();
  }

  Future<void> removePairedDevice(PairedDevice device) async {
    pairedDevices.removeWhere((d) => d.endpoint == device.endpoint);
    await storage.savePairedDevices(pairedDevices);
    notifyListeners();
  }

  Future<void> _savePairedDevice(PairedDevice device) async {
    pairedDevices.removeWhere((d) => d.endpoint == device.endpoint);
    pairedDevices.insert(0, device);
    await storage.savePairedDevices(pairedDevices);
    notifyListeners();
  }

  // MARK: - Connection

  Future<void> connectWithPairing(PairingQRPayload payload) async {
    _currentEndpoint = payload.endpointWss;
    _pairingCode = payload.pairingCode;
    _hasPairingCode = true;
    _pairingFallbackEndpoint = payload.endpointWsLocal;
    _pairingUsedFallback = false;

    try {
      await _connect(payload.endpointWss);
    } catch (e) {
      final recovered = await _handleTransportFailure(e);
      if (!recovered) rethrow;
    }
  }

  Future<void> reconnectTo(PairedDevice device) async {
    _hasPairingCode = false;
    _pairingCode = null;
    _reconnectLocalEndpoint = device.endpointLocal;

    if (device.endpointLocal != null && device.endpointLocal!.isNotEmpty) {
      try {
        _currentEndpoint = device.endpointLocal!;
        await _connect(device.endpointLocal!);
        return;
      } catch (_) {
        await disconnect();
      }
    }

    _currentEndpoint = device.endpoint;
    await _connect(device.endpoint);
  }

  Future<void> disconnect() async {
    _authTimeout?.cancel();
    _authTimeout = null;

    await _sub?.cancel();
    _sub = null;

    await _channel?.sink.close();
    _channel = null;

    state = ConnectionState.disconnected;
    errorMessage = null;
    hasEverConnected = false;

    messagesByAI.clear();
    pendingAIResponses.clear();
    currentPrompt = null;
    aiList.clear();
    groupChats.clear();

    notifyListeners();
  }

  Future<void> _connect(String endpoint) async {
    await disconnect();

    _updateState(ConnectionState.connecting);
    _channel = IOWebSocketChannel.connect(
      Uri.parse(endpoint),
      pingInterval: const Duration(seconds: 25),
    );

    _sub = _channel!.stream.listen(
      _handleInbound,
      onError: (e) => _handleReceiveFailure(e),
      onDone: () => _handleReceiveFailure(const SocketException('WebSocket closed')),
      cancelOnError: true,
    );

    _updateState(ConnectionState.authenticating);

    final phoneName = _localDeviceDisplayName();
    final phonePublicKey = identity.publicKeyBase64;

    if (_hasPairingCode && (_pairingCode ?? '').isNotEmpty) {
      final msg = pairRequest(
        pairingCode: _pairingCode!,
        phonePublicKey: phonePublicKey,
        phoneName: phoneName,
      );
      _sendJson(msg);
    } else {
      final msg = authHello(
        phonePublicKey: phonePublicKey,
        phoneName: phoneName,
      );
      _sendJson(msg);
    }

    _startAuthTimeout();
  }

  void _startAuthTimeout() {
    _authTimeout?.cancel();
    _authTimeout = Timer(const Duration(seconds: 15), () {
      if (state == ConnectionState.authenticating) {
        _handleTransportFailure(const TimeoutException('auth timeout'));
      }
    });
  }

  Future<bool> _handleTransportFailure(Object error) async {
    if (_hasPairingCode &&
        !_pairingUsedFallback &&
        (_pairingFallbackEndpoint ?? '').isNotEmpty &&
        _isTransportErrorForFallback(error)) {
      _pairingUsedFallback = true;
      final fallback = _pairingFallbackEndpoint!;
      try {
        _currentEndpoint = fallback;
        await _connect(fallback);
        return true;
      } catch (_) {
        // continue to error below
      }
    }

    _updateError(_presentableError(error));
    return false;
  }

  bool _isTransportErrorForFallback(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    return true;
  }

  String _presentableError(Object error) {
    final s = error.toString();
    final lines = <String>[];

    if (s.contains('TimeoutException') || s.contains('timed out') || s.contains('auth timeout')) {
      lines.add('Connection timed out.');
      if (_pairingUsedFallback) {
        lines.add('LAN direct connection also timed out. Please ensure devices are on the same Wi‑Fi and the Mac app is running.');
      } else if ((_pairingFallbackEndpoint ?? '').isNotEmpty) {
        lines.add('Will try LAN direct connection: $_pairingFallbackEndpoint');
      } else {
        lines.add('If you are using a tunnel (wss), refresh the QR code and scan again.');
      }
      return lines.join('\n');
    }

    lines.add(s);
    return lines.join('\n');
  }

  void _handleReceiveFailure(Object error) {
    if (state == ConnectionState.connected || state == ConnectionState.authenticating) {
      // For now, surface the error. Auto-reconnect can be added like iOS later.
      _updateError(_presentableError(error));
    }
  }

  // MARK: - Inbound handling

  void _handleInbound(dynamic data) async {
    final String text;
    if (data is String) {
      text = data;
    } else if (data is List<int>) {
      text = utf8.decode(data);
    } else if (data is Uint8List) {
      text = utf8.decode(data);
    } else {
      return;
    }

    final obj = jsonDecode(text);
    if (obj is! Map<String, dynamic>) return;

    // RemoteEvent (Mac -> clients) has seq + payloadJSON.
    if (obj.containsKey('seq') && obj.containsKey('payloadJSON') && obj.containsKey('type')) {
      final event = RemoteEvent.fromJson(obj);
      lastSeq = event.seq;
      final payload = jsonDecode(event.payloadJSON);
      if (payload is! Map<String, dynamic>) return;
      _handleRemoteEvent(event.type, payload);
      return;
    }

    final type = obj['type'];
    if (type is! String) return;

    switch (type) {
      case 'authChallenge':
        await _handleAuthChallenge(obj);
        break;
      case 'authOK':
        _authTimeout?.cancel();
        _updateState(ConnectionState.connected);
        hasEverConnected = true;
        notifyListeners();
        _sendJson({'type': 'syncRequest', 'lastSeq': lastSeq});
        break;
      case 'authDenied':
        _authTimeout?.cancel();
        _updateError('Device not authorized. Please scan again to pair.');
        break;
      case 'pairResponse':
        await _handlePairResponse(obj);
        break;
      case 'pairComplete':
        _authTimeout?.cancel();
        _updateState(ConnectionState.connected);
        hasEverConnected = true;
        notifyListeners();
        await _handlePairComplete(obj);
        break;
      default:
        break;
    }
  }

  Future<void> _handleAuthChallenge(Map<String, dynamic> obj) async {
    final challengeB64 = obj['challenge'] as String?;
    if (challengeB64 == null) return;
    final challenge = base64Decode(challengeB64);
    final signature = await identity.signBase64(Uint8List.fromList(challenge));
    _sendJson(authResponse(phonePublicKey: identity.publicKeyBase64, signatureBase64: signature));
  }

  Future<void> _handlePairResponse(Map<String, dynamic> obj) async {
    final success = obj['success'] == true;
    if (!success) {
      final err = obj['error'] as String? ?? 'Pairing failed';
      _updateError(err);
      return;
    }
    final challengeB64 = obj['challenge'] as String?;
    if (challengeB64 == null) {
      _updateError('Pairing failed: missing challenge');
      return;
    }
    final challenge = base64Decode(challengeB64);
    final signature = await identity.signBase64(Uint8List.fromList(challenge));
    _sendJson(challengeResponse(signatureBase64: signature));
  }

  Future<void> _handlePairComplete(Map<String, dynamic> obj) async {
    final endpoint = _currentEndpoint;
    if (endpoint == null || endpoint.isEmpty) return;
    final name = (obj['macDeviceName'] as String?) ?? 'Mac';
    final localEndpoint = _reconnectLocalEndpoint ?? _pairingFallbackEndpoint;
    await _savePairedDevice(
      PairedDevice(
        id: endpoint,
        name: name,
        endpoint: endpoint,
        endpointLocal: localEndpoint,
        lastConnected: DateTime.now(),
      ),
    );
  }

  void _handleRemoteEvent(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'aiStatus':
        final p = AIStatusPayload.fromJson(payload);
        final info = AIInfoDTO(
          id: p.aiId,
          name: p.name,
          provider: p.provider ?? '',
          isRunning: p.isRunning,
          workingDirectory: p.workingDirectory,
        );
        final idx = aiList.indexWhere((a) => a.id == info.id);
        if (idx >= 0) {
          aiList[idx] = info;
        } else {
          aiList.add(info);
        }
        notifyListeners();
        break;
      case 'aiResponse':
        final resp = AIResponsePayload.fromJson(payload);
        _handleAIResponse(resp);
        break;
      case 'terminalPrompt':
        currentPrompt = TerminalPromptPayload.fromJson(payload);
        notifyListeners();
        break;
      case 'groupChatsSnapshot':
        final snap = GroupChatsSnapshotPayload.fromJson(payload);
        groupChats
          ..clear()
          ..addAll(snap.chats..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
        notifyListeners();
        break;
      case 'groupChatError':
        _updateError(payload['error'] as String? ?? 'Group chat error');
        break;
      default:
        break;
    }
  }

  void _handleAIResponse(AIResponsePayload resp) {
    final list = messagesByAI.putIfAbsent(resp.aiId, () => []);
    final msg = resp.message;

    if (resp.isStreaming && list.isNotEmpty) {
      final last = list.last;
      if (last.senderType == msg.senderType && last.senderId == msg.senderId) {
        list[list.length - 1] = msg;
      } else {
        list.add(msg);
      }
    } else {
      if (list.isNotEmpty) {
        final last = list.last;
        if (last.senderType == msg.senderType &&
            last.senderId == msg.senderId &&
            last.content == msg.content) {
          notifyListeners();
          return;
        }
      }
      list.add(msg);
    }

    if (msg.senderType != 'user') {
      pendingAIResponses.remove(resp.aiId);
    }

    notifyListeners();
  }

  // MARK: - Sending

  void sendMessage(String aiId, String text) {
    if (state != ConnectionState.connected) return;
    pendingAIResponses.add(aiId);
    _sendJson({
      'type': 'sendMessage',
      'aiId': aiId,
      'text': text,
    });
    notifyListeners();
  }

  void submitTerminalChoice(String aiId, int choice) {
    if (state != ConnectionState.connected) return;
    _sendJson({'type': 'terminalChoice', 'aiId': aiId, 'choice': choice});
    currentPrompt = null;
    notifyListeners();
  }

  void createGroupChat(String name, List<String> memberIds) {
    if (state != ConnectionState.connected) return;
    _sendJson({'type': 'createGroupChat', 'name': name, 'memberIds': memberIds});
  }

  void sendGroupMessage(String chatId, String text) {
    if (state != ConnectionState.connected) return;
    _sendJson({'type': 'sendGroupMessage', 'chatId': chatId, 'text': text});
  }

  // MARK: - Helpers

  void _sendJson(Map<String, dynamic> obj) {
    final bytes = utf8.encode(jsonEncode(obj));
    _channel?.sink.add(bytes);
  }

  void _updateState(ConnectionState newState) {
    state = newState;
    if (newState != ConnectionState.error) {
      errorMessage = null;
    }
    notifyListeners();
  }

  void _updateError(String message) {
    state = ConnectionState.error;
    errorMessage = message;
    notifyListeners();
  }

  String _localDeviceDisplayName() {
    final os = Platform.operatingSystem;
    final host = Platform.localHostname;
    if (host.isNotEmpty) return '$host ($os)';
    return 'BattleLM ($os)';
  }
}
