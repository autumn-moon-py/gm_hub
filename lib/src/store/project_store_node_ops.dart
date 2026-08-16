part of 'project_store.dart';

extension ProjectStoreNodeOps on ProjectStore {
  bool moveSelectionDown() => _moveSelection(1);

  List<String> resolveDraggedNodeIds(String draggedId) {
    if (draggedId.isEmpty || draggedId == 'root') {
      return const [];
    }
    final selected =
        _selectedIds.where((id) => id != 'root').toList(growable: false);
    if (!selected.contains(draggedId)) {
      return [draggedId];
    }
    return selected;
  }

  bool canDropNode({
    required String draggedId,
    required String targetId,
    DropPlacement placement = DropPlacement.before,
  }) {
    final draggedIds = resolveDraggedNodeIds(draggedId);
    if (draggedIds.isEmpty || draggedIds.contains(targetId)) {
      return false;
    }
    final target = _findNodeById(_project.root, targetId);
    if (target == null) {
      return false;
    }
    final targetPath = _findPathToNode(targetId);
    if (targetPath == null) {
      return false;
    }
    for (final n in targetPath) {
      if (draggedIds.contains(n.id)) {
        return false;
      }
    }
    if (placement == DropPlacement.into && !target.isGroup) {
      return false;
    }
    final locations = draggedIds
        .map(_findNodeLocation)
        .whereType<_NodeLocation>()
        .toList(growable: false);
    if (locations.length != draggedIds.length) {
      return false;
    }
    if (placement != DropPlacement.into) {
      final targetLocation = _findNodeLocation(targetId);
      if (targetLocation == null) {
        return false;
      }
      final sameParent = locations
          .every((location) => location.parentId == targetLocation.parentId);
      if (sameParent) {
        final indexes = locations.map((e) => e.index).toSet();
        if (placement == DropPlacement.before &&
            indexes.contains(targetLocation.index)) {
          return false;
        }
        if (placement == DropPlacement.after &&
            indexes.contains(targetLocation.index + 1)) {
          return false;
        }
      }
    }
    return true;
  }

  bool moveNodeByDrop({
    required String draggedId,
    required String targetId,
    DropPlacement placement = DropPlacement.before,
  }) {
    if (!canDropNode(
      draggedId: draggedId,
      targetId: targetId,
      placement: placement,
    )) {
      return false;
    }

    final draggedIds = resolveDraggedNodeIds(draggedId);
    if (draggedIds.isEmpty) {
      return false;
    }
    final locations =
        draggedIds.map(_findNodeLocation).whereType<_NodeLocation>().toList();
    if (locations.length != draggedIds.length) {
      return false;
    }
    locations.sort((a, b) => a.index.compareTo(b.index));

    final movingNodes =
        locations.map((location) => location.node).toList(growable: false);
    final movingIdSet = draggedIds.toSet();
    var rootAfterRemoval = _project
        .copyWith(
          root: _removeNodes(_project.root, movingIdSet),
        )
        .root;

    final targetNode = _findNodeById(rootAfterRemoval, targetId);
    if (targetNode == null) {
      return false;
    }

    String insertParentId;
    int insertIndex;
    if (placement == DropPlacement.into) {
      insertParentId = targetNode.id;
      insertIndex = targetNode.children.length;
    } else {
      final to = _findNodeLocationInTree(rootAfterRemoval, targetId);
      if (to == null) {
        return false;
      }
      insertParentId = to.parentId;
      insertIndex = placement == DropPlacement.after ? to.index + 1 : to.index;
    }

    rootAfterRemoval = _mutateChildrenOfParent(
      rootAfterRemoval,
      insertParentId,
      (children) {
        final list = [...children];
        final idx = insertIndex.clamp(0, list.length);
        list.insertAll(idx, movingNodes);
        return list;
      },
    );

    _pushLayerHistorySnapshot();
    _project = _project.copyWith(root: rootAfterRemoval);
    _onProjectChanged();
    return true;
  }

