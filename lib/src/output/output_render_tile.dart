import 'package:flutter/material.dart';

import '../model/render_item.dart';
import '../render/render_item_content.dart';

class OutputRenderTile extends StatelessWidget {
  const OutputRenderTile({
    super.key,
    required this.item,
    required this.renderedHeight,
  });

  final RenderItem item;
  final double? renderedHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.transparent),
        RenderItemContent(
          item: item,
          renderedHeight: renderedHeight,
          showImagePlaceholder: false,
        ),
      ],
    );
  }
}
