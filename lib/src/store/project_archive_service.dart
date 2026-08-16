import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';

import '../model/project_model.dart';

// 新格式 .gmh 的读取结果:模型 + 资源字节表 + manifest(可为空)
class ArchiveLoadResult {
  ArchiveLoadResult({
    required this.model,
    required this.assetMap,
    required this.manifest,
  });

  final ProjectModel model;
  final Map<String, List<int>> assetMap;
  final Map<String, dynamic> manifest;
}

// 解码 manifest.json,失败或非对象时回退为空 Map
Map<String, dynamic> _decodeManifest(List<int> bytes) {
  try {
    final text = utf8.decode(bytes);
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
  } catch (_) {
    // 忽略,后续会使用默认值
  }
  return <String, dynamic>{};
}

// 收集 assets/ 前缀的资源字节,key 为压缩包内的相对路径
Map<String, List<int>> _extractAssetMap(Archive archive) {
  final map = <String, List<int>>{};
  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    final name = entry.name;
    if (!name.startsWith('assets/')) {
      continue;
    }
    // 防路径穿越:拒绝含 .. 的条目名,避免解压时逃逸缓存目录
    if (name.contains('..')) {
      continue;
    }
    final bytes = entry.content as List<int>;
    map[name] = List<int>.unmodifiable(bytes);
  }
  return map;
}

class ProjectArchiveService {
  // 与 pubspec.yaml 的 version 字段保持一致
  static const String kToolVersion = '1.0.0';

  // 同步读取 .gmh(ZIP)并解析模型与资源
  static ArchiveLoadResult read(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? manifestEntry;
    ArchiveFile? projectEntry;
    for (final entry in archive) {
      if (entry.name == 'manifest.json') {
        manifestEntry = entry;
      } else if (entry.name == 'project.json') {
        projectEntry = entry;
      }
    }
    if (projectEntry == null) {
      throw const FormatException('新格式 .gmh 缺少 project.json 条目');
    }

    final manifest = manifestEntry != null
        ? _decodeManifest(manifestEntry.content as List<int>)
        : <String, dynamic>{};
    final jsonText = utf8.decode(projectEntry.content as List<int>);
    final jsonMap = jsonDecode(jsonText);
    if (jsonMap is! Map) {
      throw const FormatException('project.json 内容不是 JSON 对象');
    }
    final model = ProjectModel.fromJson(jsonMap.cast<String, dynamic>());

    return ArchiveLoadResult(
      model: model,
      assetMap: _extractAssetMap(archive),
      manifest: manifest,
    );
  }

  // 生成 manifest.json 的字节内容,标记为新格式(formatVersion=2)
  static List<int> _encodeManifest({
    required String toolVersion,
  }) {
    final manifest = <String, dynamic>{
      'formatVersion': 2,
      'toolName': 'GM Hub',
      'toolVersion': toolVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
  }

  // 同步构建 .gmh(ZIP)的字节内容:manifest + project.json + assets/*
  static List<int> buildBytes({
    required ProjectModel model,
    required Map<String, List<int>> assetMap,
    String toolVersion = kToolVersion,
  }) {
    final archive = Archive();

    final manifestBytes = _encodeManifest(toolVersion: toolVersion);
    archive.addFile(ArchiveFile(
      'manifest.json',
      manifestBytes.length,
      manifestBytes,
    ));

    final projectJson = const JsonEncoder.withIndent('  ')
        .convert(<String, dynamic>{
      'version': model.version,
      'formatVersion': model.formatVersion,
      'name': model.name,
      'canvas': {
        'width': model.canvas.width,
        'height': model.canvas.height,
      },
      'root': model.root.toJson(),
      'audio': {
        'tracks': model.tracks.map((e) => e.toJson()).toList(),
        'state': model.audioState.toJson(),
      },
      'uiState': model.uiState.toJson(),
    });
    final projectBytes = utf8.encode(projectJson);
    archive.addFile(ArchiveFile(
      'project.json',
      projectBytes.length,
      projectBytes,
    ));

    // 资源(图片/音频)本身已是压缩格式,ZIP 再压收益极小,直接 store 避免空耗 CPU
    assetMap.forEach((name, bytes) {
      archive.addFile(ArchiveFile(
        name,
        bytes.length,
        bytes,
      )..compress = false);
    });

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const FormatException('ZIP 编码失败');
    }
    return encoded;
  }

  // 在 isolate 中构建 ZIP 字节,避免大资源压缩阻塞 UI。
  // 注意:闭包必须在静态方法内创建且只捕获纯数据参数,
  // 否则会连带捕获调用方实例(如 ProjectStore 内的 AudioPlayer)导致跨 isolate 发送失败。
  static Future<List<int>> buildBytesInIsolate({
    required ProjectModel model,
    required Map<String, List<int>> assetMap,
    String toolVersion = kToolVersion,
  }) {
    return Isolate.run(
      () => buildBytes(
        model: model,
        assetMap: assetMap,
        toolVersion: toolVersion,
      ),
    );
  }

  // 同步写出 .gmh 文件到磁盘,自动创建父目录
  static void write({
    required String filePath,
    required ProjectModel model,
    required Map<String, List<int>> assetMap,
    String toolVersion = kToolVersion,
  }) {
    final bytes = buildBytes(
      model: model,
      assetMap: assetMap,
      toolVersion: toolVersion,
    );
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: true);
  }
}
