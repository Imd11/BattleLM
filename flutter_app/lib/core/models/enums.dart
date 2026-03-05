import 'package:equatable/equatable.dart';

/// AI type enumeration
enum AIType {
  claude('claude', 'Claude', 'brain.head.profile'),
  gemini('gemini', 'Gemini', 'sparkles'),
  codex('codex', 'Codex', 'chevron.left.forwardslash.chevron.right'),
  qwen('qwen', 'Qwen', 'wand.and.stars'),
  kimi('kimi', 'Kimi', 'person.2.wave.2');

  final String id;
  final String displayName;
  final String iconName;

  const AIType(this.id, this.displayName, this.iconName);

  static AIType fromString(String value) {
    return AIType.values.firstWhere(
      (e) => e.id == value,
      orElse: () => AIType.claude,
    );
  }
}

/// Reasoning effort level
enum ReasoningEffort {
  low('low', 'Low', 'Fast responses with lighter reasoning'),
  medium('medium', 'Medium', 'Balances speed and reasoning depth'),
  high('high', 'High', 'Greater reasoning depth for complex problems'),
  xhigh('xhigh', 'XHigh', 'Extra high reasoning depth for complex problems');

  final String id;
  final String displayName;
  final String subtitle;

  const ReasoningEffort(this.id, this.displayName, this.subtitle);

  static ReasoningEffort fromString(String value) {
    return ReasoningEffort.values.firstWhere(
      (e) => e.id == value,
      orElse: () => ReasoningEffort.medium,
    );
  }
}

/// Model option for AI
class ModelOption extends Equatable {
  final String id;
  final String displayName;
  final String subtitle;
  final bool isDefault;
  final List<ReasoningEffort> reasoningEfforts;
  final ReasoningEffort? defaultEffort;
  final bool enableThinking;

  const ModelOption({
    required this.id,
    required this.displayName,
    required this.subtitle,
    this.isDefault = false,
    this.reasoningEfforts = const [],
    this.defaultEffort,
    this.enableThinking = false,
  });

  String get actualModelId => id.replaceAll('(thinking)', '');

  bool get hasReasoningEffort => reasoningEfforts.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'subtitle': subtitle,
        'isDefault': isDefault,
        'reasoningEfforts': reasoningEfforts.map((e) => e.id).toList(),
        'defaultEffort': defaultEffort?.id,
        'enableThinking': enableThinking,
      };

  factory ModelOption.fromJson(Map<String, dynamic> json) => ModelOption(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        subtitle: json['subtitle'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        reasoningEfforts: (json['reasoningEfforts'] as List<dynamic>?)
                ?.map((e) => ReasoningEffort.fromString(e as String))
                .toList() ??
            [],
        defaultEffort: json['defaultEffort'] != null
            ? ReasoningEffort.fromString(json['defaultEffort'] as String)
            : null,
        enableThinking: json['enableThinking'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        id,
        displayName,
        subtitle,
        isDefault,
        reasoningEfforts,
        defaultEffort,
        enableThinking,
      ];
}

/// Chat mode
enum ChatMode {
  discussion('discussion', 'Discussion', 'Multi-round AI debate'),
  qna('qna', 'Q&A', 'Single-round Q&A'),
  solo('solo', 'Solo', 'Single AI conversation');

  final String id;
  final String displayName;
  final String description;

  const ChatMode(this.id, this.displayName, this.description);

  static ChatMode fromString(String value) {
    return ChatMode.values.firstWhere(
      (e) => e.id == value,
      orElse: () => ChatMode.discussion,
    );
  }
}

/// Message type
enum MessageType {
  question('question'),
  analysis('analysis'),
  evaluation('evaluation'),
  system('system');

  final String id;
  const MessageType(this.id);

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.id == value,
      orElse: () => MessageType.system,
    );
  }
}

/// Sender type
enum SenderType {
  user('user'),
  ai('ai'),
  system('system');

  final String id;
  const SenderType(this.id);

  static SenderType fromString(String value) {
    return SenderType.values.firstWhere(
      (e) => e.id == value,
      orElse: () => SenderType.system,
    );
  }
}
