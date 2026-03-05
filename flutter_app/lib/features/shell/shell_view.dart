import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../sidebar/sidebar_view.dart';
import '../chat/chat_view.dart';

class ShellView extends StatelessWidget {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (!isWide) {
              // For now: use the same desktop layout but allow it to scroll.
              // Windows preview target is wide layout.
              return _DesktopLayout(state: state);
            }
            return _DesktopLayout(state: state);
          },
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final AppState state;
  const _DesktopLayout({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarView(state: state),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: ChatView(state: state),
          ),
        ],
      ),
    );
  }
}

