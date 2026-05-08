import 'package:flutter/material.dart';

import '../model/render_item.dart';

class OutputLayoutMetrics {
  const OutputLayoutMetrics({
    required this.renderScaleX,
    required this.renderScaleY,
    required this.offsetX,
    required this.offsetY,
  });

  final double renderScaleX;
  final double renderScaleY;
  final double offsetX;
  final double offsetY;
}

OutputLayoutMetrics computeOutputLayout({
  required BoxConstraints constraints,
  required double canvasWidth,
  required double canvasHeight,
  required String outputScaleMode,
}) {
  final safeCanvasW =
      (canvasWidth.isFinite && canvasWidth > 0) ? canvasWidth : 1.0;
  final safeCanvasH =
      (canvasHeight.isFinite && canvasHeight > 0) ? canvasHeight : 1.0;
  final scaleX = constraints.maxWidth / safeCanvasW;
  final scaleY = constraints.maxHeight / safeCanvasH;
  final containScale = scaleX < scaleY ? scaleX : scaleY;
  final useContain = outputScaleMode != 'stretch';
  final renderScaleX = useContain ? containScale : scaleX;
  final renderScaleY = useContain ? containScale : scaleY;
  final offsetX = useContain
      ? (constraints.maxWidth - safeCanvasW * containScale) / 2
      : 0.0;
  final offsetY = useContain
      ? (constraints.maxHeight - safeCanvasH * containScale) / 2
      : 0.0;
  return OutputLayoutMetrics(
    renderScaleX: renderScaleX,
    renderScaleY: renderScaleY,
    offsetX: offsetX,
    offsetY: offsetY,
  );
}

bool isRenderableItem(RenderItem item) {
  return item.worldPosition.dx.isFinite &&
      item.worldPosition.dy.isFinite &&
      item.worldScale.isFinite &&
      item.baseWidth.isFinite &&
      item.baseHeight.isFinite &&
      item.baseWidth > 0 &&
      item.baseHeight > 0 &&
      item.worldScale > 0;
}
