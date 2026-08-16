import 'dart:io';

import 'package:path/path.dart' as p;

/// 把"asset 字段引用"翻译成"可读盘的绝对路径"的统一抽象
/// 新老格式共用,后续 store 层只依赖此接口,不直接拼路径
abstract class AssetResolver {
  String? resolve(String? assetRef);
  bool canResolve(String? assetRef);
}

/// 老格式 resolver
/// asset 可能是绝对路径(外部导入)或相对路径(项目目录子路径)
class LegacyAssetResolver implements AssetResolver {
  LegacyAssetResolver(this.projectDir);

  final String? projectDir;

  @override
  String? resolve(String? assetRef) {
    if (assetRef == null || assetRef.isEmpty) {
      return null;
    }
    if (p.isAbsolute(assetRef)) {
      return p.normalize(assetRef);
    }
    if (projectDir == null || projectDir!.isEmpty) {
      return null;
    }
    return p.normalize(p.join(projectDir!, assetRef));
  }

  @override
  bool canResolve(String? assetRef) {
    if (assetRef == null || assetRef.isEmpty) {
      return false;
    }
    return p.isAbsolute(assetRef) || (projectDir != null && projectDir!.isNotEmpty);
  }
}

/// 新格式 resolver(.gmh 包)
/// asset 都是 ZIP 内的相对路径(如 assets/img_a1b2c3d4.png),需要拼到缓存目录
/// 绝对路径视为已迁移后的外部引用,直接透传
class EmbeddedAssetResolver implements AssetResolver {
  EmbeddedAssetResolver(this.cacheDir);

  final Directory cacheDir;

  @override
  String? resolve(String? assetRef) {
    if (assetRef == null || assetRef.isEmpty) {
      return null;
    }
    // 绝对路径视为已迁移后的外部引用,直接返回
    if (p.isAbsolute(assetRef)) {
      return p.normalize(assetRef);
    }
    // 含 .. 的相对路径视为非法,防止拼出缓存目录
    if (assetRef.contains('..')) {
      return null;
    }
    // 相对路径都视为 ZIP 内 assets/*,拼到缓存根
    return p.normalize(p.join(cacheDir.path, assetRef));
  }

  @override
  bool canResolve(String? assetRef) {
    if (assetRef == null || assetRef.isEmpty) {
      return false;
    }
    if (assetRef.contains('..')) {
      return false;
    }
    return p.isAbsolute(assetRef) || !assetRef.startsWith('/');
  }
}
