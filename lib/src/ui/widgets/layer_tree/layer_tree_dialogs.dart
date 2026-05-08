import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../model/project_model.dart';
import '../../facade/project_ui_facade.dart';

Future<void> showLayerRenameDialog(
  BuildContext context, {
  required LayerTreeFacade facade,
  String? targetId,
}) async {
  if (targetId != null) {
    facade.selectNode(targetId);
  }
  final controller = TextEditingController(text: facade.selectionName ?? '');
  final renamed = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('重命名节点'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context, controller.text),
          decoration: const InputDecoration(hintText: '输入新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  if (renamed != null) {
    facade.renameSelection(renamed);
  }
  controller.dispose();
}

void handleLayerNodeActivate(
  BuildContext context, {
  required LayerTreeFacade facade,
  required NodeModel node,
  required bool toggleSelection,
}) {
  if (toggleSelection) {
    facade.toggleMultiSelect(node.id);
  } else {
    facade.selectNode(node.id);
  }
  if (node.isGroup || !facade.isNodeAssetMissing(node.id)) {
    return;
  }
  showMissingNodeAssetDialog(
    context,
    facade: facade,
    node: node,
  );
}

bool isToggleSelectionPressed() {
  final keyboard = HardwareKeyboard.instance;
  return keyboard.isControlPressed || keyboard.isMetaPressed;
}

bool isRangeSelectionPressed() {
  return HardwareKeyboard.instance.isShiftPressed;
}

Future<void> showMissingNodeAssetDialog(
  BuildContext context, {
  required LayerTreeFacade facade,
  required NodeModel node,
}) async {
  final path = facade.getNodeAssetPath(node.id) ?? '';
  final message = '素材文件不存在，请重新选择路径。\n$path';
  final relink = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('素材丢失'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('图层：${node.name}'),
            const SizedBox(height: 8),
            SelectableText(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('已复制错误信息')),
                );
              }
            },
            child: const Text('复制文本'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重新选择文件'),
          ),
        ],
      );
    },
  );
  if (relink == true) {
    await facade.relinkNodeAsset(node.id);
  }
}
