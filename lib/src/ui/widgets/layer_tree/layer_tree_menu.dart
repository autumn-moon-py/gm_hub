import 'package:flutter/material.dart';

import '../../../model/project_model.dart';
import '../layer_tree_actions.dart';

List<PopupMenuEntry<String>> buildLayerTreeNodeMenuItems({
  required NodeModel node,
}) {
  final canRename = node.id != 'root';
  return [
    PopupMenuItem(
      value: LayerTreeActionKey.rename,
      enabled: canRename,
      child: const Text('重命名'),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: LayerTreeActionKey.addImage,
      child: Text('添加图片'),
    ),
    const PopupMenuItem(
      value: LayerTreeActionKey.addText,
      child: Text('添加文字'),
    ),
    const PopupMenuItem(
      value: LayerTreeActionKey.addGroup,
      child: Text('添加分组'),
    ),
    if (node.type == NodeType.image)
      const PopupMenuItem(
        value: LayerTreeActionKey.relinkAsset,
        child: Text('重新选择素材文件'),
      ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: LayerTreeActionKey.delete,
      enabled: canRename,
      child: const Text('删除'),
    ),
  ];
}
