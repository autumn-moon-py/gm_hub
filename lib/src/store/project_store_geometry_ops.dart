part of 'project_store.dart';

extension ProjectStoreGeometryOps on ProjectStore {
  _NodeLocation? _findNodeLocationInTree(NodeModel root, String id) {
    _NodeLocation? walk(NodeModel parent) {
      for (var i = 0; i < parent.children.length; i++) {
        final child = parent.children[i];
        if (child.id == id) {
          return _NodeLocation(parentId: parent.id, index: i, node: child);
        }
        final nested = walk(child);
        if (nested != null) {
          return nested;
        }
      }
      return null;
    }

    if (id == 'root') {
      return null;
    }
    return walk(root);
  }

  NodeModel _mutateNode(
    NodeModel root,
    String targetId,
    NodeModel Function(NodeModel node) mutator,
  ) {
    if (root.id == targetId) {
      return mutator(root);
    }
    if (root.children.isEmpty) {
      return root;
    }
    var changed = false;
    final updatedChildren = root.children.map((child) {
      final updated = _mutateNode(child, targetId, mutator);
      if (!identical(updated, child)) {
        changed = true;
      }
      return updated;
    }).toList();
    if (!changed) {
      return root;
    }
    return root.copyWith(children: updatedChildren);
  }

  NodeModel _mutateChildrenOfParent(
    NodeModel root,
    String parentId,
    List<NodeModel> Function(List<NodeModel> children) mutator,
  ) {
    if (root.id == parentId && root.isGroup) {
      return root.copyWith(children: mutator(root.children));
    }
    if (root.children.isEmpty) {
      return root;
    }

    var changed = false;
    final updated = root.children.map((child) {
      final next = _mutateChildrenOfParent(child, parentId, mutator);
      if (!identical(next, child)) {
        changed = true;
      }
      return next;
    }).toList();

    if (!changed) {
      return root;
    }
    return root.copyWith(children: updated);
  }

  void _dfsCollect({
    required NodeModel node,
    required bool parentVisible,
    required bool parentLocked,
    required bool parentPreserveAspect,
    required Offset parentWorldPos,
    required double parentWorldScale,
    required double parentWorldRotation,
    required double parentOpacity,
    required int depth,
    required List<RenderItem> output,
  }) {
    final effectiveVisible = parentVisible && node.visible;
    final effectiveLocked = parentLocked || node.locked;
    final currentScale = parentWorldScale * node.transform.scale;
    final currentRotation = parentWorldRotation + node.transform.rotation;
    final localScaled = Offset(
      node.transform.x * parentWorldScale,
      node.transform.y * parentWorldScale,
    );
    final cosTheta = math.cos(parentWorldRotation);
    final sinTheta = math.sin(parentWorldRotation);
    final rotatedLocal = Offset(
      localScaled.dx * cosTheta - localScaled.dy * sinTheta,
      localScaled.dx * sinTheta + localScaled.dy * cosTheta,
    );
    final currentPos = parentWorldPos + rotatedLocal;
    final currentOpacity = (parentOpacity * node.opacity).clamp(0.0, 1.0);
    final currentPreserveAspect =
        parentPreserveAspect || _isPreserveAspectGroup(node);

    if (!node.isGroup) {
      final relAsset = node.asset;
      final abs = _resolveAssetAbsolutePath(relAsset);
      final size = _resolveNodeBaseSize(node, abs);
      final textValue = node.type == NodeType.text ? (node.text ?? '文字') : null;
      final textFontSize =
          node.type == NodeType.text ? (node.fontSize ?? 34) : null;
      final textColorValue =
          node.type == NodeType.text ? node.textColorValue : null;
      final handleHeight =
          node.type == NodeType.text ? ProjectStore._textDragHandleHeight : 0.0;
      output.add(
        RenderItem(
          id: node.id,
          name: node.name,
          type: node.type,
          lockedByAncestor: effectiveLocked,
          visible: effectiveVisible,
          worldPosition: currentPos,
          worldScale: currentScale,
          worldRotation: currentRotation,
          opacity: currentOpacity,
          depth: depth,
          assetPath: relAsset,
          assetAbsolutePath: abs,
          text: textValue,
          textFontSize: textFontSize,
          textColorValue: textColorValue,
          textHandleHeight: handleHeight,
          preserveAspect: currentPreserveAspect,
          baseWidth: size.width,
          baseHeight: size.height,
        ),
      );
    }

    for (final child in node.children.reversed) {
      _dfsCollect(
        node: child,
        parentVisible: effectiveVisible,
        parentLocked: effectiveLocked,
        parentPreserveAspect: currentPreserveAspect,
        parentWorldPos: currentPos,
        parentWorldScale: currentScale,
        parentWorldRotation: currentRotation,
        parentOpacity: currentOpacity,
        depth: depth + 1,
        output: output,
      );
    }
  }

