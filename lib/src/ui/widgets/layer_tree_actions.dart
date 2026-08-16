import 'package:flutter/material.dart';

import '../../model/project_model.dart';
import '../facade/project_ui_facade.dart';

class LayerTreeActionKey {
  LayerTreeActionKey._();

  static const rename = 'rename';
  static const toggleVisible = 'toggle_visible';
  static const toggleLocked = 'toggle_locked';
  static const addImage = 'add_image';
  static const addText = 'add_text';
  static const addGroup = 'add_group';
  static const relinkAsset = 'relink_asset';
  static const groupSelected = 'group_selected';
  static const ungroup = 'ungroup';
  static const toggleCollapse = 'toggle_collapse';
  static const delete = 'delete';
}

Future<void> showLayerNodeContextMenu({
  required BuildContext context,
  required TapDownDetails details,
  required List<PopupMenuEntry<String>> menuItems,
  required void Function(String action) onAction,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) {
    return;
  }
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(
        details.globalPosition.dx,
        details.globalPosition.dy,
        1,
        1,
      ),
      Offset.zero & overlay.size,
    ),
    items: menuItems,
  );
  if (action != null) {
    onAction(action);
  }
}

void handleLayerNodeMenuAction({
  required BuildContext context,
  required LayerTreeFacade facade,
  required NodeModel node,
  required String action,
  required Future<void> Function(BuildContext context, {String? targetId})
      showRenameDialog,
}) {
  switch (action) {
    case LayerTreeActionKey.rename:
      showRenameDialog(context, targetId: node.id);
      break;
    case LayerTreeActionKey.toggleVisible:
      facade.toggleNodeVisible(node.id);
      break;
    case LayerTreeActionKey.toggleLocked:
      facade.toggleNodeLocked(node.id);
      break;
    case LayerTreeActionKey.addImage:
      facade.selectNode(node.id);
      facade.addImageLayer();
      break;
    case LayerTreeActionKey.addText:
      facade.selectNode(node.id);
      facade.addTextLayer();
      break;
    case LayerTreeActionKey.addGroup:
      facade.selectNode(node.id);
      facade.addGroup();
      break;
    case LayerTreeActionKey.relinkAsset:
      facade.selectNode(node.id);
      facade.relinkNodeAsset(node.id);
      break;
    case LayerTreeActionKey.groupSelected:
      facade.groupSelected();
      break;
    case LayerTreeActionKey.ungroup:
      facade.selectNode(node.id);
      facade.ungroupSelection();
      break;
    case LayerTreeActionKey.toggleCollapse:
      if (node.isGroup) {
        facade.toggleGroupCollapse(node.id);
      }
      break;
    case LayerTreeActionKey.delete:
      if (!facade.selectedIds.contains(node.id)) {
        facade.selectNode(node.id);
      }
      facade.deleteSelected();
      break;
  }
}
