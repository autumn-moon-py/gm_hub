import 'package:flutter/material.dart';

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
  });

  final List<RenderItem> renderList;
  final List<SyncFlowMessage> flowMessages;
  final double canvasWidth;
  final double canvasHeight;
  final String outputScaleMode;

  factory SyncRenderPayload.fromStore(ProjectStore store) {
    return SyncRenderPayload(
      renderList: store.buildRenderList(),
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
    );
  }

  factory SyncRenderPayload.tryParse(
    Object? raw, {
    required double fallbackCanvasWidth,
    required double fallbackCanvasHeight,
    required String fallbackScaleMode,
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

    return SyncRenderPayload(
      renderList: nextRenderList,
      flowMessages: nextFlowMessages,
      canvasWidth: nextCanvasWidth,
      canvasHeight: nextCanvasHeight,
      outputScaleMode: nextScaleMode,
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
      'assetAbsolutePath': item.assetAbsolutePath,
    };
  }
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
    assetAbsolutePath: m['assetAbsolutePath'] as String?,
  );
}
