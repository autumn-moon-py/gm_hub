import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../model/battle_model.dart';
import '../model/project_model.dart';
import '../model/render_item.dart';
import '../store/project_store.dart';

class SyncFlowMessage {
  const SyncFlowMessage({
    required this.id,
    required this.text,
    required this.colorValue,
  });

  final String id;
  final String text;
  final int colorValue;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'colorValue': colorValue,
    };
  }
}

class SyncRenderPayload {
  const SyncRenderPayload({
    required this.renderList,
    required this.flowMessages,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.outputScaleMode,
    required this.currentMode,
    required this.battle,
  });

  final List<RenderItem> renderList;
  final List<SyncFlowMessage> flowMessages;
  final double canvasWidth;
  final double canvasHeight;
  final String outputScaleMode;
  final ProjectMode currentMode;
  final SyncBattlePayload? battle;

  factory SyncRenderPayload.fromStore(ProjectStore store) {
    final isBattle = store.project.currentMode == ProjectMode.battle;
    return SyncRenderPayload(
      renderList: isBattle
          ? store.buildRenderListForNode('group_background')
          : store.buildRenderList(),
      flowMessages: store.flowMessages
          .map(
            (item) => SyncFlowMessage(
              id: item.id,
              text: item.text,
              colorValue: item.color.toARGB32(),
            ),
          )
          .toList(growable: false),
      canvasWidth: store.project.canvas.width,
      canvasHeight: store.project.canvas.height,
      outputScaleMode: store.outputScaleMode,
      currentMode: store.project.currentMode,
      battle: SyncBattlePayload.fromStore(store),
    );
  }

  factory SyncRenderPayload.tryParse(
    Object? raw, {
    required double fallbackCanvasWidth,
    required double fallbackCanvasHeight,
    required String fallbackScaleMode,
    required ProjectMode fallbackCurrentMode,
    required SyncBattlePayload? fallbackBattle,
  }) {
    final args = raw;
    if (args is! Map) {
      throw const FormatException('sync_render 参数类型异常');
    }

    var nextCanvasWidth = fallbackCanvasWidth;
    var nextCanvasHeight = fallbackCanvasHeight;

    final rawCanvas = args['canvas'];
    if (rawCanvas is Map) {
      final w = rawCanvas['width'];
      final h = rawCanvas['height'];
      if (w is num) {
        final nextW = w.toDouble();
        if (nextW.isFinite && nextW > 0) {
          nextCanvasWidth = nextW;
        }
      }
      if (h is num) {
        final nextH = h.toDouble();
        if (nextH.isFinite && nextH > 0) {
          nextCanvasHeight = nextH;
        }
      }
    }

    var nextScaleMode =
        fallbackScaleMode.toLowerCase() == 'contain' ? 'contain' : 'stretch';
    final rawScaleMode = (args['outputScaleMode'] as String?)?.toLowerCase();
    if (rawScaleMode != null) {
      nextScaleMode = rawScaleMode == 'contain' ? 'contain' : 'stretch';
    }

    var nextRenderList = const <RenderItem>[];
    final rawRender = args['render'];
    if (rawRender is List) {
      nextRenderList =
          rawRender.whereType<Map>().map(_parseRenderItem).toList();
    }

    var nextFlowMessages = const <SyncFlowMessage>[];
    final rawFlowMessages = args['flowMessages'];
    if (rawFlowMessages is List) {
      nextFlowMessages =
          rawFlowMessages.whereType<Map>().map(_parseFlowMessage).toList();
    }

    final nextCurrentMode = args.containsKey('currentMode')
        ? projectModeFromJson(args['currentMode'])
        : fallbackCurrentMode;
    final rawBattle = args['battle'];
    final nextBattle = args.containsKey('battle')
        ? (rawBattle is Map
              ? SyncBattlePayload.tryParse(rawBattle)
              : null)
        : fallbackBattle;

    return SyncRenderPayload(
      renderList: nextRenderList,
      flowMessages: nextFlowMessages,
      canvasWidth: nextCanvasWidth,
      canvasHeight: nextCanvasHeight,
      outputScaleMode: nextScaleMode,
      currentMode: nextCurrentMode,
      battle: nextBattle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'render': renderList.map(_renderItemToMap).toList(),
      'flowMessages': flowMessages.map((item) => item.toMap()).toList(),
      'canvas': {
        'width': canvasWidth,
        'height': canvasHeight,
      },
      'outputScaleMode': outputScaleMode,
      'currentMode': currentMode.name,
      'battle': battle?.toMap(),
    };
  }

