import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';
import 'layer_tree/layer_tree_row.dart';

class LayerTreePanel extends StatelessWidget {
  final LayerTreeFacade facade;
  final bool showHeader;

  const LayerTreePanel({
    super.key,
    required this.facade,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showHeader) {
      return Container(
        color: const Color(0xFFF3F7FA),
        child: _LayerTreeList(facade: facade),
      );
    }
    return Container(
      color: const Color(0xFFF3F7FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFFDDE5EA),
            child: Row(
              children: [
                const Text(
                  '图层树',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                LayerTreeSelectionActions(facade: facade),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _LayerTreeList(facade: facade)),
        ],
      ),
    );
  }
}

class LayerTreeSelectionActions extends StatelessWidget {
  const LayerTreeSelectionActions({super.key, required this.facade});

  final LayerTreeFacade facade;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: facade.selectionListenable,
      builder: (context, child) {
        final selectedCount =
            facade.selectedIds.where((id) => id != 'root').length;
        if (selectedCount < 2) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: facade.groupSelected,
              child: const Text('编组'),
            ),
            TextButton(
              onPressed: facade.ungroupSelection,
              child: const Text('解组'),
            ),
          ],
        );
      },
    );
  }
}

class _LayerTreeList extends StatelessWidget {
  const _LayerTreeList({required this.facade});

  final LayerTreeFacade facade;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: facade.treeListenable,
      builder: (context, child) {
        final visibleEntries = buildVisibleLayerTreeEntries(
          facade: facade,
          nodes: facade.project.root.children,
        );
        final orderedVisibleNodeIds = visibleEntries
            .map((entry) => entry.node.id)
            .toList(growable: false);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: facade.clearSelection,
          child: ListView.builder(
            itemCount: visibleEntries.length,
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              return buildLayerTreeRowItem(
                context: context,
                facade: facade,
                node: entry.node,
                level: entry.level,
                orderedVisibleNodeIds: orderedVisibleNodeIds,
              );
            },
          ),
        );
      },
    );
  }
}
