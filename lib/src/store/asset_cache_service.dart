import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../model/project_model.dart';

class _CacheMeta {
  _CacheMeta({
    required this.sourcePath,
    required this.sourceMtime,
    required this.sourceSize,
    required this.extractedAt,
  });

  final String sourcePath;
  final int sourceMtime;
  final int sourceSize;
  final int extractedAt;

  factory _CacheMeta.fromJson(Map<String, dynamic> json) {
    return _CacheMeta(
      sourcePath: (json['sourcePath'] as String?) ?? '',
      sourceMtime: (json['sourceMtime'] as num?)?.toInt() ?? 0,
      sourceSize: (json['sourceSize'] as num?)?.toInt() ?? 0,
      extractedAt: (json['extractedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'sourcePath': sourcePath,
        'sourceMtime': sourceMtime,
        'sourceSize': sourceSize,
        'extractedAt': extractedAt,
      };
}

class AssetCacheService {
  static Directory get _cacheRoot {
    final appData = Platform.environment['APPDATA'];
    final base = (appData == null || appData.isEmpty)
        ? Directory.current.path
        : appData;
    final dir = Directory(p.join(base, 'gm_hub', 'project_cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static String _computeCacheKey(String projectFilePath) {
    // Windows 路径不区分大小写,统一小写避免同一文件产生多份缓存
    final canonical =
        p.canonicalize(projectFilePath).replaceAll('\\', '/').toLowerCase();
    final bytes = utf8.encode(canonical);
    return sha256.convert(bytes).toString();
  }

  static Directory _cacheDir(String projectFilePath) {
    return Directory(p.join(_cacheRoot.path, _computeCacheKey(projectFilePath)));
  }

  static Directory? tryGetValidCache(String projectFilePath) {
    final sourceFile = File(projectFilePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    final cacheDir = _cacheDir(projectFilePath);
    if (!cacheDir.existsSync()) {
      return null;
    }
    // 资源目录缺失视为缓存不完整,需要重新解压
    if (!Directory(p.join(cacheDir.path, 'assets')).existsSync()) {
      return null;
    }
    final metaFile = File(p.join(cacheDir.path, '.gmh_cache_meta'));
    if (!metaFile.existsSync()) {
      return null;
    }
    try {
      final stat = sourceFile.statSync();
      final meta = _CacheMeta.fromJson(
        (jsonDecode(metaFile.readAsStringSync()) as Map).cast<String, dynamic>(),
      );
      if (meta.sourcePath != sourceFile.path ||
          meta.sourceMtime != stat.modified.millisecondsSinceEpoch ||
          meta.sourceSize != stat.size) {
        return null;
      }
      return cacheDir;
    } catch (_) {
      return null;
    }
  }

  static async_lib.Future<Directory> extract({
    required String projectFilePath,
    required Map<String, List<int>> assetMap,
    required ProjectModel model,
  }) async {
    final sourceFile = File(projectFilePath);
    final stat = sourceFile.statSync();

    final cacheDir = _cacheDir(projectFilePath);
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }
    await cacheDir.create(recursive: true);

    // project.json 副本(供调试,运行时从内存读取)
    final jsonFile = File(p.join(cacheDir.path, 'project.json'));
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'version': model.version,
        'formatVersion': model.formatVersion,
        'name': model.name,
      }),
      flush: true,
    );

    // 资源写入
    final assetsDir = Directory(p.join(cacheDir.path, 'assets'));
    await assetsDir.create(recursive: true);
    for (final entry in assetMap.entries) {
      // 防路径穿越:条目名拼出缓存目录之外的直接跳过
      final targetPath = p.normalize(p.join(cacheDir.path, entry.key));
      if (!targetPath.startsWith(cacheDir.path + p.separator)) {
        debugPrint('asset_cache 跳过越界资源条目: ${entry.key}');
        continue;
      }
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }

    await File(p.join(cacheDir.path, '.gmh_cache_meta')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        _CacheMeta(
          sourcePath: sourceFile.path,
          sourceMtime: stat.modified.millisecondsSinceEpoch,
          sourceSize: stat.size,
          extractedAt: DateTime.now().millisecondsSinceEpoch,
        ).toJson(),
      ),
      flush: true,
    );
    return cacheDir;
  }

  static void invalidate(String projectFilePath) {
    final cacheDir = _cacheDir(projectFilePath);
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  }

  static void clearAll() {
    final root = _cacheRoot;
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}
