import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/models/models.dart';
import '../core/services/storage_service.dart';
import '../core/local/local_engine.dart';

class AppState extends ChangeNotifier {
  final StorageService storage;
  final LocalEngine engine;

  AppState({required this.storage, required this.engine});

  final List<AIInstance> aiInstances = [];
  final List<GroupChat> groupChats = [];

  /// AI ids currently "thinking" (show typing indicator).
  final Set<String> pendingAiResponses = {};

  String? selectedAiId;
  String? selectedGroupChatId;

  bool isLoading = true;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final a = await storage.loadAIInstances();
    final g = await storage.loadGroupChats();
    aiInstances
      ..clear()
      ..addAll(a);
    groupChats
      ..clear()
      ..addAll(g);
    isLoading = false;
    notifyListeners();
  }

  AIInstance? get selectedAI {
    if (selectedAiId == null) return null;
    try {
      return aiInstances.firstWhere((a) => a.id == selectedAiId);
    } catch (_) {
      return null;
    }
  }

  GroupChat? get selectedGroupChat {
    if (selectedGroupChatId == null) return null;
    try {
      return groupChats.firstWhere((c) => c.id == selectedGroupChatId);
    } catch (_) {
      return null;
    }
  }

  void selectAI(AIInstance ai) {
    selectedAiId = ai.id;
    selectedGroupChatId = null;
    notifyListeners();
  }

  void selectGroupChat(GroupChat chat) {
    selectedGroupChatId = chat.id;
    selectedAiId = null;
    notifyListeners();
  }

  Future<void> addAI({required AIType type, required String name, required String workingDirectory}) async {
    final ai = AIInstance.create(type: type, name: name.isEmpty ? null : name, workingDirectory: workingDirectory.isEmpty ? '~' : workingDirectory);
    aiInstances.insert(0, ai);
    await storage.saveAIInstances(aiInstances);
    selectAI(ai);
  }

  Future<void> setAIModel({required String aiId, required String? modelId}) async {
    final idx = aiInstances.indexWhere((a) => a.id == aiId);
    if (idx < 0) return;
    aiInstances[idx] = aiInstances[idx].copyWith(selectedModel: modelId);
    await storage.saveAIInstances(aiInstances);
    notifyListeners();
  }

  Future<void> removeAI(AIInstance ai) async {
    aiInstances.removeWhere((a) => a.id == ai.id);
    if (selectedAiId == ai.id) selectedAiId = null;
    // Also remove from group chats (immutable update).
    for (var i = 0; i < groupChats.length; i++) {
      final chat = groupChats[i];
      final updatedMembers = chat.members.where((m) => m.id != ai.id).toList();
      if (updatedMembers.length != chat.members.length) {
        groupChats[i] = chat.copyWith(members: updatedMembers);
      }
    }
    await storage.saveAIInstances(aiInstances);
    await storage.saveGroupChats(groupChats);
    notifyListeners();
  }

  Future<void> addGroupChat({required String name, required List<AIInstance> members}) async {
    final chat = GroupChat.create(name: name, members: members);
    groupChats.insert(0, chat);
    await storage.saveGroupChats(groupChats);
    selectGroupChat(chat);
  }

  Future<void> removeGroupChat(GroupChat chat) async {
    groupChats.removeWhere((c) => c.id == chat.id);
    if (selectedGroupChatId == chat.id) selectedGroupChatId = null;
    await storage.saveGroupChats(groupChats);
    notifyListeners();
  }

  Future<void> sendUserMessageToAI(AIInstance ai, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final idx = aiInstances.indexWhere((a) => a.id == ai.id);
    if (idx < 0) return;

    final updated = aiInstances[idx].copyWith(
      messages: [
        ...aiInstances[idx].messages,
        Message.user(content: trimmed),
      ],
    );
    aiInstances[idx] = updated;
    await storage.saveAIInstances(aiInstances);
    pendingAiResponses.add(ai.id);
    notifyListeners();

    await _runLocalAI(ai, trimmed);
  }

  Future<void> sendUserMessageToGroupChat(GroupChat chat, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final idx = groupChats.indexWhere((c) => c.id == chat.id);
    if (idx < 0) return;

    final updated = groupChats[idx].copyWith(
      messages: [
        ...groupChats[idx].messages,
        Message.user(content: trimmed),
      ],
    );
    groupChats[idx] = updated;
    await storage.saveGroupChats(groupChats);
    notifyListeners();

    // For now, run each AI sequentially. (Parallel can be added later.)
    for (final member in updated.members) {
      await _runLocalGroupAI(chatId: updated.id, ai: member, userText: trimmed);
    }
  }

  Future<void> _runLocalAI(AIInstance ai, String userText) async {
    final stream = await engine.runOnce(ai: ai, prompt: userText);
    var buffer = '';
    var didCreate = false;

    await for (final evt in stream) {
      if (evt is EngineTextDelta) {
        buffer += evt.delta;
        await _upsertAIStreaming(aiId: ai.id, aiName: ai.name, content: buffer, createIfNeeded: !didCreate);
        didCreate = true;
      } else if (evt is EngineInfo) {
        // Keep UI clean; provider info can be surfaced in a future "Logs" panel.
      } else if (evt is EngineError) {
        await _appendAISystem(aiId: ai.id, aiName: 'System', content: evt.message);
        pendingAiResponses.remove(ai.id);
        notifyListeners();
      } else if (evt is EngineDone) {
        pendingAiResponses.remove(ai.id);
        notifyListeners();
      }
    }
  }

  Future<void> _runLocalGroupAI({required String chatId, required AIInstance ai, required String userText}) async {
    final stream = await engine.runOnce(ai: ai, prompt: userText);
    var buffer = '';
    var didCreate = false;

    await for (final evt in stream) {
      if (evt is EngineTextDelta) {
        buffer += evt.delta;
        await _upsertGroupStreaming(chatId: chatId, aiName: ai.name, aiId: ai.id, content: buffer, createIfNeeded: !didCreate);
        didCreate = true;
      } else if (evt is EngineInfo) {
        // no-op
      } else if (evt is EngineError) {
        await _appendGroupSystem(chatId: chatId, content: evt.message);
      } else if (evt is EngineDone) {
        // no-op
      }
    }
  }

  Future<void> _upsertAIStreaming({
    required String aiId,
    required String aiName,
    required String content,
    required bool createIfNeeded,
  }) async {
    final idx = aiInstances.indexWhere((a) => a.id == aiId);
    if (idx < 0) return;
    final ai = aiInstances[idx];
    final msgs = List<Message>.from(ai.messages);

    if (createIfNeeded || msgs.isEmpty || msgs.last.senderType == SenderType.user) {
      msgs.add(Message.ai(content: content, senderId: aiId, senderName: aiName, id: _randomId()));
    } else {
      final last = msgs.last;
      msgs[msgs.length - 1] = Message.ai(
        id: last.id,
        content: content,
        senderId: aiId,
        senderName: aiName,
      );
    }

    aiInstances[idx] = ai.copyWith(messages: msgs);
    await storage.saveAIInstances(aiInstances);
    notifyListeners();
  }

  Future<void> _appendAISystem({required String aiId, required String aiName, required String content}) async {
    final idx = aiInstances.indexWhere((a) => a.id == aiId);
    if (idx < 0) return;
    final ai = aiInstances[idx];
    final msgs = [
      ...ai.messages,
      Message.system(content: content),
    ];
    aiInstances[idx] = ai.copyWith(messages: msgs);
    await storage.saveAIInstances(aiInstances);
    notifyListeners();
  }

  Future<void> _upsertGroupStreaming({
    required String chatId,
    required String aiId,
    required String aiName,
    required String content,
    required bool createIfNeeded,
  }) async {
    final idx = groupChats.indexWhere((c) => c.id == chatId);
    if (idx < 0) return;
    final chat = groupChats[idx];
    final msgs = List<Message>.from(chat.messages);

    if (createIfNeeded || msgs.isEmpty || msgs.last.senderType == SenderType.user) {
      msgs.add(Message.ai(content: content, senderId: aiId, senderName: aiName, id: _randomId()));
    } else {
      final last = msgs.last;
      msgs[msgs.length - 1] = Message.ai(
        id: last.id,
        content: content,
        senderId: aiId,
        senderName: aiName,
      );
    }

    groupChats[idx] = chat.copyWith(messages: msgs);
    await storage.saveGroupChats(groupChats);
    notifyListeners();
  }

  Future<void> _appendGroupSystem({required String chatId, required String content}) async {
    final idx = groupChats.indexWhere((c) => c.id == chatId);
    if (idx < 0) return;
    final chat = groupChats[idx];
    final msgs = [
      ...chat.messages,
      Message.system(content: content),
    ];
    groupChats[idx] = chat.copyWith(messages: msgs);
    await storage.saveGroupChats(groupChats);
    notifyListeners();
  }

  void _streamMessageToAI({
    required String aiId,
    required String senderId,
    required String senderName,
    required String full,
  }) {
    final chunks = _chunk(full, 18);
    int i = 0;
    Timer.periodic(const Duration(milliseconds: 30), (timer) async {
      final idx = aiInstances.indexWhere((a) => a.id == aiId);
      if (idx < 0) {
        timer.cancel();
        return;
      }
      final ai = aiInstances[idx];
      final existing = ai.messages;
      final currentText = chunks.take(i + 1).join();
      final isFirst = i == 0;

      final nextMessages = List<Message>.from(existing);
      if (isFirst) {
        nextMessages.add(Message.ai(content: currentText, senderId: senderId, senderName: senderName));
      } else {
        nextMessages[nextMessages.length - 1] = Message.ai(
          id: nextMessages.last.id,
          content: currentText,
          senderId: senderId,
          senderName: senderName,
        );
      }

      aiInstances[idx] = ai.copyWith(messages: nextMessages);
      await storage.saveAIInstances(aiInstances);
      notifyListeners();

      i += 1;
      if (i >= chunks.length) {
        timer.cancel();
        pendingAiResponses.remove(aiId);
        notifyListeners();
      }
    });
  }

  void _streamMessageToGroup({
    required String chatId,
    required String senderId,
    required String senderName,
    required String full,
  }) {
    final chunks = _chunk(full, 18);
    int i = 0;
    Timer.periodic(const Duration(milliseconds: 32), (timer) async {
      final idx = groupChats.indexWhere((c) => c.id == chatId);
      if (idx < 0) {
        timer.cancel();
        return;
      }
      final chat = groupChats[idx];
      final existing = chat.messages;
      final currentText = chunks.take(i + 1).join();
      final isFirst = i == 0;

      final nextMessages = List<Message>.from(existing);
      if (isFirst) {
        nextMessages.add(Message.ai(content: currentText, senderId: senderId, senderName: senderName));
      } else {
        nextMessages[nextMessages.length - 1] = Message.ai(
          id: nextMessages.last.id,
          content: currentText,
          senderId: senderId,
          senderName: senderName,
        );
      }

      groupChats[idx] = chat.copyWith(messages: nextMessages);
      await storage.saveGroupChats(groupChats);
      notifyListeners();

      i += 1;
      if (i >= chunks.length) timer.cancel();
    });
  }

  List<String> _chunk(String s, int n) {
    final out = <String>[];
    for (var i = 0; i < s.length; i += n) {
      out.add(s.substring(i, (i + n) > s.length ? s.length : i + n));
    }
    return out;
  }

  String _randomId() => (math.Random().nextInt(1 << 31)).toString();
}
