part of 'project_store.dart';

extension ProjectStoreTreeOps on ProjectStore {
  void _setProjectFilePath(String value) {
    final normalized = p.normalize(value);
    _projectFilePath = normalized;
    _projectDirPath = p.dirname(normalized);
  }

  String _buildSuggestedProjectFileName(String name) {
    final trimmed = name.trim();
    final raw = trimmed.isEmpty ? 'untitled' : trimmed;
    final safe = raw.replaceAll(RegExp(r'[<>:\"/\\|?*\x00-\x1F]'), '_');
    if (safe
        .toLowerCase()
        .endsWith(ProjectFileService.projectFileDotExtension)) {
      return safe;
    }
    return '$safe${ProjectFileService.projectFileDotExtension}';
  }

  String? _resolveAssetAbsolutePath(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) {
      return null;
    }
    if (p.isAbsolute(assetPath)) {
      return p.normalize(assetPath);
    }
    final baseDir = _projectDirPath;
    if (baseDir == null || baseDir.isEmpty) {
      return null;
    }
    return p.normalize(p.join(baseDir, assetPath));
  }

  bool _assetPathExists(String? assetPath) {
    final absPath = _resolveAssetAbsolutePath(assetPath);
    if (absPath == null || absPath.isEmpty) {
      return false;
    }
    final cached = _assetExistsCache[absPath];
    if (cached != null) {
      return cached;
    }
    final exists = File(absPath).existsSync();
    _assetExistsCache[absPath] = exists;
    return exists;
  }

  AudioTrackModel? _findTrackById(String trackId) {
    for (final track in _project.tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }

  String _nextId(String prefix) {
    _idSeed += 1;
    return '${prefix}_$_idSeed';
  }

  void _refreshIdSeedFromProject() {
    var maxUsedId = 10;

    void visitNode(NodeModel node) {
      maxUsedId = math.max(maxUsedId, _parseNumericIdSuffix(node.id));
      for (final child in node.children) {
        visitNode(child);
      }
    }

    visitNode(_project.root);
    for (final track in _project.tracks) {
      maxUsedId = math.max(maxUsedId, _parseNumericIdSuffix(track.id));
    }
    _idSeed = maxUsedId;
  }

  int _parseNumericIdSuffix(String id) {
    final match = RegExp(r'_(\d+)$').firstMatch(id);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1)!) ?? 0;
  }

  String _resolveInsertParentId() {
    final selected = _selection;
    if (selected == null) {
      return 'root';
    }
    final node = _findNodeById(_project.root, selected);
    if (node == null) {
      return 'root';
    }
    if (node.isGroup) {
      return node.id;
    }
    final location = _findNodeLocation(selected);
    return location?.parentId ?? 'root';
  }

  _NodeWorldTransform _resolveWorldTransform(String nodeId) {
    final path = _findPathToNode(nodeId);
    if (path == null || path.isEmpty) {
      return const _NodeWorldTransform.identity();
    }
    var position = Offset.zero;
    var scale = 1.0;
    var rotation = 0.0;
    for (final node in path) {
      final localScaled = Offset(
        node.transform.x * scale,
        node.transform.y * scale,
      );
      final cosTheta = math.cos(rotation);
      final sinTheta = math.sin(rotation);
      final rotatedLocal = Offset(
        localScaled.dx * cosTheta - localScaled.dy * sinTheta,
        localScaled.dx * sinTheta + localScaled.dy * cosTheta,
      );
      position += rotatedLocal;
      scale *= node.transform.scale;
      rotation += node.transform.rotation;
    }
    return _NodeWorldTransform(
      position: position,
      scale: scale,
      rotation: rotation,
    );
  }

  TransformModel _buildCenteredLocalTransform({
    required Size size,
    required _NodeWorldTransform parentWorld,
    required CanvasModel canvas,
  }) {
    final effectiveScale =
        parentWorld.scale.abs() < 0.00001 ? 1.0 : parentWorld.scale;
    final worldWidth = size.width * effectiveScale;
    final worldHeight = size.height * effectiveScale;
    final targetWorldTopLeft = Offset(
      (canvas.width - worldWidth) / 2,
      (canvas.height - worldHeight) / 2,
    );
    final delta = targetWorldTopLeft - parentWorld.position;
    final cosTheta = math.cos(-parentWorld.rotation);
    final sinTheta = math.sin(-parentWorld.rotation);
    final rotated = Offset(
      delta.dx * cosTheta - delta.dy * sinTheta,
      delta.dx * sinTheta + delta.dy * cosTheta,
    );
    return TransformModel(
      x: rotated.dx / effectiveScale,
      y: rotated.dy / effectiveScale,
      scale: 1,
      rotation: 0,
    );
  }

  bool _moveSelection(int delta) {
    final selected = _selection;
    if (selected == null || selected == 'root' || _selectedIds.length != 1) {
      return false;
    }
    final location = _findNodeLocation(selected);
    if (location == null) {
      return false;
    }

    final parentId = location.parentId;
    var moved = false;
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateChildrenOfParent(
        _project.root,
        parentId,
        (children) {
          final from = location.index;
          final to = from + delta;
          if (to < 0 || to >= children.length) {
            return children;
          }
          moved = true;
          final next = [...children];
          final item = next.removeAt(from);
          next.insert(to, item);
          return next;
        },
      ),
    );
    if (!moved) {
      _layerUndoStack.removeLast();
      return false;
    }
    _onProjectChanged();
    return true;
  }

  NodeModel _removeNodes(NodeModel node, Set<String> ids) {
    if (!node.isGroup || node.children.isEmpty) {
      return node;
    }
    final nextChildren = <NodeModel>[];
    for (final child in node.children) {
      if (ids.contains(child.id)) {
        continue;
      }
      nextChildren.add(_removeNodes(child, ids));
    }
    return node.copyWith(children: nextChildren);
  }

  NodeModel? _findNodeById(NodeModel node, String id) {
    if (node.id == id) {
      return node;
    }
    for (final child in node.children) {
      final found = _findNodeById(child, id);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  bool _isNodeLockedByAncestorsOrSelf(String nodeId) {
    final path = _findPathToNode(nodeId);
    if (path == null) {
      return true;
    }
    for (final node in path) {
      if (node.locked) {
        return true;
      }
    }
    return false;
  }

  List<NodeModel>? _findPathToNode(String id) {
    List<NodeModel>? walk(NodeModel current, List<NodeModel> acc) {
      final next = [...acc, current];
      if (current.id == id) {
        return next;
      }
      for (final child in current.children) {
        final found = walk(child, next);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    return walk(_project.root, const []);
  }

  _NodeLocation? _findNodeLocation(String id) {
    return _findNodeLocationInTree(_project.root, id);
  }
}
