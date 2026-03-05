import 'dart:convert';

/// Protocol models matching the macOS `RemoteHostServer` + BattleLMShared.

class PairingQRPayload {
  final String deviceId;
  final String deviceName;
  final String publicKeyFingerprint;
  final String endpointWss;
  final String? endpointWsLocal;
  final String pairingCode;
  final DateTime expiresAt;

  const PairingQRPayload({
    required this.deviceId,
    required this.deviceName,
    required this.publicKeyFingerprint,
    required this.endpointWss,
    required this.endpointWsLocal,
    required this.pairingCode,
    required this.expiresAt,
  });

  factory PairingQRPayload.fromJson(Map<String, dynamic> json) {
    return PairingQRPayload(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      publicKeyFingerprint: json['publicKeyFingerprint'] as String,
      endpointWss: json['endpointWss'] as String,
      endpointWsLocal: json['endpointWsLocal'] as String?,
      pairingCode: json['pairingCode'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'publicKeyFingerprint': publicKeyFingerprint,
        'endpointWss': endpointWss,
        'endpointWsLocal': endpointWsLocal,
        'pairingCode': pairingCode,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static PairingQRPayload fromBase64(String base64) {
    final decoded = utf8.decode(base64Decode(base64));
    return PairingQRPayload.fromJson(jsonDecode(decoded) as Map<String, dynamic>);
  }
}

// MARK: - Auth

Map<String, dynamic> pairRequest({
  required String pairingCode,
  required String phonePublicKey,
  required String phoneName,
}) =>
    {
      'type': 'pairRequest',
      'pairingCode': pairingCode,
      'phonePublicKey': phonePublicKey,
      'phoneName': phoneName,
    };

Map<String, dynamic> challengeResponse({required String signatureBase64}) => {
      'type': 'challengeResponse',
      'signature': signatureBase64,
    };

Map<String, dynamic> authHello({
  required String phonePublicKey,
  required String phoneName,
}) =>
    {
      'type': 'authHello',
      'phonePublicKey': phonePublicKey,
      'phoneName': phoneName,
    };

Map<String, dynamic> authResponse({
  required String phonePublicKey,
  required String signatureBase64,
}) =>
    {
      'type': 'authResponse',
      'phonePublicKey': phonePublicKey,
      'signature': signatureBase64,
    };

// MARK: - Event stream

class RemoteEvent {
  final String type;
  final int seq;
  final String payloadJSON;

  const RemoteEvent({
    required this.type,
    required this.seq,
    required this.payloadJSON,
  });

  factory RemoteEvent.fromJson(Map<String, dynamic> json) => RemoteEvent(
        type: json['type'] as String,
        seq: json['seq'] as int,
        payloadJSON: json['payloadJSON'] as String,
      );
}

class MessageDTO {
  final String id;
  final String senderId;
  final String senderType; // user | system | assistant/ai
  final String senderName;
  final String content;
  final DateTime timestamp;

  const MessageDTO({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory MessageDTO.fromJson(Map<String, dynamic> json) => MessageDTO(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        senderType: json['senderType'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class AIInfoDTO {
  final String id;
  final String name;
  final String provider;
  final bool isRunning;
  final String? workingDirectory;

  const AIInfoDTO({
    required this.id,
    required this.name,
    required this.provider,
    required this.isRunning,
    required this.workingDirectory,
  });

  factory AIInfoDTO.fromJson(Map<String, dynamic> json) => AIInfoDTO(
        id: json['id'] as String,
        name: json['name'] as String,
        provider: (json['provider'] as String?) ?? '',
        isRunning: json['isRunning'] as bool,
        workingDirectory: json['workingDirectory'] as String?,
      );
}

class AIStatusPayload {
  final String aiId;
  final String name;
  final String? provider;
  final bool isRunning;
  final String? workingDirectory;

  const AIStatusPayload({
    required this.aiId,
    required this.name,
    required this.provider,
    required this.isRunning,
    required this.workingDirectory,
  });

  factory AIStatusPayload.fromJson(Map<String, dynamic> json) => AIStatusPayload(
        aiId: json['aiId'] as String,
        name: json['name'] as String,
        provider: json['provider'] as String?,
        isRunning: json['isRunning'] as bool,
        workingDirectory: json['workingDirectory'] as String?,
      );
}

class AIResponsePayload {
  final String aiId;
  final MessageDTO message;
  final bool isStreaming;

  const AIResponsePayload({
    required this.aiId,
    required this.message,
    required this.isStreaming,
  });

  factory AIResponsePayload.fromJson(Map<String, dynamic> json) => AIResponsePayload(
        aiId: json['aiId'] as String,
        message: MessageDTO.fromJson(json['message'] as Map<String, dynamic>),
        isStreaming: json['isStreaming'] as bool,
      );
}

class TerminalPromptPayload {
  final String aiId;
  final String title;
  final String? body;
  final String? hint;
  final List<TerminalPromptOption> options;

  const TerminalPromptPayload({
    required this.aiId,
    required this.title,
    required this.body,
    required this.hint,
    required this.options,
  });

  factory TerminalPromptPayload.fromJson(Map<String, dynamic> json) => TerminalPromptPayload(
        aiId: json['aiId'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        hint: json['hint'] as String?,
        options: (json['options'] as List<dynamic>)
            .map((o) => TerminalPromptOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class TerminalPromptOption {
  final int number;
  final String label;

  const TerminalPromptOption({required this.number, required this.label});

  factory TerminalPromptOption.fromJson(Map<String, dynamic> json) => TerminalPromptOption(
        number: json['number'] as int,
        label: json['label'] as String,
      );
}

class GroupChatDTO {
  final String id;
  final String name;
  final List<String> memberIds;
  final String mode;
  final bool isActive;
  final List<MessageDTO> messages;

  const GroupChatDTO({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.mode,
    required this.isActive,
    required this.messages,
  });

  factory GroupChatDTO.fromJson(Map<String, dynamic> json) => GroupChatDTO(
        id: json['id'] as String,
        name: json['name'] as String,
        memberIds: (json['memberIds'] as List<dynamic>).map((e) => e as String).toList(),
        mode: json['mode'] as String,
        isActive: json['isActive'] as bool,
        messages: (json['messages'] as List<dynamic>)
            .map((m) => MessageDTO.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class GroupChatsSnapshotPayload {
  final List<GroupChatDTO> chats;

  const GroupChatsSnapshotPayload({required this.chats});

  factory GroupChatsSnapshotPayload.fromJson(Map<String, dynamic> json) => GroupChatsSnapshotPayload(
        chats: (json['chats'] as List<dynamic>)
            .map((c) => GroupChatDTO.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

