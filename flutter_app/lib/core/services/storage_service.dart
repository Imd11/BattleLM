import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local storage service
class StorageService {
  static const String _aiInstancesKey = 'ai_instances';
  static const String _groupChatsKey = 'group_chats';
  static const String _appSettingsKey = 'app_settings';
  static const String _pairedDevicesKey = 'paired_devices';

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize storage
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Save AI instances
  Future<void> saveAIInstances(List<AIInstance> instances) async {
    await _ensureInitialized();
    final json = jsonEncode(instances.map((i) => i.toJson()).toList());
    await _prefs.setString(_aiInstancesKey, json);
  }

  /// Load AI instances
  Future<List<AIInstance>> loadAIInstances() async {
    await _ensureInitialized();
    final json = _prefs.getString(_aiInstancesKey);
    if (json == null || json.isEmpty) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => AIInstance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading AI instances: $e');
      return [];
    }
  }

  /// Save group chats
  Future<void> saveGroupChats(List<GroupChat> chats) async {
    await _ensureInitialized();
    final json = jsonEncode(chats.map((c) => c.toJson()).toList());
    await _prefs.setString(_groupChatsKey, json);
  }

  /// Load group chats
  Future<List<GroupChat>> loadGroupChats() async {
    await _ensureInitialized();
    final json = _prefs.getString(_groupChatsKey);
    if (json == null || json.isEmpty) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading group chats: $e');
      return [];
    }
  }

  /// Save app settings
  Future<void> saveAppSettings(AppSettings settings) async {
    await _ensureInitialized();
    await _prefs.setString(_appSettingsKey, jsonEncode(settings.toJson()));
  }

  /// Load app settings
  Future<AppSettings> loadAppSettings() async {
    await _ensureInitialized();
    final json = _prefs.getString(_appSettingsKey);
    if (json == null || json.isEmpty) return AppSettings.defaults();

    try {
      return AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      print('Error loading app settings: $e');
      return AppSettings.defaults();
    }
  }

  /// Save paired devices
  Future<void> savePairedDevices(List<PairedDevice> devices) async {
    await _ensureInitialized();
    final json = jsonEncode(devices.map((d) => d.toJson()).toList());
    await _prefs.setString(_pairedDevicesKey, json);
  }

  /// Load paired devices
  Future<List<PairedDevice>> loadPairedDevices() async {
    await _ensureInitialized();
    final json = _prefs.getString(_pairedDevicesKey);
    if (json == null || json.isEmpty) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => PairedDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading paired devices: $e');
      return [];
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs.clear();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }
}

/// App settings model
class AppSettings extends Equatable {
  final String appearance; // system, light, dark
  final double fontSize;
  final bool showTokenUsage;
  final bool autoConnect;

  const AppSettings({
    this.appearance = 'system',
    this.fontSize = 14.0,
    this.showTokenUsage = true,
    this.autoConnect = false,
  });

  factory AppSettings.defaults() => const AppSettings();

  Map<String, dynamic> toJson() => {
        'appearance': appearance,
        'fontSize': fontSize,
        'showTokenUsage': showTokenUsage,
        'autoConnect': autoConnect,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        appearance: json['appearance'] as String? ?? 'system',
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
        showTokenUsage: json['showTokenUsage'] as bool? ?? true,
        autoConnect: json['autoConnect'] as bool? ?? false,
      );

  AppSettings copyWith({
    String? appearance,
    double? fontSize,
    bool? showTokenUsage,
    bool? autoConnect,
  }) {
    return AppSettings(
      appearance: appearance ?? this.appearance,
      fontSize: fontSize ?? this.fontSize,
      showTokenUsage: showTokenUsage ?? this.showTokenUsage,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  @override
  List<Object?> get props => [appearance, fontSize, showTokenUsage, autoConnect];
}

/// Paired device model
class PairedDevice extends Equatable {
  final String id;
  final String name;
  final String endpoint;
  final String? endpointLocal;
  final DateTime lastConnected;

  const PairedDevice({
    required this.id,
    required this.name,
    required this.endpoint,
    this.endpointLocal,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'endpoint': endpoint,
        'endpointLocal': endpointLocal,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        endpoint: json['endpoint'] as String,
        endpointLocal: json['endpointLocal'] as String?,
        lastConnected: DateTime.parse(json['lastConnected'] as String),
      );

  @override
  List<Object?> get props => [id, name, endpoint, endpointLocal, lastConnected];
}
