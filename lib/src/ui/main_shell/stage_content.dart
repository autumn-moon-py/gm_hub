import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';
import '../widgets/flow_message_panel.dart';
import '../widgets/stage_canvas.dart';
import 'transform_bar.dart';

class StageContent extends StatelessWidget {
  const StageContent({
    super.key,
    required this.ui,
  });

  final MainShellUiFacade ui;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TransformBar(facade: ui.stage),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: ui.stage.stageListenable,
              builder: (context, child) {
                final renderList = ui.stage.buildRenderList();
                final canvas = ui.stage.project.canvas;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: StageCanvas(
                        renderList: renderList,
                        selectionListenable: ui.stage.selectionListenable,
                        selectedIdResolver: () => ui.stage.selection,
                        canvasWidth: canvas.width,
                        canvasHeight: canvas.height,
                        onItemTap: ui.stage.selectNode,
                        onBlankTap: ui.stage.clearSelection,
                        onPanStart: ui.stage.beginDragSelection,
                        onPanEnd: ui.stage.endDragSelection,
                        onPanDelta: ui.stage.nudgeSelection,
                        onScaleByWheel: ui.stage.scaleSelection,
                        onRotateByWheel: ui.stage.rotateSelection,
                        onViewportScalesChanged: ui.stage.updateViewportScales,
                      ),
                    ),
                    if (ui.stage.flowMessages.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FlowMessagePanel(
                          messages: ui.stage.flowMessages,
                          onViewportChanged: (size) {
                            ui.stage.setFlowViewport(
                                width: size.width, height: size.height);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
