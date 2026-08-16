import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/project_model.dart';
import '../../model/render_item.dart';
import '../../render/render_item_content.dart';
import 'stage/stage_hit_test.dart';
import 'stage/stage_layer_tile.dart';

class StageCanvas extends StatelessWidget {
  final List<RenderItem> renderList;
  final Listenable selectionListenable;
  final ValueGetter<String?> selectedIdResolver;
  final double canvasWidth;
  final double canvasHeight;
  final bool isOutputMode;
  final ValueChanged<String> onItemTap;
  final VoidCallback onBlankTap;
  final VoidCallback onPanStart;
  final VoidCallback onPanEnd;
  final ValueChanged<Offset> onPanDelta;
  final ValueChanged<double> onScaleByWheel;
  final ValueChanged<double> onRotateByWheel;
  final void Function(double scaleX, double scaleY)? onViewportScalesChanged;

  const StageCanvas({
    super.key,
    required this.renderList,
    required this.selectionListenable,
    required this.selectedIdResolver,
    required this.canvasWidth,
    required this.canvasHeight,
    this.isOutputMode = false,
    required this.onItemTap,
    required this.onBlankTap,
    required this.onPanStart,
    required this.onPanEnd,
    required this.onPanDelta,
    required this.onScaleByWheel,
    required this.onRotateByWheel,
    this.onViewportScalesChanged,
  });

  bool _shouldKeepSelectionOnTap({
    required Offset localPosition,
    required double scaleX,
    required double scaleY,
  }) {
    final currentSelectedId = selectedIdResolver();
    final selectedItem = _findRenderItemById(currentSelectedId);
    if (selectedItem == null) {
      return false;
    }

    return hitTestTopDown(
          renderList: [selectedItem],
          localPosition: localPosition,
          scaleX: scaleX,
          scaleY: scaleY,
          useFullBoundsHit: true,
        ) ==
        currentSelectedId;
  }

  RenderItem? _findRenderItemById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final item in renderList) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  double _itemWidth(
    RenderItem item, {
    required double scaleX,
    required double uniformScale,
  }) {
    return item.baseWidth *
        item.worldScale *
        (item.preserveAspect ? uniformScale : scaleX);
  }

  double _itemHeight(
    RenderItem item, {
    required double scaleY,
    required double uniformScale,
  }) {
    return item.baseHeight *
        item.worldScale *
        (item.preserveAspect ? uniformScale : scaleY);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaleX = constraints.maxWidth / canvasWidth;
          final scaleY = constraints.maxHeight / canvasHeight;
          onViewportScalesChanged?.call(scaleX, scaleY);
          final uniformScale = scaleX < scaleY ? scaleX : scaleY;
          final stageScene = RepaintBoundary(
            child: _StageCanvasScene(
              renderList: renderList,
              scaleX: scaleX,
              scaleY: scaleY,
              uniformScale: uniformScale,
            ),
          );
          return GestureDetector(
            onDoubleTapDown: isOutputMode
                ? null
                : (details) {
                    final hitId = hitTestTopDown(
                      renderList: renderList,
                      localPosition: details.localPosition,
                      scaleX: scaleX,
                      scaleY: scaleY,
                      useFullBoundsHit: true,
                    );
                    if (hitId != null) {
                      onItemTap(hitId);
                    } else {
                      onBlankTap();
                    }
                  },
            onTapDown: isOutputMode
                ? null
                : (details) {
                    final hitId = hitTestTopDown(
                      renderList: renderList,
                      localPosition: details.localPosition,
                      scaleX: scaleX,
                      scaleY: scaleY,
                    );
                    if (hitId != null) {
                      onItemTap(hitId);
                    } else if (_shouldKeepSelectionOnTap(
                      localPosition: details.localPosition,
                      scaleX: scaleX,
                      scaleY: scaleY,
                    )) {
                      return;
                    } else {
                      onBlankTap();
                    }
                  },
            onPanUpdate: isOutputMode ? null : (d) => onPanDelta(d.delta * 3.0),
            onPanStart: isOutputMode ? null : (_) => onPanStart(),
            onPanEnd: isOutputMode ? null : (_) => onPanEnd(),
            onPanCancel: isOutputMode ? null : onPanEnd,
            child: Listener(
              onPointerSignal: isOutputMode
                  ? null
                  : (signal) {
                      if (signal is PointerScrollEvent) {
                        final isAltPressed =
                            HardwareKeyboard.instance.isAltPressed;
                        if (isAltPressed) {
                          onRotateByWheel(
                            signal.scrollDelta.dy < 0 ? -0.08 : 0.08,
                          );
                        } else {
                          onScaleByWheel(
                            signal.scrollDelta.dy < 0 ? 1.06 : 0.94,
                          );
                        }
                      }
                    },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: const Color(0xFF182028),
                child: Stack(
                  children: [
                    Positioned.fill(child: stageScene),
                    ListenableBuilder(
                      listenable: selectionListenable,
                      builder: (context, child) {
                        final selectedItem = _findRenderItemById(
                          selectedIdResolver(),
                        );
                        if (selectedItem == null) {
                          return const SizedBox.shrink();
                        }
                        final isText = selectedItem.type == NodeType.text;
                        final itemWidth = _itemWidth(
                          selectedItem,
                          scaleX: scaleX,
                          uniformScale: uniformScale,
                        );
                        final itemHeight = _itemHeight(
                          selectedItem,
                          scaleY: scaleY,
                          uniformScale: uniformScale,
                        );
                        return Positioned(
                          left: selectedItem.worldPosition.dx * scaleX,
                          top: selectedItem.worldPosition.dy * scaleY,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: selectedItem.worldRotation,
                              alignment: Alignment.center,
                              child: isText
                                  ? Transform.scale(
                                      scale: selectedItem.worldScale,
                                      alignment: Alignment.center,
                                      child: IntrinsicWidth(
                                        child: IntrinsicHeight(
                                          child: Stack(
                                            children: [
                                              // Invisible content to size the stack
                                              Opacity(
                                                opacity: 0,
                                                child: RenderItemContent(
                                                  item: selectedItem,
                                                  renderedHeight: null,
                                                  showImagePlaceholder: true,
                                                ),
                                              ),
                                              // Border overlay
                                              Positioned.fill(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.amber,
                                                      width: 3,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: itemWidth,
                                      height: itemHeight,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.amber,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageCanvasScene extends StatelessWidget {
  const _StageCanvasScene({
    required this.renderList,
    required this.scaleX,
    required this.scaleY,
    required this.uniformScale,
  });

  final List<RenderItem> renderList;
  final double scaleX;
  final double scaleY;
  final double uniformScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final item in renderList)
          Positioned(
            left: item.worldPosition.dx * scaleX,
            top: item.worldPosition.dy * scaleY,
            child: Opacity(
              opacity: item.visible ? item.opacity : 0,
              child: Transform.rotate(
                angle: item.worldRotation,
                alignment: Alignment.center,
                child: item.type == NodeType.text
                    ? Transform.scale(
                        scale: item.worldScale,
                        alignment: Alignment.center,
                        child: StageLayerTile(item: item),
                      )
                    : StageLayerTile(
                        item: item,
                        width: item.baseWidth *
                            item.worldScale *
                            (item.preserveAspect ? uniformScale : scaleX),
                        height: item.baseHeight *
                            item.worldScale *
                            (item.preserveAspect ? uniformScale : scaleY),
                      ),
              ),
            ),
          ),
        if (renderList.isEmpty)
          const Center(
            child: Text(
              '暂无可渲染图层',
              style: TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }
}
