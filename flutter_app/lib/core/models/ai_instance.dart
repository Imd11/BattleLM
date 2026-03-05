import 'package:equatable/equatable.dart';
import 'enums.dart';
import 'message.dart';

/// AI Instance - represents an AI agent in the battle
class AIInstance extends Equatable {
  final String id;
  final AIType type;
  final String name;
  final String workingDirectory;
  final String tmuxSession;
  final bool isActive;
  final bool isEliminated;
  final double eliminationScore;
  final List<Message> messages;
  final String? selectedModel;
  final ReasoningEffort? selectedReasoningEffort;
  final String? fallbackDefaultModelId;

  const AIInstance({
    required this.id,
    required this.type,
    required this.name,
    this.workingDirectory = '~',
    required this.tmuxSession,
    this.isActive = false,
    this.isEliminated = false,
    this.eliminationScore = 0,
    this.messages = const [],
    this.selectedModel,
    this.selectedReasoningEffort,
    this.fallbackDefaultModelId,
  });

  /// Get the resolved default model ID
  String get resolvedDefaultModelId {
    if (fallbackDefaultModelId != null) {
      final models = type.availableModels;
      if (models.any((m) => m.id == fallbackDefaultModelId || m.actualModelId == fallbackDefaultModelId)) {
        return fallbackDefaultModelId!;
      }
    }
    return type.defaultModel.id;
  }

  /// Get the currently selected model or default
  String get currentModel => selectedModel ?? resolvedDefaultModelId;

  /// Create a copy with updated fields
  AIInstance copyWith({
    String? id,
    AIType? type,
    String? name,
    String? workingDirectory,
    String? tmuxSession,
    bool? isActive,
    bool? isEliminated,
    double? eliminationScore,
    List<Message>? messages,
    String? selectedModel,
    ReasoningEffort? selectedReasoningEffort,
    String? fallbackDefaultModelId,
  }) {
    return AIInstance(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      tmuxSession: tmuxSession ?? this.tmuxSession,
      isActive: isActive ?? this.isActive,
      isEliminated: isEliminated ?? this.isEliminated,
      eliminationScore: eliminationScore ?? this.eliminationScore,
      messages: messages ?? this.messages,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedReasoningEffort: selectedReasoningEffort ?? this.selectedReasoningEffort,
      fallbackDefaultModelId: fallbackDefaultModelId ?? this.fallbackDefaultModelId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.id,
        'name': name,
        'workingDirectory': workingDirectory,
        'tmuxSession': tmuxSession,
        'isActive': isActive,
        'isEliminated': isEliminated,
        'eliminationScore': eliminationScore,
        'messages': messages.map((m) => m.toJson()).toList(),
        'selectedModel': selectedModel,
        'selectedReasoningEffort': selectedReasoningEffort?.id,
        'fallbackDefaultModelId': fallbackDefaultModelId,
      };

  factory AIInstance.fromJson(Map<String, dynamic> json) => AIInstance(
        id: json['id'] as String,
        type: AIType.fromString(json['type'] as String),
        name: json['name'] as String,
        workingDirectory: json['workingDirectory'] as String? ?? '~',
        tmuxSession: json['tmuxSession'] as String,
        isActive: json['isActive'] as bool? ?? false,
        isEliminated: json['isEliminated'] as bool? ?? false,
        eliminationScore: (json['eliminationScore'] as num?)?.toDouble() ?? 0,
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        selectedModel: json['selectedModel'] as String?,
        selectedReasoningEffort: json['selectedReasoningEffort'] != null
            ? ReasoningEffort.fromString(json['selectedReasoningEffort'] as String)
            : null,
        fallbackDefaultModelId: json['fallbackDefaultModelId'] as String?,
      );

  /// Create a new AI instance
  factory AIInstance.create({
    required AIType type,
    String? name,
    String workingDirectory = '~',
  }) {
    final instanceId = DateTime.now().millisecondsSinceEpoch.toString();
    return AIInstance(
      id: instanceId,
      type: type,
      name: name ?? type.displayName,
      workingDirectory: workingDirectory,
      tmuxSession: 'battlelm-$instanceId',
      isActive: false,
      isEliminated: false,
      eliminationScore: 0,
      messages: [],
      selectedModel: null,
      selectedReasoningEffort: null,
      fallbackDefaultModelId: null,
    );
  }

  @override
 List<Object?> get props => [
        id,
        type,
        name,
        workingDirectory,
        tmuxSession,
        isActive,
        isEliminated,
        eliminationScore,
        messages,
        selectedModel,
        selectedReasoningEffort,
        fallbackDefaultModelId,
      ];
}

/// Extension to provide model options for each AI type
extension AITypeExtension on AIType {
  List<ModelOption> get availableModels {
    switch (this) {
      case AIType.claude:
        return const [
          ModelOption(
            id: 'claude-sonnet-4-6',
            displayName: 'Claude Sonnet 4.6',
            subtitle: 'Latest Sonnet model',
            isDefault: true,
            reasoningEfforts: [ReasoningEffort.low, ReasoningEffort.medium, ReasoningEffort.high, ReasoningEffort.xhigh],
            defaultEffort: ReasoningEffort.medium,
            enableThinking: true,
          ),
          ModelOption(
            id: 'claude-sonnet-4-5',
            displayName: 'Claude Sonnet 4.5',
            subtitle: 'Previous Sonnet model',
          ),
          ModelOption(
            id: 'claude-haiku-3-5',
            displayName: 'Claude Haiku 3.5',
            subtitle: 'Fast and efficient',
          ),
        ];
      case AIType.gemini:
        return const [
          ModelOption(
            id: 'gemini-2.0-flash',
            displayName: 'Gemini 2.0 Flash',
            subtitle: 'Latest fast model',
            isDefault: true,
          ),
          ModelOption(
            id: 'gemini-1.5-pro',
            displayName: 'Gemini 1.5 Pro',
            subtitle: 'Balanced performance',
          ),
          ModelOption(
            id: 'gemini-1.5-flash',
            displayName: 'Gemini 1.5 Flash',
            subtitle: 'Fast and efficient',
          ),
        ];
      case AIType.codex:
        return const [
          ModelOption(
            id: 'codex-latest',
            displayName: 'Codex Latest',
            subtitle: 'Latest Codex model',
            isDefault: true,
          ),
        ];
      case AIType.qwen:
        return const [
          ModelOption(
            id: 'qwen-turbo',
            displayName: 'Qwen Turbo',
            subtitle: 'Fast response',
            isDefault: true,
          ),
          ModelOption(
            id: 'qwen-plus',
            displayName: 'Qwen Plus',
            subtitle: 'Balanced performance',
          ),
          ModelOption(
            id: 'qwen-max',
            displayName: 'Qwen Max',
            subtitle: 'Best quality',
          ),
        ];
      case AIType.kimi:
        return const [
          ModelOption(
            id: 'kimi-latest',
            displayName: 'Kimi Latest',
            subtitle: 'Latest Kimi model',
            isDefault: true,
          ),
        ];
    }
  }

  ModelOption get defaultModel {
    return availableModels.firstWhere(
      (m) => m.isDefault,
      orElse: () => availableModels.first,
    );
  }
}
