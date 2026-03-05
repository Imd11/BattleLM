import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/models.dart';
import 'widgets/message_bubble.dart';
import 'widgets/thinking_dots.dart';

class ChatView extends StatelessWidget {
  final AppState state;
  const ChatView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final ai = state.selectedAI;
    final chat = state.selectedGroupChat;

    if (ai == null && chat == null) {
      return const _EmptyPane();
    }

    if (ai != null) {
      return _AIChatPane(state: state, ai: ai);
    }

    return _GroupChatPane(state: state, chat: chat!);
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/images/battle_logo.png', width: 80, height: 80, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          Text('Welcome to BattleLM', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Add AI instances and create group chats to get started', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class _AIChatPane extends StatefulWidget {
  final AppState state;
  final AIInstance ai;
  const _AIChatPane({required this.state, required this.ai});

  @override
  State<_AIChatPane> createState() => _AIChatPaneState();
}

class _AIChatPaneState extends State<_AIChatPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _AIChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ai.id != widget.ai.id) {
      _controller.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.ai;
    final messages = ai.messages;
    final isThinking = widget.state.pendingAiResponses.contains(ai.id);

    return Column(
      children: [
        _AITopBar(state: widget.state, ai: ai),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (isThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (isThinking && index == messages.length) {
                return const _ThinkingBubble();
              }
              return MessageBubble(message: messages[index]);
            },
          ),
        ),
        const Divider(height: 1),
        _Composer(
          controller: _controller,
          trailing: ThinkingDots(isActive: isThinking),
          onSend: (text) => widget.state.sendUserMessageToAI(ai, text),
        ),
      ],
    );
  }
}

class _GroupChatPane extends StatefulWidget {
  final AppState state;
  final GroupChat chat;
  const _GroupChatPane({required this.state, required this.chat});

  @override
  State<_GroupChatPane> createState() => _GroupChatPaneState();
}

class _GroupChatPaneState extends State<_GroupChatPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _GroupChatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final messages = chat.messages;

    return Column(
      children: [
        _TopBar(title: chat.name, subtitle: '${chat.members.length} members'),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) => MessageBubble(message: messages[index]),
          ),
        ),
        const Divider(height: 1),
        _Composer(
          controller: _controller,
          trailing: ThinkingDots(isActive: false),
          onSend: (text) => widget.state.sendUserMessageToGroupChat(chat, text),
        ),
      ],
    );
  }
}

class _AITopBar extends StatelessWidget {
  final AppState state;
  final AIInstance ai;
  const _AITopBar({required this.state, required this.ai});

  @override
  Widget build(BuildContext context) {
    final models = ai.type.availableModels;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ai.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(ai.workingDirectory, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
              ],
            ),
          ),
          if (models.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: ai.selectedModel,
                  isDense: true,
                  borderRadius: BorderRadius.circular(10),
                  dropdownColor: const Color(0xFF151515),
                  onChanged: (v) => state.setAIModel(aiId: ai.id, modelId: v),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Default (${ai.resolvedDefaultModelId})', overflow: TextOverflow.ellipsis),
                    ),
                    ...models.map(
                      (m) => DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  const _TopBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Widget trailing;
  final ValueChanged<String> onSend;

  const _Composer({required this.controller, required this.trailing, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: const Color(0xFF171717),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (v) => _send(context),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _send(context),
            icon: const Icon(Icons.arrow_upward_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.all(14),
            ),
            tooltip: 'Send',
          ),
        ],
      ),
    );
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white12,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const ThinkingDots(isActive: true),
          ),
        ],
      ),
    );
  }
}

  void _send(BuildContext context) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    onSend(text);
  }
}