  static Map<String, dynamic> _renderItemToMap(RenderItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'type': item.type.name,
      'visible': item.visible,
      'x': item.worldPosition.dx,
      'y': item.worldPosition.dy,
      'scale': item.worldScale,
      'rotation': item.worldRotation,
      'opacity': item.opacity,
      'depth': item.depth,
      'baseWidth': item.baseWidth,
      'baseHeight': item.baseHeight,
      'text': item.text,
      'textFontSize': item.textFontSize,
      'textColorValue': item.textColorValue,
      'textHandleHeight': item.textHandleHeight,
      'preserveAspect': item.preserveAspect,
      'isBackground': item.isBackground,
      'assetAbsolutePath': item.assetAbsolutePath,
    };
  }
}

class SyncBattleEntityView {
  const SyncBattleEntityView({
    required this.id,
    required this.name,
    required this.assetAbsolutePath,
    required this.markers,
    required this.isCurrentActor,
    required this.isForeground,
    required this.kind,
    required this.state,
  });

  final String id;
  final String name;
  final String? assetAbsolutePath;
  final List<String> markers;
  final bool isCurrentActor;
  final bool isForeground;
  final BattleEntityKind kind;
  final String state;

  factory SyncBattleEntityView.fromBattleEntity({
    required ProjectStore store,
    required BattleEntityModel entity,
    required String? effectiveCurrentActorId,
    required String? effectiveForegroundPlayerId,
    required String? effectiveForegroundNpcId,
  }) {
    final effectiveForegroundId = entity.kind == BattleEntityKind.player
        ? effectiveForegroundPlayerId
        : effectiveForegroundNpcId;
    return SyncBattleEntityView(
      id: entity.id,
      name: entity.displayName,
      assetAbsolutePath: _resolveBattleEntityAssetAbsolutePath(store, entity),
      markers: List<String>.unmodifiable(entity.markers),
      isCurrentActor: entity.id == effectiveCurrentActorId,
      isForeground: entity.id == effectiveForegroundId,
      kind: entity.kind,
      state: entity.state.name,
    );
  }

  factory SyncBattleEntityView.tryParse(Map<dynamic, dynamic> raw) {
    return SyncBattleEntityView(
      id: raw['id']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      assetAbsolutePath: raw['assetAbsolutePath'] as String?,
      markers: _readStringList(raw['markers']),
      isCurrentActor: _readBool(raw['isCurrentActor']),
      isForeground: _readBool(raw['isForeground']),
      kind: battleEntityKindFromJson(raw['kind']),
      state: raw['state']?.toString() ?? BattleEntityState.standby.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'assetAbsolutePath': assetAbsolutePath,
      'markers': markers,
      'isCurrentActor': isCurrentActor,
      'isForeground': isForeground,
      'kind': kind.name,
      'state': state,
    };
  }
}

class SyncBattlePayload {
  const SyncBattlePayload({
    required this.showingBattle,
    required this.entities,
    required this.animTriggerId,
    required this.animActiveEntityId,
    required this.animTargetEntityId,
    required this.animActiveAction,
    required this.animTargetAction,
  });

  final bool showingBattle;
  final List<SyncBattleEntityView> entities;
  final int animTriggerId;
  final String? animActiveEntityId;
  final String? animTargetEntityId;
  final BattleAnimAction? animActiveAction;
  final BattleAnimAction? animTargetAction;

  factory SyncBattlePayload.fromStore(ProjectStore store) {
    final workspace = store.project.battle.workspace;
    final anim = store.project.battle.animation;
    final effectiveCurrentActorId = _resolveEffectiveCurrentActorId(workspace);
    final effectiveForegroundPlayerId = _resolveEffectiveForegroundId(
      workspace: workspace,
      kind: BattleEntityKind.player,
      effectiveCurrentActorId: effectiveCurrentActorId,
    );
    final effectiveForegroundNpcId = _resolveEffectiveForegroundId(
      workspace: workspace,
      kind: BattleEntityKind.npc,
      effectiveCurrentActorId: effectiveCurrentActorId,
    );
    final entities = workspace.entities
        .map(
          (entity) => SyncBattleEntityView.fromBattleEntity(
            store: store,
            entity: entity,
            effectiveCurrentActorId: effectiveCurrentActorId,
            effectiveForegroundPlayerId: effectiveForegroundPlayerId,
            effectiveForegroundNpcId: effectiveForegroundNpcId,
          ),
        )
        .toList(growable: false);
    return SyncBattlePayload(
      showingBattle: workspace.outputShowingBattle,
      entities: entities,
      animTriggerId: anim.triggerId,
      animActiveEntityId: anim.activeEntityId,
      animTargetEntityId: anim.targetEntityId,
      animActiveAction: anim.activeAction,
      animTargetAction: anim.targetAction,
    );
  }

