import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/storage_service.dart';
import 'app_state.dart';
import '../features/shell/shell_view.dart';
import '../core/local/local_engine.dart';

class BattleLMApp extends StatelessWidget {
  final StorageService storage;

  const BattleLMApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalEngine>(create: (_) => LocalEngine()),
        ChangeNotifierProvider(
          create: (ctx) => AppState(
            storage: storage,
            engine: ctx.read<LocalEngine>(),
          )..load(),
        ),
      ],
      child: MaterialApp(
        title: 'BattleLM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C4DFF),
            secondary: Color(0xFF7C4DFF),
            surface: Color(0xFF121212),
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0B0B),
          dividerColor: Colors.white12,
        ),
        home: const ShellView(),
      ),
    );
  }
}
