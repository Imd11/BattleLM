import 'package:equatable/equatable.dart';
import 'ai_instance.dart';
import 'enums.dart';
import 'message.dart';

/// Group chat for multi-AI discussions
class GroupChat extends Equatable {
  final String id;
  final String name;
  final List<AIInstance> members;
  final List<Message> messages;
  final int currentRound;
  final int maxRounds;
  final ChatMode mode;
  final List<String> eliminatedMemberIds;
  final bool isActive;
  final DateTime createdAt;

  const GroupChat({
    required this.id,
    required this.name,
    required this.members,
    this.messages = const [],
    this.currentRound = 0,
    this.maxRounds = 3,
    this.mode = ChatMode.discussion,
    this.eliminatedMemberIds = const [],
    this.isActive = false,
    required this.createdAt,
  });

  /// Get active (non-eliminated) members
  List<AIInstance> get activeMembers =>
      members.where((m) => !eliminatedMemberIds.contains(m.id)).toList();

  /// Check if a member is eliminated
  bool isMemberEliminated(String memberId) =>
      eliminatedMemberIds.contains(memberId);

  /// Get member by ID
  AIInstance? getMember(String memberId) {
    try {
      return members.firstWhere((m) => m.id == memberId);
    } catch (_) {
      return null;
    }
  }

  GroupChat copyWith({
    String? id,
    String? name,
    List<AIInstance>? members,
    List<Message>? messages,
    int? currentRound,
    int? maxRounds,
    ChatMode? mode,
    List<String>? eliminatedMemberIds,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return GroupChat(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      mode: mode ?? this.mode,
      eliminatedMemberIds: eliminatedMemberIds ?? this.eliminatedMemberIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'currentRound': currentRound,
        'maxRounds': maxRounds,
        'mode': mode.id,
        'eliminatedMemberIds': eliminatedMemberIds,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GroupChat.fromJson(Map<String, dynamic> json) => GroupChat(
        id: json['id'] as String,
        name: json['name'] as String,
        members: (json['members'] as List<dynamic>)
            .map((m) => AIInstance.fromJson(m as Map<String, dynamic>))
            .toList(),
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        currentRound: json['currentRound'] as int? ?? 0,
        maxRounds: json['maxRounds'] as int? ?? 3,
        mode: ChatMode.fromString(json['mode'] as String? ?? 'discussion'),
        eliminatedMemberIds: (json['eliminatedMemberIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isActive: json['isActive'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Create a new group chat
  factory GroupChat.create({
    required String name,
    required List<AIInstance> members,
    ChatMode mode = ChatMode.discussion,
    int maxRounds = 3,
  }) {
    return GroupChat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      members: members,
      messages: [],
      currentRound: 0,
      maxRounds: maxRounds,
      mode: mode,
      eliminatedMemberIds: [],
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        members,
        messages,
        currentRound,
        maxRounds,
        mode,
        eliminatedMemberIds,
        isActive,
        createdAt,
      ];
}
