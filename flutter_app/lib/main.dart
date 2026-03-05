import 'package:flutter/material.dart';
import 'core/services/storage_service.dart';
import 'app/battlelm_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  final storage = StorageService();
  await storage.init();

  runApp(BattleLMApp(storage: storage));
}
