import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/models.dart';
import 'widgets/sidebar_header.dart';
import 'widgets/sidebar_section_title.dart';
import 'widgets/status_dot.dart';

class SidebarView extends StatelessWidget {
  final AppState state;

  const SidebarView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          const SidebarHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                SidebarSectionTitle(
                  title: 'AI Instances',
                  trailing: IconButton(
                    onPressed: () => _showAddAIDialog(context),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'Add AI',
                  ),
                ),
                ...state.aiInstances.map((ai) => _AIItem(state: state, ai: ai)),
                const SizedBox(height: 14),
                SidebarSectionTitle(
                  title: 'Group Chats',
                  trailing: IconButton(
                    onPressed: () => _showCreateGroupDialog(context),
                    icon: const Icon(Icons.add_comment_outlined, size: 20),
                    tooltip: 'New Group Chat',
                  ),
                ),
                ...state.groupChats.map((chat) => _GroupItem(state: state, chat: chat)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _ConnectionPill(),
                const Spacer(),
                IconButton(
                  onPressed: () => _showSettingsDialog(context),
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Standalone Windows preview. Settings UI TBD.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showAddAIDialog(BuildContext context) {
    final name = TextEditingController();
    final cwd = TextEditingController(text: '~');
    AIType selected = AIType.claude;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('New AI Instance'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AIType>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder()),
                    items: AIType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                        .toList(),
                    onChanged: (v) => setState(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cwd,
                    decoration: const InputDecoration(labelText: 'Working directory', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  await state.addAI(type: selected, name: name.text.trim(), workingDirectory: cwd.text.trim());
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    if (state.aiInstances.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create Group Chat'),
          content: const Text('Add at least one AI instance first.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final name = TextEditingController(text: 'New Chat');
    final selectedIds = <String>{};

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('New Group Chat'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Members', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  ...state.aiInstances.map((ai) {
                    final checked = selectedIds.contains(ai.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          selectedIds.add(ai.id);
                        } else {
                          selectedIds.remove(ai.id);
                        }
                      }),
                      title: Text(ai.name),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        final members = state.aiInstances.where((a) => selectedIds.contains(a.id)).toList();
                        await state.addGroupChat(name: name.text.trim().isEmpty ? 'New Chat' : name.text.trim(), members: members);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AIItem extends StatelessWidget {
  final AppState state;
  final AIInstance ai;
  const _AIItem({required this.state, required this.ai});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedAiId == ai.id;
    return ListTile(
      dense: true,
      selected: selected,
      leading: const StatusDot(isOn: true),
      title: Text(ai.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(ai.workingDirectory, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
      onTap: () => state.selectAI(ai),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        tooltip: 'Remove',
        onPressed: () => state.removeAI(ai),
      ),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final AppState state;
  final GroupChat chat;
  const _GroupItem({required this.state, required this.chat});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedGroupChatId == chat.id;
    return ListTile(
      dense: true,
      selected: selected,
      leading: const Icon(Icons.forum_outlined, size: 18),
      title: Text(chat.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => state.selectGroupChat(chat),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        tooltip: 'Remove',
        onPressed: () => state.removeGroupChat(chat),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.green.withOpacity(0.15),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(isOn: true),
          SizedBox(width: 8),
          Text('Local', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}

