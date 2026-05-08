import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';

Widget buildLayerDropStrip({
  required LayerTreeFacade facade,
  required String targetId,
  required LayerDropPlacement placement,
  required Color color,
}) {
  return DragTarget<String>(
    onWillAcceptWithDetails: (details) {
      return facade.canDropNode(
        draggedId: details.data,
        targetId: targetId,
        placement: placement,
      );
    },
    onAcceptWithDetails: (details) {
      facade.moveNodeByDrop(
        draggedId: details.data,
        targetId: targetId,
        placement: placement,
      );
    },
    builder: (context, candidateData, rejectedData) {
      final hovering = candidateData.isNotEmpty;
      return Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: hovering ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    },
  );
}