  bool groupSelected() {
    if (_selectedIds.length < 2) {
      return false;
    }
    final locations = _selectedIds
        .map(_findNodeLocation)
        .whereType<_NodeLocation>()
        .where((e) => e.node.id != 'root')
        .toList();
    if (locations.length < 2) {
      return false;
    }

    final parentId = locations.first.parentId;
    if (locations.any((e) => e.parentId != parentId)) {
      return false;
    }

    locations.sort((a, b) => a.index.compareTo(b.index));
    final pickedIds = locations.map((e) => e.node.id).toSet();
    final groupNode = NodeModel(
      id: _nextId('group'),
      type: NodeType.group,
      name: '分组',
      visible: true,
      locked: false,
      opacity: 1,
      transform: const TransformModel.identity(),
      children: locations.map((e) => e.node).toList(),
    );

    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateChildrenOfParent(
        _project.root,
        parentId,
        (children) {
          final kept =
              children.where((e) => !pickedIds.contains(e.id)).toList();
          final insertAt = locations.first.index;
          return [...kept.take(insertAt), groupNode, ...kept.skip(insertAt)];
        },
      ),
    );
    selectNode(groupNode.id);
    _onProjectChanged();
    return true;
  }

  bool ungroupSelection() {
    final selected = _selection;
    if (selected == null || selected == 'root') {
      return false;
    }
    final location = _findNodeLocation(selected);
    if (location == null || !location.node.isGroup) {
      return false;
    }

    final group = location.node;
    // 组仅作为逻辑容器，其 transform 不影响子节点，解组时直接提升子节点即可
    final promoted = group.children.toList();

    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateChildrenOfParent(
        _project.root,
        location.parentId,
        (children) {
          final next = [...children]..removeAt(location.index);
          return [
            ...next.take(location.index),
            ...promoted,
            ...next.skip(location.index)
          ];
        },
      ),
    );

    if (promoted.isNotEmpty) {
      final previousSelectedIds = Set<String>.from(_selectedIds);
      final previousPrimarySelection = _selection;
      _selection = promoted.first.id;
      _selectedIds
        ..clear()
        ..add(_selection!);
      _notifySelectionListeners(
        previousSelectedIds: previousSelectedIds,
        previousPrimarySelection: previousPrimarySelection,
      );
    } else {
      final previousSelectedIds = Set<String>.from(_selectedIds);
      final previousPrimarySelection = _selection;
      _selection = null;
      _selectedIds.clear();
      _notifySelectionListeners(
        previousSelectedIds: previousSelectedIds,
        previousPrimarySelection: previousPrimarySelection,
      );
    }
    _onProjectChanged();
    return true;
  }

  void nudgeSelection(Offset delta) {
    final selected =
        _selectedIds.where((id) => id != 'root').toList(growable: false);
    if (selected.isEmpty) {
      return;
    }
    final worldDeltas = <String, Offset>{};
    for (final id in selected) {
      if (_isNodeLockedByAncestorsOrSelf(id)) {
        continue;
      }
      worldDeltas[id] = delta;
    }
    _applyWorldDeltaAndCommit(
      worldDeltas,
      recordUndo: !_dragUndoTransactionActive,
      recordUndoOnceInTransaction: _dragUndoTransactionActive,
    );
  }

  void scaleSelection(double factor) {
    final selectedId = _selection;
    if (selectedId == null || selectedId == 'root') {
      return;
    }
    if (_isNodeLockedByAncestorsOrSelf(selectedId)) {
      return;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (node) => node.copyWith(
          transform: node.transform.copyWith(
            scale: (node.transform.scale * factor).clamp(0.1, 6.0),
          ),
        ),
      ),
    );
    _onProjectChanged();
  }

  void rotateSelection(double deltaRadians) {
    final selectedId = _selection;
    if (selectedId == null || selectedId == 'root') {
      return;
    }
    if (_isNodeLockedByAncestorsOrSelf(selectedId)) {
      return;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (node) => node.copyWith(
          transform: node.transform.copyWith(
            rotation: node.transform.rotation + deltaRadians,
          ),
        ),
      ),
    );
    _onProjectChanged();
  }

  void resetSelectionRotation() {
    final selectedId = _selection;
    if (selectedId == null || selectedId == 'root') {
      return;
    }
    if (_isNodeLockedByAncestorsOrSelf(selectedId)) {
      return;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (node) => node.copyWith(
          transform: node.transform.copyWith(rotation: 0),
        ),
      ),
    );
    _onProjectChanged();
  }

  bool resetSelectionImageTransform() {
    final selectedId = _selection;
    if (selectedId == null || selectedId == 'root') {
      return false;
    }
    final location = _findNodeLocation(selectedId);
    if (location == null || location.node.type != NodeType.image) {
      return false;
    }
    if (_isNodeLockedByAncestorsOrSelf(selectedId)) {
      return false;
    }

    final size =
        _resolveAssetSize(_resolveAssetAbsolutePath(location.node.asset));
    final parentWorld = _resolveWorldTransform(location.parentId);
    final centeredTransform = _buildCenteredLocalTransform(
      size: size,
      parentWorld: parentWorld,
      canvas: _project.canvas,
    );

    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (current) => current.copyWith(
          transform: centeredTransform,
          width: size.width,
          height: size.height,
        ),
      ),
    );
    _onProjectChanged();
    return true;
  }

  bool centerSelectionHorizontally() {
    return _centerSelectionInCanvas(horizontal: true, vertical: false);
  }

  bool centerSelectionVertically() {
    return _centerSelectionInCanvas(horizontal: false, vertical: true);
  }

  bool _centerSelectionInCanvas({
    required bool horizontal,
    required bool vertical,
  }) {
    final selected = _selectedIds.where((id) => id != 'root').toSet();
    if (selected.isEmpty) {
      return false;
    }
    final infos = _collectNodeWorldInfos(selected);
    final movable =
        infos.values.where((info) => !info.lockedByAncestor).toList();
    if (movable.isEmpty) {
      return false;
    }

    final targetBounds = selected.length == 1
        ? movable.first.bounds
        : _unionBounds(movable.map((info) => info.bounds).toList());
    if (targetBounds == null) {
      return false;
    }

    final canvasCenter = Offset(
      _project.canvas.width / 2,
      _project.canvas.height / 2,
    );
    final worldDelta = Offset(
      horizontal ? canvasCenter.dx - targetBounds.center.dx : 0,
      vertical ? canvasCenter.dy - targetBounds.center.dy : 0,
    );
    final deltas = <String, Offset>{
      for (final info in movable) info.id: worldDelta,
    };
    return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
  }

  bool alignSelectionToCanvasTop({
    double viewportScaleX = 1,
    double viewportScaleY = 1,
  }) {
    final selected = _selectedIds.where((id) => id != 'root').toSet();
    if (selected.isEmpty) {
      return false;
    }
    final infos = _collectNodeWorldInfos(selected);
    final movable =
        infos.values.where((info) => !info.lockedByAncestor).toList();
    if (movable.isEmpty) {
      return false;
    }
    final uniformScale =
        viewportScaleX < viewportScaleY ? viewportScaleX : viewportScaleY;
    final deltas = <String, Offset>{};
    for (final info in movable) {
      double dy;
      if (info.preserveAspect &&
          uniformScale > 0 &&
          viewportScaleY > 0 &&
          (uniformScale - viewportScaleY).abs() > 0.0001) {
        // preserveAspect: rendered height uses uniformScale, but top uses scaleY.
        // To make the visual top = 0, we need:
        //   worldPosition.dy * scaleY = 0  =>  worldPosition.dy = 0
        // But the rendered item's visual top is worldPosition.dy * scaleY,
        // so dy = 0 - info.bounds.top still works for the position.
        // The issue is only on the bottom side where rendered height differs.
        dy = 0 - info.bounds.top;
      } else {
        dy = 0 - info.bounds.top;
      }
      deltas[info.id] = Offset(0, dy);
    }
    return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
  }

  bool alignSelectionToCanvasBottom({
    double viewportScaleX = 1,
    double viewportScaleY = 1,
  }) {
    final selected = _selectedIds.where((id) => id != 'root').toSet();
    if (selected.isEmpty) {
      return false;
    }
    final infos = _collectNodeWorldInfos(selected);
    final movable =
        infos.values.where((info) => !info.lockedByAncestor).toList();
    if (movable.isEmpty) {
      return false;
    }
    final canvasHeight = _project.canvas.height;
    final uniformScale =
        viewportScaleX < viewportScaleY ? viewportScaleX : viewportScaleY;
    final deltas = <String, Offset>{};
    for (final info in movable) {
      double dy;
      if (info.preserveAspect &&
          uniformScale > 0 &&
          viewportScaleY > 0 &&
          (uniformScale - viewportScaleY).abs() > 0.0001) {
        // preserveAspect: rendered height = baseHeight * worldScale * uniformScale,
        // but top = worldPosition.dy * scaleY.
        // We want: top + renderedHeight = constraints.maxHeight = canvasHeight * scaleY
        // => worldPosition.dy * scaleY + baseHeight * worldScale * uniformScale = canvasHeight * scaleY
        // => worldPosition.dy = canvasHeight - baseHeight * worldScale * uniformScale / scaleY
        // Normal (non-preserveAspect) target: canvasHeight - baseHeight * worldScale
        // Difference: baseHeight * worldScale * (1 - uniformScale / scaleY)
        // We adjust bounds.bottom to reflect the rendered visual bottom:
        final renderedVisualHeight =
            info.baseHeight * info.worldScale * uniformScale / viewportScaleY;
        final adjustedBottom = info.bounds.top + renderedVisualHeight;
        dy = canvasHeight - adjustedBottom;
      } else {
        dy = canvasHeight - info.bounds.bottom;
      }
      deltas[info.id] = Offset(0, dy);
    }
    return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
  }

  bool alignSelected(AlignAction action) {
    final selected = _selectedIds.where((id) => id != 'root').toSet();
    if (selected.length < 2) {
      return false;
    }
    final infos = _collectNodeWorldInfos(selected);
    final movable =
        infos.values.where((info) => !info.lockedByAncestor).toList();
    if (movable.length < 2) {
      return false;
    }

    final deltas = <String, Offset>{};
    final groupBounds = _unionBounds(movable.map((e) => e.bounds).toList());
    if (groupBounds == null) {
      return false;
    }

    if (action == AlignAction.distributeH) {
      if (movable.length < 2) {
        return false;
      }
      movable.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      final totalWidth = movable.fold<double>(
        0,
        (sum, e) => sum + e.bounds.width,
      );
      final span = movable.last.bounds.right - movable.first.bounds.left;
      if (span <= 0) {
        return false;
      }
      final gap = math.max(0.0, (span - totalWidth) / (movable.length - 1));
      final packedWidth = totalWidth + gap * (movable.length - 1);
      var cursor = groupBounds.left + (groupBounds.width - packedWidth) / 2;
      for (var i = 0; i < movable.length; i++) {
        final item = movable[i];
        final dx = cursor - item.bounds.left;
        deltas[item.id] = Offset(dx, 0);
        cursor += item.bounds.width + gap;
      }
      return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
    }

    if (action == AlignAction.distributeV) {
      if (movable.length < 2) {
        return false;
      }
      movable.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
      final totalHeight = movable.fold<double>(
        0,
        (sum, e) => sum + e.bounds.height,
      );
      final span = movable.last.bounds.bottom - movable.first.bounds.top;
      if (span <= 0) {
        return false;
      }
      final gap = math.max(0.0, (span - totalHeight) / (movable.length - 1));
      final packedHeight = totalHeight + gap * (movable.length - 1);
      var cursor = groupBounds.top + (groupBounds.height - packedHeight) / 2;
      for (var i = 0; i < movable.length; i++) {
        final item = movable[i];
        final dy = cursor - item.bounds.top;
        deltas[item.id] = Offset(0, dy);
        cursor += item.bounds.height + gap;
      }
      return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
    }

    for (final info in movable) {
      switch (action) {
        case AlignAction.left:
          deltas[info.id] = Offset(groupBounds.left - info.bounds.left, 0);
          break;
        case AlignAction.hCenter:
          deltas[info.id] = Offset(
            groupBounds.center.dx - info.bounds.center.dx,
            0,
          );
          break;
        case AlignAction.right:
          deltas[info.id] = Offset(groupBounds.right - info.bounds.right, 0);
          break;
        case AlignAction.top:
          deltas[info.id] = Offset(0, groupBounds.top - info.bounds.top);
          break;
        case AlignAction.vCenter:
          deltas[info.id] = Offset(
            0,
            groupBounds.center.dy - info.bounds.center.dy,
          );
          break;
        case AlignAction.bottom:
          deltas[info.id] = Offset(0, groupBounds.bottom - info.bounds.bottom);
          break;
        case AlignAction.distributeH:
        case AlignAction.distributeV:
          break;
      }
    }
    return _applyWorldDeltaAndCommit(deltas, recordUndo: true);
  }

  bool stretchSelectionToOutputSize() {
    final selectedId = _selection;
    if (selectedId == null || selectedId == 'root') {
      return false;
    }
    final node = _findNodeById(_project.root, selectedId);
    if (node == null) {
      return false;
    }
    if (_isNodeLockedByAncestorsOrSelf(selectedId)) {
      return false;
    }

    final canvas = _project.canvas;
    if (node.isGroup) {
      var stretchedCount = 0;

      NodeModel stretchGroupLayers(NodeModel current,
          {required bool ancestorLocked}) {
        final locked = ancestorLocked || current.locked;
        if (!current.isGroup) {
          if (current.type != NodeType.image || locked) {
            return current;
          }
          stretchedCount++;
          return _stretchImageNodeToOutputSize(current, canvas);
        }

        var changed = false;
        final updatedChildren = current.children.map((child) {
          final updated = stretchGroupLayers(child, ancestorLocked: locked);
          if (!identical(updated, child)) {
            changed = true;
          }
          return updated;
        }).toList(growable: false);
        if (!changed) {
          return current;
        }
        return current.copyWith(children: updatedChildren);
      }

      final nextRoot = _mutateNode(
        _project.root,
        selectedId,
        (current) => stretchGroupLayers(current, ancestorLocked: false),
      );
      if (stretchedCount == 0) {
        return false;
      }
      _pushLayerHistorySnapshot();
      _project = _project.copyWith(root: nextRoot);
      _onProjectChanged();
      return true;
    }
    if (node.type != NodeType.image) {
      return false;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (current) => _stretchImageNodeToOutputSize(current, canvas),
      ),
    );
    _onProjectChanged();
    return true;
  }

  NodeModel _stretchImageNodeToOutputSize(NodeModel node, CanvasModel canvas) {
    return node.copyWith(
      transform: node.transform.copyWith(
        x: 0,
        y: 0,
        scale: 1,
        rotation: 0,
      ),
      width: canvas.width,
      height: canvas.height,
    );
  }
}
