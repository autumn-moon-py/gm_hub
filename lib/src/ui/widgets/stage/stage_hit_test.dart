import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../model/project_model.dart';
import '../../../model/render_item.dart';

String? hitTestTopDown({
  required List<RenderItem> renderList,
  required Offset localPosition,
  required double scaleX,
  required double scaleY,
  bool useFullBoundsHit = false,
}) {
  final uniformScale = math.min(scaleX, scaleY);

  for (var i = renderList.length - 1; i >= 0; i--) {
    final item = renderList[i];
    if (!item.visible || item.opacity <= 0) {
      continue;
    }
    // Text nodes use Transform.scale for worldScale, so their rendered size
    // is baseWidth * worldScale (without viewport scaleX/scaleY).
    final isText = item.type == NodeType.text;
    final rect = Rect.fromLTWH(
      item.worldPosition.dx * scaleX,
      item.worldPosition.dy * scaleY,
      isText
          ? item.baseWidth * item.worldScale
          : item.baseWidth *
              item.worldScale *
              (item.preserveAspect ? uniformScale : scaleX),
      isText
          ? item.baseHeight * item.worldScale
          : item.baseHeight *
              item.worldScale *
              (item.preserveAspect ? uniformScale : scaleY),
    );
    final center = rect.center;
    final local = localPosition - center;
    final cosTheta = math.cos(-item.worldRotation);
    final sinTheta = math.sin(-item.worldRotation);
    final rotated = Offset(
      local.dx * cosTheta - local.dy * sinTheta,
      local.dx * sinTheta - local.dy * cosTheta,
    );
    final unrotatedPoint = center + rotated;
    if (!rect.contains(unrotatedPoint)) {
      continue;
    }
    return item.id;
  }
  return null;
}
