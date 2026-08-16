import 'dart:async' as async_lib;
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../model/project_model.dart';
import 'asset_cache_service.dart';
import 'asset_resolver.dart';
import 'project_archive_service.dart';

class ProjectLoadResult {
  ProjectLoadResult({
    required this.model,
    required this.resolver,
    required this.assetMap,
  });

  final ProjectModel model;
  final AssetResolver resolver;
  final Map<String, List<int>> assetMap;
}

enum _ProjectFormat { zip, legacy, unknown }

_ProjectFormat _detectFormat(List<int> head) {
  if (head.length >= 4 &&
      head[0] == 0x50 &&
      head[1] == 0x4B &&
      head[2] == 0x03 &&
      head[3] == 0x04) {
    return _ProjectFormat.zip;
  }
  if (head.length >= 2 && head[0] == 0x1F && head[1] == 0x8B) {
    return _ProjectFormat.legacy;
  }
  if (head.isNotEmpty && head[0] == 0x7B) {
    return _ProjectFormat.legacy;
  }
  return _ProjectFormat.unknown;
}

class ProjectFileService {
  static const String projectFileExtension = 'gmh';
  static const String projectFileDotExtension = '.gmh';
  static const String defaultProjectFileName =
      'untitled$projectFileDotExtension';
  static const String legacyProjectFileName = 'project.json';

  async_lib.Future<ProjectLoadResult?> loadProject(String projectFilePath) async {
    final file = File(projectFilePath);
    if (!file.existsSync()) {
      return null;
    }

    final raf = file.openSync();
    List<int> head;
    try {
      head = raf.readSync(4);
      raf.closeSync();
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      return null;
    }

    final format = _detectFormat(head);
    switch (format) {
      case _ProjectFormat.zip:
        return _loadFromZip(projectFilePath);
      case _ProjectFormat.legacy:
        return _loadFromLegacy(projectFilePath);
      case _ProjectFormat.unknown:
        return null;
    }
  }

  async_lib.Future<void> saveProject(
    String projectFilePath,
    ProjectModel project, {
    Map<String, List<int>>? assetBytes,
  }) async {
    await _ensureSaveParentExists(projectFilePath);
    if (project.formatVersion == 2) {
      await _writeZip(
        projectFilePath,
        project,
        assetBytes ?? const <String, List<int>>{},
      );
      return;
    }
    await _writeProjectFile(projectFilePath, project);
  }

  async_lib.Future<void> _writeZip(
    String projectFilePath,
    ProjectModel project,
    Map<String, List<int>> assetBytes,
  ) async {
    final bytes = await ProjectArchiveService.buildBytesInIsolate(
      model: project,
      assetMap: assetBytes,
    );
    final file = File(projectFilePath);
    await file.writeAsBytes(bytes, flush: true);
  }

  void saveProjectSync(
    String projectFilePath,
    ProjectModel project,
  ) {
    if (project.formatVersion == 2) {
      // 新格式必须走 ZIP 容器,同步路径仅支持老格式
      throw StateError('新格式(formatVersion=2)项目必须通过 saveProject 走 ZIP 保存');
    }
    _ensureSaveParentExistsSync(projectFilePath);
    _writeProjectFileSync(projectFilePath, project);
  }

  async_lib.Future<ProjectLoadResult?> _loadFromZip(
    String projectFilePath,
  ) async {
    try {
      final result = ProjectArchiveService.read(projectFilePath);
      final cacheDir = AssetCacheService.tryGetValidCache(projectFilePath) ??
          await AssetCacheService.extract(
            projectFilePath: projectFilePath,
            assetMap: result.assetMap,
            model: result.model,
          );
      return ProjectLoadResult(
        model: result.model,
        resolver: EmbeddedAssetResolver(cacheDir),
        assetMap: result.assetMap,
      );
    } catch (e, st) {
      // ZIP 解析或解压失败,视为无法读取;打印原因便于排查
      debugPrint('loadProject ZIP 解析失败($projectFilePath): $e\n$st');
      return null;
    }
  }

  ProjectLoadResult? _loadFromLegacy(String projectFilePath) {
    final file = File(projectFilePath);
    final bytes = file.readAsBytesSync();
    final decoded = _decodeProjectJson(bytes);
    if (decoded is! Map) {
      return null;
    }
    final model = ProjectModel.fromJson(decoded.cast<String, dynamic>());
    return ProjectLoadResult(
      model: model,
      resolver: LegacyAssetResolver(p.dirname(projectFilePath)),
      assetMap: const <String, List<int>>{},
    );
  }

  async_lib.Future<void> _ensureSaveParentExists(String projectFilePath) async {
    final file = File(projectFilePath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
  }

  void _ensureSaveParentExistsSync(String projectFilePath) {
    final file = File(projectFilePath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
  }

  async_lib.Future<void> _writeProjectFile(
    String projectFilePath,
    ProjectModel project,
  ) async {
    final ext = p.extension(projectFilePath).toLowerCase();
    if (ext == '.json') {
      final jsonText = await Isolate.run(() => project.toPrettyJson());
      final file = File(projectFilePath);
      await file.writeAsString(jsonText);
      return;
    }
    final compressed = await Isolate.run(() {
      final jsonText = project.toPrettyJson();
      return gzip.encode(utf8.encode(jsonText));
    });
    final file = File(projectFilePath);
    await file.writeAsBytes(compressed, flush: true);
  }

  void _writeProjectFileSync(
    String projectFilePath,
    ProjectModel project,
  ) {
    final file = File(projectFilePath);
    final jsonText = project.toPrettyJson();
    final ext = p.extension(projectFilePath).toLowerCase();
    if (ext == '.json') {
      file.writeAsStringSync(jsonText, flush: true);
      return;
    }
    final compressed = gzip.encode(utf8.encode(jsonText));
    file.writeAsBytesSync(compressed, flush: true);
  }

  async_lib.Future<String> importImageFile(String sourcePath) async {
    return p.normalize(sourcePath);
  }

  async_lib.Future<String> importAudioFile(String sourcePath) async {
    return p.normalize(sourcePath);
  }

  dynamic _decodeProjectJson(List<int> rawBytes) {
    try {
      final uncompressed = gzip.decode(rawBytes);
      final text = utf8.decode(uncompressed);
      return jsonDecode(text);
    } catch (_) {
      // Ignore and fallback to plain JSON decoding.
    }
    try {
      final text = utf8.decode(rawBytes);
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
