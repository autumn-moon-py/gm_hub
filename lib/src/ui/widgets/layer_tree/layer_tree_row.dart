import 'package:flutter/material.dart';

import '../../../model/project_model.dart';
import '../../facade/project_ui_facade.dart';
import '../layer_tree_actions.dart';
import '../layer_tree_drop_strip.dart';
import 'layer_tree_dialogs.dart';
import 'layer_tree_menu.dart';

class LayerTreeRowEntry {
  final NodeModel node;
  final int level;

  const LayerTreeRowEntry({
    required this.node,
    required this.level,
  });
}

List<LayerTreeRowEntry> buildVisibleLayerTreeEntries({
  required LayerTreeFacade facade,
  required List<NodeModel> nodes,
  int level = 0,
}) {
  final entries = <LayerTreeRowEntry>[];
  for (final node in nodes) {
    entries.add(LayerTreeRowEntry(node: node, level: level));
    if (node.isGroup && !facade.isGroupCollapsed(node.id)) {
      entries.addAll(
        buildVisibleLayerTreeEntries(
          facade: facade,
          nodes: node.children,
          level: level + 1,
        ),
      );
    }
  }
  return entries;
}

Widget buildLayerTreeRowItem({
  required BuildContext context,
  required LayerTreeFacade facade,
  required NodeModel node,
  required int level,
  required List<String> orderedVisibleNodeIds,
}) {
  return KeyedSubtree(
    key: ValueKey('layer_tree_${node.id}'),
    child: _LayerTreeRowNodeShell(
      facade: facade,
      initialNode: node,
      level: level,
      orderedVisibleNodeIds: orderedVisibleNodeIds,
    ),
  );
}

class _LayerTreeRowNodeShell extends StatelessWidget {
  const _LayerTreeRowNodeShell({
    required this.facade,
    required this.initialNode,
    required this.level,
    required this.orderedVisibleNodeIds,
  });

  final LayerTreeFacade facade;
  final NodeModel initialNode;
  final int level;
  final List<String> orderedVisibleNodeIds;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: facade.nodeDataListenableForNode(initialNode.id),
      builder: (context, child) {
        final node = facade.getNodeById(initialNode.id) ?? initialNode;
        final collapsed = node.isGroup && facade.isGroupCollapsed(node.id);
        return Column(
          children: [
            buildLayerDropStrip(
              facade: facade,
              targetId: node.id,
              placement: LayerDropPlacement.before,
              color: const Color(0xFF0D47A1),
            ),
            DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                return facade.canDropNode(
                  draggedId: details.data,
                  targetId: node.id,
                  placement: node.isGroup
                      ? LayerDropPlacement.into
                      : LayerDropPlacement.before,
                );
              },
              onAcceptWithDetails: (details) {
                facade.moveNodeByDrop(
                  draggedId: details.data,
                  targetId: node.id,
                  placement: node.isGroup
                      ? LayerDropPlacement.into
                      : LayerDropPlacement.before,
                );
              },
              builder: (context, candidateData, rejectedData) {
                final hovering = candidateData.isNotEmpty;
                final dropIntoGroup = hovering && node.isGroup;
                final isAssetMissing =
                    !node.isGroup && facade.isAssetPathMissing(node.asset);

                Widget rowContent({bool draggingPlaceholder = false}) {
                  return _SelectionAwareLayerTreeRowShell(
                    facade: facade,
                    nodeId: node.id,
                    hovering: hovering,
                    dropIntoGroup: dropIntoGroup,
                    draggingPlaceholder: draggingPlaceholder,
                    onTap: () {
                      if (isRangeSelectionPressed()) {
                        facade.selectNodeRange(node.id, orderedVisibleNodeIds);
                      } else if (isToggleSelectionPressed()) {
                        facade.toggleMultiSelect(node.id);
                      } else {
                        facade.selectNode(node.id);
                      }
                    },
                    onDoubleTap: () => handleLayerNodeActivate(
                      context,
                      facade: facade,
                      node: node,
                      toggleSelection: isToggleSelectionPressed(),
                    ),
                    onSecondaryTapDown: (details) {
                      showLayerNodeContextMenu(
                        context: context,
                        details: details,
                        menuItems: buildLayerTreeNodeMenuItems(node: node),
                        onAction: (action) {
                          handleLayerNodeMenuAction(
                            context: context,
                            facade: facade,
                            node: node,
                            action: action,
                            showRenameDialog: (dialogContext, {targetId}) {
                              return showLayerRenameDialog(
                                dialogContext,
                                facade: facade,
                                targetId: targetId,
                              );
                            },
                          );
                        },
                      );
                    },
                    child: _LayerTreeRowBody(
                      node: node,
                      level: level,
                      collapsed: collapsed,
                      isAssetMissing: isAssetMissing,
                      onToggleCollapse: node.isGroup
                          ? () => facade.toggleGroupCollapse(node.id)
                          : null,
                      onRelinkAsset: isAssetMissing
                          ? () => showMissingNodeAssetDialog(
                              context,
                              facade: facade,
                              node: node,
                            )
                          : null,
                      onToggleVisible: () => facade.toggleNodeVisible(node.id),
                      onToggleLocked: () => facade.toggleNodeLocked(node.id),
                      onMenuSelected: (value) {
                        handleLayerNodeMenuAction(
                          context: context,
                          facade: facade,
                          node: node,
                          action: value,
                          showRenameDialog: (dialogContext, {targetId}) {
                            return showLayerRenameDialog(
                              dialogContext,
                              facade: facade,
                              targetId: targetId,
                            );
                          },
                        );
                      },
                    ),
                  );
                }

                final draggedNodeIds = facade.resolveDraggedNodeIds(node.id);
                final dragLabel = draggedNodeIds.length > 1
                    ? '${draggedNodeIds.length} 个图层'
                    : node.name;
                return Draggable<String>(
                  data: node.id,
                  maxSimultaneousDrags: 1,
                  feedback: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                dragLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.45,
                    child: IgnorePointer(
                      child: rowContent(draggingPlaceholder: true),
                    ),
                  ),
                  child: rowContent(),
                );
              },
            ),
            buildLayerDropStrip(
              facade: facade,
              targetId: node.id,
              placement: LayerDropPlacement.after,
              color: const Color(0xFF0D47A1),
            ),
          ],
        );
      },
    );
  }
}

