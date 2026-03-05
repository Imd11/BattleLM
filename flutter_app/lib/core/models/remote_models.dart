import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Remote message base class
class RemoteMessage extends Equatable {
  final String type;
  final dynamic payload;

  const RemoteMessage({
    required this.type,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
      };

  factory RemoteMessage.fromJson(Map<String, dynamic> json) => RemoteMessage(
        type: json['type'] as String,
        payload: json['payload'],
      );

  String encode() => jsonEncode(toJson());

  static RemoteMessage? decode(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return RemoteMessage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [type, payload];
}

/// Host capabilities payload
class HostCapabilities extends Equatable {
  final String platform; // windows, linux, macos
  final List<String> supportedAIs;
  final List<String> features;
  final String version;

  const HostCapabilities({
    required this.platform,
    required this.supportedAIs,
    required this.features,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'supportedAIs': supportedAIs,
        'features': features,
        'version': version,
      };

  factory HostCapabilities.fromJson(Map<String, dynamic> json) =>
      HostCapabilities(
        platform: json['platform'] as String,
        supportedAIs: (json['supportedAIs'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        features:
            (json['features'] as List<dynamic>).map((e) => e as String).toList(),
        version: json['version'] as String,
      );

  @override
  List<Object?> get props => [platform, supportedAIs, features, version];
}

/// Session control payload
class SessionControl extends Equatable {
  final String action; // start, stop, send, kill
  final String? aiId;
  final String? aiType;
  final String? workingDirectory;
  final String? model;
  final String? message;

  const SessionControl({
    required this.action,
    this.aiId,
    this.aiType,
    this.workingDirectory,
    this.model,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        if (aiId != null) 'aiId': aiId,
        if (aiType != null) 'aiType': aiType,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        if (model != null) 'model': model,
        if (message != null) 'message': message,
      };

  factory SessionControl.fromJson(Map<String, dynamic> json) => SessionControl(
        action: json['action'] as String,
        aiId: json['aiId'] as String?,
        aiType: json['aiType'] as String?,
        workingDirectory: json['workingDirectory'] as String?,
        model: json['model'] as String?,
        message: json['message'] as String?,
      );

  @override
  List<Object?> get props =>
      [action, aiId, aiType, workingDirectory, model, message];
}

/// Terminal I/O payload
class TerminalIO extends Equatable {
  final String aiId;
  final String data;
  final bool isInput;

  const TerminalIO({
    required this.aiId,
    required this.data,
    required this.isInput,
  });

  Map<String, dynamic> toJson() => {
        'aiId': aiId,
        'data': data,
        'isInput': isInput,
      };

  factory TerminalIO.fromJson(Map<String, dynamic> json) => TerminalIO(
        aiId: json['aiId'] as String,
        data: json['data'] as String,
        isInput: json['isInput'] as bool,
      );

  @override
  List<Object?> get props => [aiId, data, isInput];
}

/// Token usage payload
class TokenUsage extends Equatable {
  final String aiType;
  final int inputTokens;
  final int outputTokens;
  final int? cacheTokens;
  final DateTime timestamp;

  const TokenUsage({
    required this.aiType,
    required this.inputTokens,
    required this.outputTokens,
    this.cacheTokens,
    required this.timestamp,
  });

  int get totalTokens => inputTokens + outputTokens;

  Map<String, dynamic> toJson() => {
        'aiType': aiType,
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        if (cacheTokens != null) 'cacheTokens': cacheTokens,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        aiType: json['aiType'] as String,
        inputTokens: json['inputTokens'] as int,
        outputTokens: json['outputTokens'] as int,
        cacheTokens: json['cacheTokens'] as int?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  List<Object?> get props =>
      [aiType, inputTokens, outputTokens, cacheTokens, timestamp];
}

/// AI Info DTO for remote communication
class AIInfoDTO extends Equatable {
  final String id;
  final String name;
  final String type;
  final String? selectedModel;
  final bool isActive;
  final bool isEliminated;

  const AIInfoDTO({
    required this.id,
    required this.name,
    required this.type,
    this.selectedModel,
    this.isActive = false,
    this.isEliminated = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'selectedModel': selectedModel,
        'isActive': isActive,
        'isEliminated': isEliminated,
      };

  factory AIInfoDTO.fromJson(Map<String, dynamic> json) => AIInfoDTO(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        selectedModel: json['selectedModel'] as String?,
        isActive: json['isActive'] as bool? ?? false,
        isEliminated: json['isEliminated'] as bool? ?? false,
      );

  @override
  List<Object?> get props =>
      [id, name, type, selectedModel, isActive, isEliminated];
}

/// Group chat DTO for remote communication
class GroupChatDTO extends Equatable {
  final String id;
  final String name;
  final List<AIInfoDTO> members;
  final int currentRound;
  final int maxRounds;
  final String mode;
  final List<String> eliminatedMemberIds;

  const GroupChatDTO({
    required this.id,
    required this.name,
    required this.members,
    this.currentRound = 0,
    this.maxRounds = 3,
    this.mode = 'discussion',
    this.eliminatedMemberIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'currentRound': currentRound,
        'maxRounds': maxRounds,
        'mode': mode,
        'eliminatedMemberIds': eliminatedMemberIds,
      };

  factory GroupChatDTO.fromJson(Map<String, dynamic> json) => GroupChatDTO(
        id: json['id'] as String,
        name: json['name'] as String,
        members: (json['members'] as List<dynamic>)
            .map((m) => AIInfoDTO.fromJson(m as Map<String, dynamic>))
            .toList(),
        currentRound: json['currentRound'] as int? ?? 0,
        maxRounds: json['maxRounds'] as int? ?? 3,
        mode: json['mode'] as String? ?? 'discussion',
        eliminatedMemberIds: (json['eliminatedMemberIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  @override
  List<Object?> get props =>
      [id, name, members, currentRound, maxRounds, mode, eliminatedMemberIds];
}

/// Terminal prompt option
class PromptOptionDTO extends Equatable {
  final int number;
  final String label;

  const PromptOptionDTO({
    required this.number,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'label': label,
      };

  factory PromptOptionDTO.fromJson(Map<String, dynamic> json) => PromptOptionDTO(
        number: json['number'] as int,
        label: json['label'] as String,
      );

  @override
  List<Object?> get props => [number, label];
}

/// Terminal prompt payload
class TerminalPromptPayload extends Equatable {
  final String aiId;
  final String title;
  final String? body;
  final String? hint;
  final List<PromptOptionDTO> options;

  const TerminalPromptPayload({
    required this.aiId,
    required this.title,
    this.body,
    this.hint,
    required this.options,
  });

  Map<String, dynamic> toJson() => {
        'aiId': aiId,
        'title': title,
        'body': body,
        'hint': hint,
        'options': options.map((o) => o.toJson()).toList(),
      };

  factory TerminalPromptPayload.fromJson(Map<String, dynamic> json) =>
      TerminalPromptPayload(
        aiId: json['aiId'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        hint: json['hint'] as String?,
        options: (json['options'] as List<dynamic>)
            .map((o) => PromptOptionDTO.fromJson(o as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [aiId, title, body, hint, options];
}
