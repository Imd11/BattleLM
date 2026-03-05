import 'package:equatable/equatable.dart';
import 'enums.dart';

/// Chat message
class Message extends Equatable {
  final String id;
  final String content;
  final SenderType senderType;
  final String? senderId;
  final String? senderName;
  final DateTime timestamp;
  final int? roundNumber;
  final MessageType? messageType;
  final bool isStreaming;
  final String? reaction; // like/dislike

  const Message({
    required this.id,
    required this.content,
    required this.senderType,
    this.senderId,
    this.senderName,
    required this.timestamp,
    this.roundNumber,
    this.messageType,
    this.isStreaming = false,
    this.reaction,
  });

  bool get isFromUser => senderType == SenderType.user;
  bool get isFromAI => senderType == SenderType.ai;
  bool get isSystem => senderType == SenderType.system;

  Message copyWith({
    String? id,
    String? content,
    SenderType? senderType,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    int? roundNumber,
    MessageType? messageType,
    bool? isStreaming,
    String? reaction,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      roundNumber: roundNumber ?? this.roundNumber,
      messageType: messageType ?? this.messageType,
      isStreaming: isStreaming ?? this.isStreaming,
      reaction: reaction ?? this.reaction,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'senderType': senderType.id,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': timestamp.toIso8601String(),
        'roundNumber': roundNumber,
        'messageType': messageType?.id,
        'isStreaming': isStreaming,
        'reaction': reaction,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        content: json['content'] as String,
        senderType: SenderType.fromString(json['senderType'] as String),
        senderId: json['senderId'] as String?,
        senderName: json['senderName'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        roundNumber: json['roundNumber'] as int?,
        messageType: json['messageType'] != null
            ? MessageType.fromString(json['messageType'] as String)
            : null,
        isStreaming: json['isStreaming'] as bool? ?? false,
        reaction: json['reaction'] as String?,
      );

  /// Create a user message
  factory Message.user({
    required String content,
    String? id,
  }) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderType: SenderType.user,
      timestamp: DateTime.now(),
    );
  }

  /// Create an AI message
  factory Message.ai({
    required String content,
    required String senderId,
    required String senderName,
    int? roundNumber,
    MessageType? messageType,
    String? id,
  }) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderType: SenderType.ai,
      senderId: senderId,
      senderName: senderName,
      timestamp: DateTime.now(),
      roundNumber: roundNumber,
      messageType: messageType,
    );
  }

  /// Create a system message
  factory Message.system({
    required String content,
    String? id,
  }) {
    return Message(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderType: SenderType.system,
      timestamp: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        senderType,
        senderId,
        senderName,
        timestamp,
        roundNumber,
        messageType,
        isStreaming,
        reaction,
      ];
}