  bool _isPreserveAspectGroup(NodeModel node) {
    if (!node.isGroup) {
      return false;
    }
    if (node.id == 'group_npc' || node.id == 'group_player') {
      return true;
    }
    final name = node.name.trim();
    return name.toUpperCase() == 'NPC' || name == '玩家';
  }

  bool _applyWorldDeltaAndCommit(
    Map<String, Offset> worldDeltas, {
    bool recordUndo = false,
    bool recordUndoOnceInTransaction = false,
  }) {
    if (worldDeltas.isEmpty) {
      return false;
    }
    final infos = _collectNodeWorldInfos(worldDeltas.keys.toSet());
    final localDeltas = <String, Offset>{};
    infos.forEach((id, info) {
      final worldDelta = worldDeltas[id];
      if (worldDelta == null) {
        return;
      }
      if (worldDelta.dx.abs() < 0.0001 && worldDelta.dy.abs() < 0.0001) {
        return;
      }
      final local = _worldDeltaToLocalDelta(
        worldDelta,
        parentWorldScale: info.parentWorldScale,
        parentWorldRotation: info.parentWorldRotation,
      );
      if (local.dx.abs() < 0.0001 && local.dy.abs() < 0.0001) {
        return;
      }
      localDeltas[id] = local;
    });
    if (localDeltas.isEmpty) {
      return false;
    }
    if (recordUndo) {
      _pushLayerHistorySnapshot();
    } else if (recordUndoOnceInTransaction &&
        _dragUndoTransactionActive &&
        !_dragUndoSnapshotCaptured) {
      _pushLayerHistorySnapshot();
      _dragUndoSnapshotCaptured = true;
    }
    _project = _project.copyWith(
      root: _mutateNodesLocalOffset(_project.root, localDeltas),
    );
    _onProjectChanged();
    return true;
  }

  NodeModel _mutateNodesLocalOffset(
    NodeModel node,
    Map<String, Offset> localDeltas,
  ) {
    final delta = localDeltas[node.id];
    var next = node;
    if (delta != null) {
      next = node.copyWith(
        transform: node.transform.copyWith(
          x: node.transform.x + delta.dx,
          y: node.transform.y + delta.dy,
        ),
      );
    }
    if (node.children.isEmpty) {
      return next;
    }
    var changed = false;
    final updatedChildren = next.children.map((child) {
      final updated = _mutateNodesLocalOffset(child, localDeltas);
      if (!identical(updated, child)) {
        changed = true;
      }
      return updated;
    }).toList();
    if (!changed) {
      return next;
    }
    return next.copyWith(children: updatedChildren);
  }

  Map<String, _NodeWorldInfo> _collectNodeWorldInfos(Set<String> targetIds) {
    final infos = <String, _NodeWorldInfo>{};
    _walkNodeWorldInfo(
      node: _project.root,
      parentWorldPos: Offset.zero,
      parentWorldScale: 1,
      parentWorldRotation: 0,
      parentLocked: false,
      targetIds: targetIds,
      output: infos,
    );
    return infos;
  }

