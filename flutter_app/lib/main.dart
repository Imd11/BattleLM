import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/services.dart';
import 'features/home/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final storage = StorageService();
  await storage.init();

  runApp(BattleLMApp(storage: storage));
}

class BattleLMApp extends StatelessWidget {
  final StorageService storage;

  const BattleLMApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Provider<StorageService>.value(
      value: storage,
      child: MaterialApp(
        title: 'BattleLM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeView(),
      ),
    );
  }
}
