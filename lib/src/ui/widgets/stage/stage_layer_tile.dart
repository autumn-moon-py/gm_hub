import 'package:flutter/material.dart';

import '../../../model/project_model.dart';
import '../../../model/render_item.dart';
import '../../../render/render_color.dart';
import '../../../render/render_item_content.dart';

class StageLayerTile extends StatelessWidget {
  const StageLayerTile({
    super.key,
    required this.item,
    required this.width,
    required this.height,
  });

  final RenderItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!item.visible) {
      return SizedBox(width: width, height: height);
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