  factory SyncBattlePayload.tryParse(Map<dynamic, dynamic> raw) {
    final rawEntities = raw['entities'];
    return SyncBattlePayload(
      showingBattle: _readBool(raw['showingBattle']),
      entities: rawEntities is List
          ? rawEntities
                .whereType<Map>()
                .map(SyncBattleEntityView.tryParse)
                .toList(growable: false)
          : const [],
      animTriggerId: _readJsonInt(raw['animTriggerId'], fallback: 0),
      animActiveEntityId: raw['animActiveEntityId']?.toString(),
      animTargetEntityId: raw['animTargetEntityId']?.toString(),
      animActiveAction: _animActionFromJson(raw['animActiveAction']),
      animTargetAction: _animActionFromJson(raw['animTargetAction']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showingBattle': showingBattle,
      'entities': entities.map((item) => item.toMap()).toList(),
      'animTriggerId': animTriggerId,
      'animActiveEntityId': animActiveEntityId,
      'animTargetEntityId': animTargetEntityId,
      'animActiveAction': animActiveAction?.name,
      'animTargetAction': animTargetAction?.name,
    };
  }
}

BattleAnimAction? _animActionFromJson(dynamic value) {
  final raw = (value as String?)?.toLowerCase();
  if (raw == BattleAnimAction.attack.name) return BattleAnimAction.attack;
  if (raw == BattleAnimAction.dodge.name) return BattleAnimAction.dodge;
  if (raw == BattleAnimAction.counter.name) return BattleAnimAction.counter;
  return null;
}

int _readJsonInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback;
}

SyncFlowMessage _parseFlowMessage(Map<dynamic, dynamic> m) {
  return SyncFlowMessage(
    id: m['id']?.toString() ?? '',
    text: m['text']?.toString() ?? '',
    colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
  );
}

RenderItem _parseRenderItem(Map<dynamic, dynamic> m) {
  return RenderItem(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    type: NodeType.values.firstWhere(
      (v) => v.name == (m['type']?.toString() ?? ''),
      orElse: () => NodeType.image,
    ),
    lockedByAncestor: (m['lockedByAncestor'] as bool?) ?? false,
    visible: (m['visible'] as bool?) ?? true,
    worldPosition: Offset(
      ((m['x'] as num?) ?? 0).toDouble(),
      ((m['y'] as num?) ?? 0).toDouble(),
    ),
    worldScale: ((m['scale'] as num?) ?? 1).toDouble(),
    worldRotation: ((m['rotation'] as num?) ?? 0).toDouble(),
    opacity: ((m['opacity'] as num?) ?? 1).toDouble(),
    depth: ((m['depth'] as num?) ?? 0).toInt(),
    baseWidth: ((m['baseWidth'] as num?) ?? 220).toDouble(),
    baseHeight: ((m['baseHeight'] as num?) ?? 140).toDouble(),
    text: m['text'] as String?,
    textFontSize: ((m['textFontSize'] as num?) ?? 34).toDouble(),
    textColorValue: (m['textColorValue'] as num?)?.toInt(),
    textHandleHeight: ((m['textHandleHeight'] as num?) ?? 0).toDouble(),
    preserveAspect: (m['preserveAspect'] as bool?) ?? false,
    isBackground: (m['isBackground'] as bool?) ?? false,
    assetAbsolutePath: m['assetAbsolutePath'] as String?,
  );
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

String? _resolveEffectiveCurrentActorId(BattleWorkspaceModel workspace) {
  for (final entity in workspace.entities) {
    if (entity.isCurrentActor && entity.id.isNotEmpty) {
      return entity.id;
    }
  }
  return null;
}

String? _resolveEffectiveForegroundId({
  required BattleWorkspaceModel workspace,
  required BattleEntityKind kind,
  required String? effectiveCurrentActorId,
}) {
  for (final entity in workspace.entities) {
    if (entity.kind == kind && entity.isForeground && entity.id.isNotEmpty) {
      return entity.id;
    }
  }
  if (effectiveCurrentActorId != null) {
    for (final entity in workspace.entities) {
      if (entity.id == effectiveCurrentActorId && entity.kind == kind) {
        return entity.id;
      }
    }
  }
  for (final entity in workspace.entities) {
    if (entity.kind == kind && entity.id.isNotEmpty) {
      return entity.id;
    }
  }
  return null;
}

String? _resolveBattleEntityAssetAbsolutePath(
  ProjectStore store,
  BattleEntityModel entity,
) {
  final battle = store.project.battle;
  String? assetPath;
  if (entity.kind == BattleEntityKind.npc) {
    for (final template in battle.library.npcTemplates) {
      if (template.id == entity.resourceId) {
        assetPath = template.portrait?.asset;
        break;
      }
    }
  } else {
    for (final resource in battle.library.playerResources) {
      if (resource.id == entity.resourceId) {
        assetPath = resource.portrait?.asset;
        break;
      }
    }
  }
  final trimmed = assetPath?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (p.isAbsolute(trimmed)) {
    return p.normalize(trimmed);
  }
  final projectDirPath = store.projectDirPath;
  if (projectDirPath == null || projectDirPath.isEmpty) {
    return null;
  }
  return p.normalize(p.join(projectDirPath, trimmed));
}
