import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';

class FileDropWrapper extends StatelessWidget {
  const FileDropWrapper({
    super.key,
    required this.facade,
    required this.child,
  });

  final LayerTreeFacade facade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        final paths = details.files.map((f) => f.path).toList();
        facade.importDroppedImageFiles(paths);
      },
      child: child,
    );
  }
}