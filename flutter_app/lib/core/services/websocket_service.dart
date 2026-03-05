import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// Connection state
enum WSConnectionState {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

/// WebSocket service for remote communication
class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<RemoteMessage>.broadcast();
  final _stateController = StreamController<WSConnectionState>.broadcast();

  String? _currentEndpoint;
  String? _pairingCode;
  bool _hasPairingCode = false;

  WSConnectionState _state = WSConnectionState.disconnected;
  WSConnectionState get state => _state;

  Stream<RemoteMessage> get messages => _messageController.stream;
  Stream<WSConnectionState> get stateChanges => _stateController.stream;

  String? get currentEndpoint => _currentEndpoint;

  /// Connect to a remote host
  Future<void> connect(String endpoint, {String? pairingCode}) async {
    await disconnect();

    _currentEndpoint = endpoint;
    _pairingCode = pairingCode;
    _hasPairingCode = pairingCode != null && pairingCode.isNotEmpty;

    _updateState(WSConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(endpoint));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 500));

      if (_hasPairingCode) {
        _updateState(WSConnectionState.authenticating);
        _sendMessage(RemoteMessage(
          type: 'pairing',
          payload: {'code': _pairingCode},
        ));
      } else {
        _updateState(WSConnectionState.connected);
      }
    } catch (e) {
      _updateState(WSConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect from the remote host
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _currentEndpoint = null;
    _pairingCode = null;
    _hasPairingCode = false;
    _updateState(WSConnectionState.disconnected);
  }

  /// Send a message to the remote host
  void send(String type, Map<String, dynamic> payload) {
    _sendMessage(RemoteMessage(type: type, payload: payload));
  }

  void _sendMessage(RemoteMessage message) {
    _channel?.sink.add(message.encode());
  }

  void _handleMessage(dynamic data) {
    try {
      final message = RemoteMessage.decode(data as String);
      if (message != null) {
        // Handle authentication response
        if (message.type == 'authResponse') {
          final payload = message.payload as Map<String, dynamic>;
          if (payload['success'] == true) {
            _updateState(WSConnectionState.connected);
          } else {
            _updateState(WSConnectionState.error);
          }
        }

        _messageController.add(message);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _updateState(WSConnectionState.error);
  }

  void _handleDone() {
    _updateState(WSConnectionState.disconnected);
  }

  void _updateState(WSConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Request host capabilities
  void requestHostCapabilities() {
    send('getCapabilities', {});
  }

  /// Request AI list from host
  void requestAIList() {
    send('getAIList', {});
  }

  /// Request group chats from host
  void requestGroupChats() {
    send('getGroupChats', {});
  }

  /// Send chat message
  void sendChatMessage({
    required String groupId,
    required String content,
    String? aiId,
  }) {
    send('chatMessage', {
      'groupId': groupId,
      'content': content,
      if (aiId != null) 'aiId': aiId,
    });
  }

  /// Send terminal prompt response
  void sendTerminalPromptResponse({
    required String aiId,
    required int optionNumber,
  }) {
    send('terminalPromptResponse', {
      'aiId': aiId,
      'option': optionNumber,
    });
  }

  /// Start a new group chat discussion
  void startDiscussion({
    required String groupId,
    required String question,
  }) {
    send('startDiscussion', {
      'groupId': groupId,
      'question': question,
    });
  }

  /// Stop the current discussion
  void stopDiscussion(String groupId) {
    send('stopDiscussion', {'groupId': groupId});
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