class _SelectionAwareLayerTreeRowShell extends StatefulWidget {
  const _SelectionAwareLayerTreeRowShell({
    required this.facade,
    required this.nodeId,
    required this.hovering,
    required this.dropIntoGroup,
    required this.draggingPlaceholder,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.child,
  });

  final LayerTreeFacade facade;
  final String nodeId;
  final bool hovering;
  final bool dropIntoGroup;
  final bool draggingPlaceholder;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback onSecondaryTapDown;
  final Widget child;

  @override
  State<_SelectionAwareLayerTreeRowShell> createState() =>
      _SelectionAwareLayerTreeRowShellState();
}

class _SelectionAwareLayerTreeRowShellState
    extends State<_SelectionAwareLayerTreeRowShell> {
  late bool _selected;
  late bool _primarySelected;
  late Listenable _nodeSelectionListenable;

  @override
  void initState() {
    super.initState();
    _syncSelectionFlags();
    _nodeSelectionListenable = widget.facade.selectionListenableForNode(
      widget.nodeId,
    );
    _nodeSelectionListenable.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _SelectionAwareLayerTreeRowShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSelectionListenable = widget.facade.selectionListenableForNode(
      widget.nodeId,
    );
    if (!identical(_nodeSelectionListenable, nextSelectionListenable)) {
      _nodeSelectionListenable.removeListener(_handleSelectionChanged);
      _nodeSelectionListenable = nextSelectionListenable;
      _nodeSelectionListenable.addListener(_handleSelectionChanged);
    }
    _syncSelectionFlags();
  }

  @override
  void dispose() {
    _nodeSelectionListenable.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  void _handleSelectionChanged() {
    final nextSelected = widget.facade.selectedIds.contains(widget.nodeId);
    final nextPrimarySelected = widget.facade.selection == widget.nodeId;
    if (nextSelected == _selected && nextPrimarySelected == _primarySelected) {
      return;
    }
    setState(() {
      _selected = nextSelected;
      _primarySelected = nextPrimarySelected;
    });
  }

  void _syncSelectionFlags() {
    _selected = widget.facade.selectedIds.contains(widget.nodeId);
    _primarySelected = widget.facade.selection == widget.nodeId;
  }

  @override
  Widget build(BuildContext context) {
    final rowColor = widget.hovering
        ? const Color(0xFFD7F0FF)
        : (_primarySelected
            ? const Color(0xFFD5E9FF)
            : (_selected
                ? const Color(0xFFE3F1FF)
                : const Color(0xFFF0F7FF)));
    final leftBorderColor = widget.dropIntoGroup
        ? const Color(0xFF1B5E20)
        : (_primarySelected
            ? const Color(0xFF1565C0)
            : (_selected
                ? const Color(0xFF42A5F5)
                : Colors.transparent));
    final leftBorderWidth =
        (widget.dropIntoGroup || _primarySelected || _selected) ? 3.0 : 0.0;
    return InkWell(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: Container(
        decoration: BoxDecoration(
          color: widget.draggingPlaceholder
              ? const Color(0xFFE3EFFA)
              : rowColor,
          border: Border(
            left: BorderSide(
              color: leftBorderColor,
              width: leftBorderWidth,
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _LayerTreeRowBody extends StatelessWidget {
  const _LayerTreeRowBody({
    required this.node,
    required this.level,
    required this.collapsed,
    required this.isAssetMissing,
    required this.onToggleVisible,
    required this.onToggleLocked,
    required this.onMenuSelected,
    this.onToggleCollapse,
    this.onRelinkAsset,
  });

  final NodeModel node;
  final int level;
  final bool collapsed;
  final bool isAssetMissing;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onRelinkAsset;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLocked;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 10 + level * 16, right: 4),
      height: 34,
      child: Row(
        children: [
          if (node.isGroup)
            IconButton(
              iconSize: 18,
              onPressed: onToggleCollapse,
              tooltip: collapsed ? '展开' : '折叠',
              icon: Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
              ),
            )
          else
            const SizedBox(width: 28),
          Icon(
            node.isGroup
                ? Icons.folder_open
                : (node.type == NodeType.text
                    ? Icons.text_fields
                    : Icons.image_outlined),
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              node.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (isAssetMissing)
            IconButton(
              iconSize: 18,
              tooltip: '素材丢失，点击重新选择文件',
              onPressed: onRelinkAsset,
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC62828),
              ),
            ),
          IconButton(
            iconSize: 18,
            onPressed: onToggleVisible,
            tooltip: '显示/隐藏',
            icon: Icon(
              node.visible
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
          ),
          IconButton(
            iconSize: 18,
            onPressed: onToggleLocked,
            tooltip: '锁定/解锁',
            icon: Icon(node.locked ? Icons.lock : Icons.lock_open),
          ),
          PopupMenuButton<String>(
            iconSize: 18,
            padding: EdgeInsets.zero,
            tooltip: '更多操作',
            onSelected: onMenuSelected,
            itemBuilder: (context) {
              return buildLayerTreeNodeMenuItems(node: node);
            },
          ),
        ],
      ),
    );
  }
}
