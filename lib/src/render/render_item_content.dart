import 'dart:io';

import 'package:flutter/material.dart';

import '../model/project_model.dart';
import '../model/render_item.dart';

class RenderItemContent extends StatelessWidget {
  const RenderItemContent({
    super.key,
    required this.item,
    required this.renderedHeight,
    required this.showImagePlaceholder,
  });

  final RenderItem item;
  final double? renderedHeight;
  final bool showImagePlaceholder;

  @override
  Widget build(BuildContext context) {
    if (item.type == NodeType.text) {
      final fontSize = (item.textFontSize ?? 34).clamp(8, 256).toDouble();
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Text(
          item.text ?? item.name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          strutStyle: StrutStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            color: Color(_safeColor(item.textColorValue)),
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      );
    }
    final path = item.assetAbsolutePath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: item.isBackground ? BoxFit.fill : BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return showImagePlaceholder
              ? _imagePlaceholder()
              : const SizedBox.shrink();
        },
      );
    }
    if (!showImagePlaceholder) {
      return const SizedBox.shrink();
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 28,
        color: item.lockedByAncestor ? Colors.black45 : Colors.black87,
      ),
    );
  }

  int _safeColor(int? value) {
    if (value == null) {
      return 0xFFFFFFFF;
    }
    if (value < 0 || value > 0xFFFFFFFF) {
      return 0xFFFFFFFF;
    }
    return value;
  }
}