  Rect? _walkNodeWorldInfo({
    required NodeModel node,
    required Offset parentWorldPos,
    required double parentWorldScale,
    required double parentWorldRotation,
    required bool parentLocked,
    required Set<String> targetIds,
    required Map<String, _NodeWorldInfo> output,
  }) {
    final currentScale = parentWorldScale * node.transform.scale;
    final currentRotation = parentWorldRotation + node.transform.rotation;
    final localScaled = Offset(
      node.transform.x * parentWorldScale,
      node.transform.y * parentWorldScale,
    );
    final cosTheta = math.cos(parentWorldRotation);
    final sinTheta = math.sin(parentWorldRotation);
    final rotatedLocal = Offset(
      localScaled.dx * cosTheta - localScaled.dy * sinTheta,
      localScaled.dx * sinTheta + localScaled.dy * cosTheta,
    );
    final currentPos = parentWorldPos + rotatedLocal;
    final effectiveLocked = parentLocked || node.locked;

    Rect? bounds;
    if (!node.isGroup) {
      final relAsset = node.asset;
      final abs = _resolveAssetAbsolutePath(relAsset);
      final size = _resolveNodeBaseSize(node, abs);
      final unrotated = Rect.fromLTWH(
        currentPos.dx,
        currentPos.dy,
        size.width * currentScale,
        size.height * currentScale,
      );
      bounds = _rotateRectBounds(unrotated, currentRotation);
    }

    for (final child in node.children) {
      final childBounds = _walkNodeWorldInfo(
        node: child,
        parentWorldPos: currentPos,
        parentWorldScale: currentScale,
        parentWorldRotation: currentRotation,
        parentLocked: effectiveLocked,
        targetIds: targetIds,
        output: output,
      );
      if (childBounds != null) {
        bounds =
            bounds == null ? childBounds : bounds.expandToInclude(childBounds);
      }
    }

    if (targetIds.contains(node.id)) {
      final safeBounds =
          bounds ?? Rect.fromLTWH(currentPos.dx, currentPos.dy, 0, 0);
      output[node.id] = _NodeWorldInfo(
        id: node.id,
        bounds: safeBounds,
        parentWorldScale: parentWorldScale,
        parentWorldRotation: parentWorldRotation,
        lockedByAncestor: effectiveLocked,
      );
    }
    return bounds;
  }

  Rect _rotateRectBounds(Rect rect, double radians) {
    if (radians.abs() < 0.00001 || rect.width <= 0 || rect.height <= 0) {
      return rect;
    }
    final center = rect.center;
    final cosTheta = math.cos(radians);
    final sinTheta = math.sin(radians);
    Offset rotatePoint(Offset p) {
      final local = p - center;
      return Offset(
        local.dx * cosTheta - local.dy * sinTheta + center.dx,
        local.dx * sinTheta + local.dy * cosTheta + center.dy,
      );
    }

    final points = [
      rotatePoint(rect.topLeft),
      rotatePoint(rect.topRight),
      rotatePoint(rect.bottomLeft),
      rotatePoint(rect.bottomRight),
    ];
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.dx < minX) {
        minX = p.dx;
      }
      if (p.dx > maxX) {
        maxX = p.dx;
      }
      if (p.dy < minY) {
        minY = p.dy;
      }
      if (p.dy > maxY) {
        maxY = p.dy;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect? _unionBounds(List<Rect> bounds) {
    if (bounds.isEmpty) {
      return null;
    }
    var result = bounds.first;
    for (var i = 1; i < bounds.length; i++) {
      result = result.expandToInclude(bounds[i]);
    }
    return result;
  }

  Offset _worldDeltaToLocalDelta(
    Offset worldDelta, {
    required double parentWorldScale,
    required double parentWorldRotation,
  }) {
    if (parentWorldScale.abs() < 0.00001) {
      return Offset.zero;
    }
    final cosTheta = math.cos(-parentWorldRotation);
    final sinTheta = math.sin(-parentWorldRotation);
    final rotated = Offset(
      worldDelta.dx * cosTheta - worldDelta.dy * sinTheta,
      worldDelta.dx * sinTheta + worldDelta.dy * cosTheta,
    );
    return Offset(
      rotated.dx / parentWorldScale,
      rotated.dy / parentWorldScale,
    );
  }
}
