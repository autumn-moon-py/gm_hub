import 'dart:async' as async_lib;
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../model/project_model.dart';

enum MissingAssetChoice {
  skip,
  abort,
}

class AssetRefEntry {
  AssetRefEntry({required this.absolutePath, required this.kind});

  final String absolutePath;
  final AssetRefKind kind;
}

enum AssetRefKind { image, audio, portrait }

class MigrateResult {
  MigrateResult({required this.model, required this.assetMap});

  final ProjectModel model;
  final Map<String, List<int>> assetMap;
}

class ProjectMigrator {
  static List<AssetRefEntry> collectAssetRefs(ProjectModel model) {
    final refs = <AssetRefEntry>[];
    void visit(NodeModel node) {
      if (node.type == NodeType.image &&
          node.asset != null &&
          node.asset!.isNotEmpty) {
        refs.add(AssetRefEntry(absolutePath: node.asset!, kind: AssetRefKind.image));
      }
      for (final c in node.children) {
        visit(c);
      }
    }

    visit(model.root);
    for (final track in model.tracks) {
      if (track.asset.isNotEmpty) {
        refs.add(AssetRefEntry(absolutePath: track.asset, kind: AssetRefKind.audio));
      }
    }
    // battle 立绘引用(battle.library 的 npcTemplates/playerResources)
    for (final t in model.battle.library.npcTemplates) {
      final a = t.portrait?.asset;
      if (a != null && a.isNotEmpty) {
        refs.add(AssetRefEntry(absolutePath: a, kind: AssetRefKind.portrait));
      }
    }
    for (final r in model.battle.library.playerResources) {
      final a = r.portrait?.asset;
      if (a != null && a.isNotEmpty) {
        refs.add(AssetRefEntry(absolutePath: a, kind: AssetRefKind.portrait));
      }
    }
    return refs;
  }

  static List<String> findMissing(List<AssetRefEntry> refs) {
    final missing = <String>[];
    for (final ref in refs) {
      if (!File(ref.absolutePath).existsSync()) {
        if (!missing.contains(ref.absolutePath)) {
          missing.add(ref.absolutePath);
        }
      }
    }
    return missing;
  }

  static String _buildAssetKey({
    required List<int> bytes,
    required String sourcePath,
    required AssetRefKind kind,
  }) {
    final hash = sha256.convert(bytes).toString().substring(0, 8);
    final ext = p.extension(sourcePath);
    final prefix = kind == AssetRefKind.audio ? 'audio' : 'img';
    return 'assets/${prefix}_$hash$ext';
  }

  // 原始引用 → 新 key(缺失资源为 '')
  static ProjectModel _relinkModel({
    required ProjectModel model,
    required Map<String, String> oldToNew,
    required Map<String, String> origToNorm,
  }) {
    String? relink(String? original) {
      if (original == null || original.isEmpty) {
        return original;
      }
      final norm = origToNorm[original] ?? original;
      return oldToNew[norm] ?? original;
    }

    NodeModel visit(NodeModel node) {
      final newAsset = node.type == NodeType.image ? relink(node.asset) : node.asset;
      return node.copyWith(
        asset: newAsset,
        children: node.children.map(visit).toList(),
      );
    }

    final newRoot = visit(model.root);
    final newTracks = model.tracks
        .map((t) => t.copyWith(asset: relink(t.asset)))
        .toList();
    return model.copyWith(
      formatVersion: 2,
      root: newRoot,
      tracks: newTracks,
    );
  }

  // 纯函数:读字节 + 生成 assetMap + oldToNew(可在 isolate 中运行)
  static ({Map<String, List<int>> assetMap, Map<String, String> oldToNew})
      _readAssets(List<AssetRefEntry> presentRefs) {
    final assetMap = <String, List<int>>{};
    final oldToNew = <String, String>{};
    for (final ref in presentRefs) {
      try {
        final bytes = File(ref.absolutePath).readAsBytesSync();
        final newKey = _buildAssetKey(
          bytes: bytes,
          sourcePath: ref.absolutePath,
          kind: ref.kind,
        );
        assetMap[newKey] = bytes;
        // 多引用同源时,旧路径都映射到同一新 key
        oldToNew[ref.absolutePath] = newKey;
      } catch (e) {
        // 单文件读取失败(权限/被占用)不阻断整体迁移,置空该引用
        debugPrint('迁移读取资源失败,将置空该引用: ${ref.absolutePath} ($e)');
        oldToNew[ref.absolutePath] = '';
      }
    }
    return (assetMap: assetMap, oldToNew: oldToNew);
  }

  static async_lib.Future<MigrateResult> migrate({
    required ProjectModel model,
    required String projectFilePath,
    required async_lib.Future<MissingAssetChoice> Function(List<String> missing)
        onMissingChoice,
  }) async {
    final refs = collectAssetRefs(model);
    // 相对路径统一按项目目录归一化,避免相对进程 cwd 误判/读错
    final projectDir = p.dirname(projectFilePath);
    final origToNorm = <String, String>{};
    final normalizedRefs = refs.map((r) {
      final abs = p.isAbsolute(r.absolutePath)
          ? p.normalize(r.absolutePath)
          : p.normalize(p.join(projectDir, r.absolutePath));
      origToNorm[r.absolutePath] = abs;
      return AssetRefEntry(absolutePath: abs, kind: r.kind);
    }).toList();

    final missing = findMissing(normalizedRefs);
    debugPrint(
      'ProjectMigrator: 收集 ${refs.length} 个资源引用, 缺失 ${missing.length} 个',
    );
    if (missing.isNotEmpty) {
      debugPrint('ProjectMigrator 缺失资源列表:\n${missing.join('\n')}');
      final choice = await onMissingChoice(missing);
      if (choice == MissingAssetChoice.abort) {
        throw const MigrationAbortedException();
      }
    }
    final presentRefs =
        normalizedRefs.where((r) => File(r.absolutePath).existsSync()).toList();

    // 读字节在 isolate 中执行,避免阻塞 UI
    final readResult = await Isolate.run(() => _readAssets(presentRefs));
    final assetMap = readResult.assetMap;
    final oldToNew = readResult.oldToNew;

    // 丢失资源置空
    for (final m in missing) {
      oldToNew[m] = '';
    }

    final newModel = _relinkModel(
      model: model,
      oldToNew: oldToNew,
      origToNorm: origToNorm,
    );
    return MigrateResult(model: newModel, assetMap: assetMap);
  }
}

// 公共异常:UI 层可据类型感知用户主动取消迁移
class MigrationAbortedException implements Exception {
  const MigrationAbortedException();

  @override
  String toString() => 'Migration aborted by user';
}
