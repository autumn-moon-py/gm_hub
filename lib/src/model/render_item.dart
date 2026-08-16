import 'package:flutter/material.dart';

import 'project_model.dart';

class RenderItem {
  const RenderItem({
    required this.id,
    required this.name,
    required this.type,
    required this.lockedByAncestor,
    required this.visible,
    required this.worldPosition,
    required this.worldScale,
    required this.worldRotation,
    required this.opacity,
    required this.depth,
    this.assetPath,
    this.assetAbsolutePath,
    this.text,
    this.textFontSize,
    this.textColorValue,
    this.textHandleHeight = 0,
    this.preserveAspect = false,
    this.isBackground = false,
    required this.baseWidth,
    required this.baseHeight,
  });

  final String id;
  final String name;
  final NodeType type;
  final bool lockedByAncestor;
  final bool visible;
  final Offset worldPosition;
  final double worldScale;
  final double worldRotation;
  final double opacity;
  final int depth;
  final String? assetPath;
  final String? assetAbsolutePath;
  final String? text;
  final double? textFontSize;
  final int? textColorValue;
  final double textHandleHeight;
  final bool preserveAspect;
  final bool isBackground;
  final double baseWidth;
  final double baseHeight;
}
