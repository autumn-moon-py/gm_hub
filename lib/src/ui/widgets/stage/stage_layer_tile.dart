import 'package:flutter/material.dart';

import '../../../model/project_model.dart';
import '../../../model/render_item.dart';
import '../../../render/render_color.dart';
import '../../../render/render_item_content.dart';

class StageLayerTile extends StatelessWidget {
  const StageLayerTile({
    super.key,
    required this.item,
    this.width,
    this.height,
  });

  final RenderItem item;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (!item.visible) {
      return SizedBox(width: width ?? 0, height: height ?? 0);
    }

    // Text nodes: let content size itself via IntrinsicWidth/IntrinsicHeight
    if (item.type == NodeType.text) {
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: RenderItemContent(
            item: item,
            renderedHeight: height,
            showImagePlaceholder: true,
          ),
        ),
      );
    }

    final backgroundColor = item.type == NodeType.image
        ? Colors.transparent
        : colorFromSeed(item.id);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: backgroundColor),
      child: RenderItemContent(
        item: item,
        renderedHeight: height,
        showImagePlaceholder: true,
      ),
    );
  }
}
