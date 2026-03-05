import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AssetBridge {
  AssetBridge._();

  static final AssetBridge shared = AssetBridge._();

  final Map<String, Future<File>> _cache = {};

  Future<File> ensureExtracted(String assetPath, {String? fileName}) {
    return _cache.putIfAbsent(assetPath, () async {
      final bytes = await rootBundle.load(assetPath);
      final dir = await getApplicationSupportDirectory();
      final outDir = Directory('${dir.path}/bridge');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final name = fileName ?? assetPath.split('/').last;
      final outFile = File('${outDir.path}/$name');
      await outFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return outFile;
    });
  }
}

