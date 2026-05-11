import 'dart:async';

import 'package:flutter/material.dart';

import '../../model/project_model.dart';
import '../facade/project_ui_facade.dart';

class TransformBar extends StatelessWidget {
  const TransformBar({
    super.key,
    required this.facade,
  });

  final StageEditorFacade facade;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        facade.transformListenable,
        facade.selectionListenable,
      ]),
      builder: (context, child) {
        final selectedCount =
            facade.selectedIds.where((id) => id != 'root').length;
        if (selectedCount > 1) {
          return _buildMultiSelectionBar(selectedCount: selectedCount);
        }

        final node = facade.selectedNode;
        if (node == null) {
          return Container(
            height: 34,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('未选择对象'),
          );
        }
        return _buildSingleSelectionBar(
          context: context,
          node: node,
        );
      },
    );
  }

  Widget _buildMultiSelectionBar({required int selectedCount}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('已选：$selectedCount'),
            const SizedBox(width: 8),
            _alignBtn(
              tooltip: '左对齐',
              icon: Icons.format_align_left,
              onPressed: facade.alignLeft,
            ),
            _alignBtn(
              tooltip: '水平居中',
              icon: Icons.format_align_center,
              onPressed: facade.alignHCenter,
            ),
            _alignBtn(
              tooltip: '右对齐',
              icon: Icons.format_align_right,
              onPressed: facade.alignRight,
            ),
            const SizedBox(width: 4),
            _alignBtn(
              tooltip: '顶对齐',
              icon: Icons.vertical_align_top,
              onPressed: facade.alignTop,
            ),
            _alignBtn(
              tooltip: '垂直居中',
              icon: Icons.vertical_align_center,
              onPressed: facade.alignVCenter,
            ),
            _alignBtn(
              tooltip: '底对齐',
              icon: Icons.vertical_align_bottom,
              onPressed: facade.alignBottom,
            ),
            const SizedBox(width: 4),
            _alignBtn(
              tooltip: '横向分布',
              icon: Icons.swap_horiz,
              onPressed: facade.distributeH,
            ),
            _alignBtn(
              tooltip: '纵向分布',
              icon: Icons.swap_vert,
              onPressed: facade.distributeV,
            ),
            const SizedBox(width: 4),
            _alignBtn(
              tooltip: '水平居中到画布',
              icon: Icons.view_week,
              onPressed: facade.centerSelectionHorizontally,
            ),
            _alignBtn(
              tooltip: '垂直居中到画布',
              icon: Icons.view_agenda,
              onPressed: facade.centerSelectionVertically,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSelectionBar({
    required BuildContext context,
    required NodeModel node,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.type == NodeType.text)
                IconButton(
                  tooltip: '编辑文字样式',
                  onPressed: () => _showTextEditDialog(context, node),
                  icon: const Icon(Icons.text_fields, size: 18),
                ),
              IconButton(
                tooltip: '放大',
                onPressed: () => facade.scaleSelection(1.05),
                icon: const Icon(Icons.zoom_in, size: 18),
              ),
              IconButton(
                tooltip: '缩小',
                onPressed: () => facade.scaleSelection(0.95),
                icon: const Icon(Icons.zoom_out, size: 18),
              ),
              IconButton(
                tooltip: '逆时针旋转',
                onPressed: () => facade.rotateSelection(-0.08),
                icon: const Icon(Icons.rotate_left, size: 18),
              ),
              IconButton(
                tooltip: '顺时针旋转',
                onPressed: () => facade.rotateSelection(0.08),
                icon: const Icon(Icons.rotate_right, size: 18),
              ),
              IconButton(
                tooltip: '重置旋转',
                onPressed: facade.resetSelectionRotation,
                icon: const Icon(Icons.sync, size: 18),
              ),
              IconButton(
                tooltip: '水平居中到画布',
                onPressed: facade.centerSelectionHorizontally,
                icon: const Icon(Icons.format_align_center, size: 18),
              ),
              IconButton(
                tooltip: '垂直居中到画布',
                onPressed: facade.centerSelectionVertically,
                icon: const Icon(Icons.vertical_align_center, size: 18),
              ),
              if (node.type == NodeType.image)
                IconButton(
                  tooltip: '重置图片到中心',
                  onPressed: facade.resetSelectionImageTransform,
                  icon: const Icon(Icons.filter_center_focus, size: 18),
                ),
              IconButton(
                tooltip: '拉伸到输出尺寸',
                onPressed: (node.type == NodeType.image || node.isGroup)
                    ? facade.stretchSelectionToOutputSize
                    : null,
                icon: const Icon(Icons.fit_screen, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTextEditDialog(
    BuildContext context,
    NodeModel node,
  ) async {
    final textController = TextEditingController(text: node.text ?? node.name);
    var fontSize = (node.fontSize ?? 34).clamp(8.0, 256.0);
    var textColorValue = node.textColorValue ?? 0xFFFFFFFF;
    final presets = <int>[
      0xFFFFFFFF,
      0xFFFFE082,
      0xFFFFCDD2,
      0xFFB3E5FC,
      0xFFB2DFDB,
      0xFFC5CAE9,
      0xFF212121,
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑文字图层'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: '文字内容',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('字号 ${fontSize.toStringAsFixed(0)}'),
                    Slider(
                      min: 8,
                      max: 128,
                      divisions: 120,
                      value: fontSize,
                      onChanged: (value) => setState(() {
                        fontSize = value;
                      }),
                    ),
                    const SizedBox(height: 4),
                    const Text('颜色'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in presets)
                          InkWell(
                            onTap: () => setState(() {
                              textColorValue = color;
                            }),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(color),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: textColorValue == color
                                      ? const Color(0xFF1565C0)
                                      : Colors.black26,
                                  width: textColorValue == color ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == true) {
      facade.updateSelectedTextLayer(
        text: textController.text,
        fontSize: fontSize,
        textColorValue: textColorValue,
      );
    }
    textController.dispose();
  }

  Widget _alignBtn({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
    );
  }
}
