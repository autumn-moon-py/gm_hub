part of 'project_store.dart';

extension ProjectStoreProjectOps on ProjectStore {
  bool isGroupCollapsed(String nodeId) => _collapsedGroupIds.contains(nodeId);

  void _restoreStoredUiState() {
    final uiState = _project.uiState;
    _collapsedGroupIds
      ..clear()
      ..addAll(uiState.collapsedGroupIds);
    _outputScaleMode =
        uiState.outputScaleMode == 'contain' ? 'contain' : 'stretch';
    _layerTreePanelCollapsed = uiState.layerTreePanelCollapsed;
    _notesPanelCollapsed = uiState.notesPanelCollapsed;
    if (!_layerTreePanelCollapsed && !_notesPanelCollapsed) {
      _notesPanelCollapsed = true;
    }
    _notesText = uiState.notesText;
  }

  void toggleGroupCollapse(String nodeId) {
    if (_collapsedGroupIds.contains(nodeId)) {
      _collapsedGroupIds.remove(nodeId);
    } else {
      _collapsedGroupIds.add(nodeId);
    }
    _markLatestProjectJsonDirty();
    _notifyStoreListeners(
      notifyController: false,
      notifyStage: false,
      notifyLayerTree: true,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
    );
  }

  async_lib.Future<void> _bootstrap() async {
    final projectFilePath = _projectFilePath;
    if (projectFilePath == null) {
      return;
    }
    final loaded = await _fileService.loadProject(projectFilePath);
    _clearLayerHistory();
    _resetRuntimeUiState();
    if (loaded != null) {
      _project = loaded;
      _invalidateDerivedCaches(assetExists: true);
      _refreshIdSeedFromProject();
      _restoreStoredUiState();
      _markLatestProjectJsonDirty();
      await _applyAudioStateToPlayer();
      _notifyStoreListeners();
      return;
    }
    _refreshIdSeedFromProject();
    await _applyAudioStateToPlayer();
    _onProjectChanged();
  }

  async_lib.Future<void> createOrOpenProjectInDirectory(
    String projectFilePath,
  ) async {
    await _stopAudioSession();
    _setProjectFilePath(projectFilePath);
    _clearLayerHistory();
    final loaded = await _fileService.loadProject(projectFilePath);
    _project = loaded ?? ProjectModel.initial();
    _invalidateDerivedCaches(assetExists: true);
    _refreshIdSeedFromProject();
    _assetSizeCache.clear();
    _restoreStoredUiState();
    _selection = null;
    _selectedIds.clear();
    _resetRuntimeUiState();
    _markLatestProjectJsonDirty();
    await _applyAudioStateToPlayer();
    _notifyStoreListeners();
  }

  async_lib.Future<void> createNewProject({
    required String name,
    String? filePath,
  }) async {
    final targetFile = filePath ??
        _projectFilePath ??
        p.join(
          Directory.current.path,
          ProjectFileService.defaultProjectFileName,
        );
    _setProjectFilePath(targetFile);
    await _stopAudioSession();
    _clearLayerHistory();

    _project = ProjectModel.initial().copyWith(
      name: name.trim().isEmpty ? '主持中枢项目' : name.trim(),
      uiState: const UiStateModel.initial(),
    );
    _invalidateDerivedCaches(assetExists: true);
    _refreshIdSeedFromProject();
    _selection = null;
    _selectedIds.clear();
    _restoreStoredUiState();
    _resetRuntimeUiState();
    _assetSizeCache.clear();
    _markLatestProjectJsonDirty();
    await _applyAudioStateToPlayer();
    _notifyStoreListeners();
  }

  async_lib.Future<void> chooseDirectoryAndCreateNewProject({
    required String name,
  }) async {
    final location = await getSaveLocation(
      suggestedName: _buildSuggestedProjectFileName(name),
      confirmButtonText: '保存项目',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '主持中枢项目文件',
          extensions: [ProjectFileService.projectFileExtension],
        ),
      ],
    );
    final path = location?.path;
    if (path == null || path.isEmpty) {
      return;
    }
    await createNewProject(name: name, filePath: path);
  }

  async_lib.Future<void> chooseAndOpenProjectDirectory() async {
    final file = await openFile(
      confirmButtonText: '打开项目',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '主持中枢项目文件',
          extensions: [ProjectFileService.projectFileExtension, 'json'],
        ),
      ],
    );
    final path = file?.path;
    if (path == null || path.isEmpty) {
      return;
    }
    await createOrOpenProjectInDirectory(path);
  }

  async_lib.Future<bool> saveProject() async {
    try {
      await _saveNow();
      return true;
    } catch (e, st) {
      debugPrint('saveProject failed: $e\n$st');
      return false;
    }
  }

  async_lib.Future<bool> saveProjectAs() async {
    final location = await getSaveLocation(
      suggestedName: _buildSuggestedProjectFileName(_project.name),
      confirmButtonText: '保存项目',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '主持中枢项目文件',
          extensions: [ProjectFileService.projectFileExtension],
        ),
      ],
    );
    final path = location?.path;
    if (path == null || path.isEmpty) {
      return false;
    }

    try {
      _setProjectFilePath(path);
      await _saveNow();
      _notifyStoreListeners();
      return true;
    } catch (e, st) {
      debugPrint('saveProjectAs failed: $e\n$st');
      return false;
    }
  }

  async_lib.Future<void> clearProject() async {
    final currentName = _project.name;
    await _stopAudioSession();
    _clearLayerHistory();
    _project = ProjectModel.initial().copyWith(
      name: currentName,
      uiState: const UiStateModel.initial(),
    );
    _invalidateDerivedCaches(assetExists: true);
    _refreshIdSeedFromProject();
    _selection = null;
    _selectedIds.clear();
    _restoreStoredUiState();
    _resetRuntimeUiState();
    _assetSizeCache.clear();
    _markLatestProjectJsonDirty();
    await _applyAudioStateToPlayer();
    _notifyStoreListeners();
  }

  async_lib.Future<void> importImageAsLayer() async {
    await runWithGlobalLoading(() async {
      final files = await openFiles(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '图片',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
          ),
        ],
      );
      if (files.isEmpty) {
        return;
      }
      final parentId = _resolveInsertParentId();
      final parentWorld = _resolveWorldTransform(parentId);
      final nodes = <NodeModel>[];
      for (final file in files) {
        final relPath = await _fileService.importImageFile(file.path);
        final absPath = _resolveAssetAbsolutePath(relPath);
        final size = _resolveAssetSize(absPath);
        nodes.add(
          NodeModel(
            id: _nextId('img'),
            type: NodeType.image,
            name: p.basenameWithoutExtension(file.name),
            visible: true,
            locked: false,
            opacity: 1,
            transform: _buildCenteredLocalTransform(
              size: size,
              parentWorld: parentWorld,
              canvas: _project.canvas,
            ),
            asset: relPath,
          ),
        );
      }
      _pushLayerHistorySnapshot();
      _assetSizeCache.clear();
      _project = _project.copyWith(
        root: _mutateChildrenOfParent(
          _project.root,
          parentId,
          (children) => [...children, ...nodes],
        ),
      );
      final last = nodes.last;
      _selection = last.id;
      _selectedIds
        ..clear()
        ..add(last.id);
      _onProjectChanged();
    });
  }

  async_lib.Future<void> importDroppedImageFiles(List<String> paths) async {
    await runWithGlobalLoading(() async {
      final validPaths = paths.where((path) {
        final ext = path.toLowerCase();
        return ext.endsWith('.png') ||
            ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.webp') ||
            ext.endsWith('.bmp');
      }).toList();
      if (validPaths.isEmpty) {
        return;
      }
      final parentId = _resolveInsertParentId();
      final parentWorld = _resolveWorldTransform(parentId);
      final nodes = <NodeModel>[];
      for (final path in validPaths) {
        final relPath = await _fileService.importImageFile(path);
        final absPath = _resolveAssetAbsolutePath(relPath);
        final size = _resolveAssetSize(absPath);
        final name = p.basenameWithoutExtension(path);
        nodes.add(
          NodeModel(
            id: _nextId('img'),
            type: NodeType.image,
            name: name,
            visible: true,
            locked: false,
            opacity: 1,
            transform: _buildCenteredLocalTransform(
              size: size,
              parentWorld: parentWorld,
              canvas: _project.canvas,
            ),
            asset: relPath,
          ),
        );
      }
      _pushLayerHistorySnapshot();
      _assetSizeCache.clear();
      _project = _project.copyWith(
        root: _mutateChildrenOfParent(
          _project.root,
          parentId,
          (children) => [...children, ...nodes],
        ),
      );
      final last = nodes.last;
      _selection = last.id;
      _selectedIds
        ..clear()
        ..add(last.id);
      _onProjectChanged();
    });
  }

  async_lib.Future<void> importMp3Track() async {
    await runWithGlobalLoading(() async {
      final files = await openFiles(
        acceptedTypeGroups: const [
          XTypeGroup(label: '音频', extensions: ['mp3']),
        ],
      );
      if (files.isEmpty) {
        return;
      }
      final tracks = <AudioTrackModel>[];
      for (final file in files) {
        final relPath = await _fileService.importAudioFile(file.path);
        tracks.add(
          AudioTrackModel(
            id: _nextId('track'),
            name: p.basenameWithoutExtension(file.name),
            asset: relPath,
          ),
        );
      }
      final currentTrack = tracks.last;
      _project = _project.copyWith(
        tracks: [..._project.tracks, ...tracks],
        audioState: _project.audioState.copyWith(
          currentTrackId: currentTrack.id,
          isPlaying: false,
        ),
      );
      _setAudioError(null);
      _onProjectChanged();
    });
  }

  List<RenderItem> buildRenderList() {
    final cached = _renderListCache;
    if (cached != null) {
      return cached;
    }
    final result = <RenderItem>[];
    _dfsCollect(
      node: _project.root,
      parentVisible: true,
      parentLocked: false,
      parentPreserveAspect: false,
      parentWorldPos: Offset.zero,
      parentWorldScale: 1,
      parentWorldRotation: 0,
      parentOpacity: 1,
      depth: 0,
      output: result,
    );
    final next = List<RenderItem>.unmodifiable(result);
    _renderListCache = next;
    return next;
  }

  void selectNode(String id) {
    if (_selection == id &&
        _selectedIds.length == 1 &&
        _selectedIds.contains(id)) {
      return;
    }
    final previousSelectedIds = Set<String>.from(_selectedIds);
    final previousPrimarySelection = _selection;
    _selection = id;
    _selectedIds
      ..clear()
      ..add(id);
    _notifySelectionListeners(
      previousSelectedIds: previousSelectedIds,
      previousPrimarySelection: previousPrimarySelection,
    );
  }

  void clearSelection() {
    if (_selection == null && _selectedIds.isEmpty) {
      return;
    }
    final previousSelectedIds = Set<String>.from(_selectedIds);
    final previousPrimarySelection = _selection;
    _selection = null;
    _selectedIds.clear();
    _notifySelectionListeners(
      previousSelectedIds: previousSelectedIds,
      previousPrimarySelection: previousPrimarySelection,
    );
  }

  void selectNodeRange(Iterable<String> ids, {String? primaryId}) {
    final nextSelected = ids
        .where((id) =>
            id.isNotEmpty &&
            id != 'root' &&
            _findNodeById(_project.root, id) != null)
        .toSet();
    if (nextSelected.isEmpty) {
      clearSelection();
      return;
    }
    final nextPrimary = (primaryId != null && nextSelected.contains(primaryId))
        ? primaryId
        : nextSelected.last;
    if (_selection == nextPrimary &&
        _selectedIds.length == nextSelected.length &&
        _selectedIds.containsAll(nextSelected)) {
      return;
    }
    final previousSelectedIds = Set<String>.from(_selectedIds);
    final previousPrimarySelection = _selection;
    _selection = nextPrimary;
    _selectedIds
      ..clear()
      ..addAll(nextSelected);
    _notifySelectionListeners(
      previousSelectedIds: previousSelectedIds,
      previousPrimarySelection: previousPrimarySelection,
    );
  }

  void toggleMultiSelect(String id) {
    final previousSelectedIds = Set<String>.from(_selectedIds);
    final previousPrimarySelection = _selection;
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selection == id) {
        _selection = _selectedIds.isEmpty ? null : _selectedIds.first;
      }
    } else {
      _selectedIds.add(id);
      _selection = id;
    }
    _notifySelectionListeners(
      previousSelectedIds: previousSelectedIds,
      previousPrimarySelection: previousPrimarySelection,
    );
  }

  void toggleNodeVisible(String id) {
    if (_findNodeById(_project.root, id) == null) {
      return;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        id,
        (node) => node.copyWith(visible: !node.visible),
      ),
    );
    _notifyNodeDataListeners([id]);
    _onProjectChanged(
      notifyController: true,
      notifyStage: true,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
      invalidateRenderList: true,
    );
  }

  void toggleNodeLocked(String id) {
    if (_findNodeById(_project.root, id) == null) {
      return;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        id,
        (node) => node.copyWith(locked: !node.locked),
      ),
    );
    _notifyNodeDataListeners([id]);
    _onProjectChanged(
      notifyController: false,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
      invalidateRenderList: false,
    );
  }

  async_lib.Future<void> addImageLayer() => importImageAsLayer();

  void addGroup() {
    final parentId = _resolveInsertParentId();
    final node = NodeModel(
      id: _nextId('group'),
      type: NodeType.group,
      name: '分组',
      visible: true,
      locked: false,
      opacity: 1,
      transform: const TransformModel.identity(),
      children: const [],
    );
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateChildrenOfParent(
        _project.root,
        parentId,
        (children) => [...children, node],
      ),
    );
    selectNode(node.id);
    _onProjectChanged();
  }

  void addTextLayer() {
    final parentId = _resolveInsertParentId();
    final parentWorld = _resolveWorldTransform(parentId);
    final node = NodeModel(
      id: _nextId('text'),
      type: NodeType.text,
      name: '文字',
      visible: true,
      locked: false,
      opacity: 1,
      text: '新建文字',
      fontSize: 34,
      textColorValue: 0xFFFFFFFF,
      transform: _buildCenteredLocalTransform(
        size: _resolveTextNodeSize(
          const NodeModel(
            id: '',
            type: NodeType.text,
            name: '',
            visible: true,
            locked: false,
            opacity: 1,
            transform: TransformModel.identity(),
            text: '新建文字',
            fontSize: 34,
            textColorValue: 0xFFFFFFFF,
          ),
        ),
        parentWorld: parentWorld,
        canvas: _project.canvas,
      ),
    );
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateChildrenOfParent(
        _project.root,
        parentId,
        (children) => [...children, node],
      ),
    );
    selectNode(node.id);
    _onProjectChanged();
  }

  bool updateSelectedTextLayer({
    String? text,
    double? fontSize,
    int? textColorValue,
  }) {
    final selectedId = _selection;
    if (selectedId == null) {
      return false;
    }
    final selected = _findNodeById(_project.root, selectedId);
    if (selected == null || selected.type != NodeType.text) {
      return false;
    }
    final nextText = text?.trim();
    final nextFontSize =
        fontSize == null ? selected.fontSize : fontSize.clamp(8.0, 256.0);
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        selectedId,
        (node) => node.copyWith(
          text: (nextText == null || nextText.isEmpty) ? node.text : nextText,
          fontSize: nextFontSize,
          textColorValue: textColorValue ?? node.textColorValue,
        ),
      ),
    );
    _assetSizeCache.clear();
    _onProjectChanged();
    return true;
  }

  void deleteSelected() {
    final targets = _selectedIds.where((id) => id != 'root').toSet();
    if (targets.isEmpty && _selection != null && _selection != 'root') {
      targets.add(_selection!);
    }
    if (targets.isEmpty) {
      return;
    }

    _pushLayerHistorySnapshot();
    _project = _project.copyWith(root: _removeNodes(_project.root, targets));
    _selectedIds.removeWhere(targets.contains);
    if (_selection != null && targets.contains(_selection)) {
      _selection = _selectedIds.isEmpty ? null : _selectedIds.first;
    }
    _onProjectChanged();
  }

  bool renameSelection(String newName) {
    final target = _selection;
    if (target == null || newName.trim().isEmpty) {
      return false;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      root: _mutateNode(
        _project.root,
        target,
        (node) => node.copyWith(name: newName.trim()),
      ),
    );
    _notifyNodeDataListeners([target]);
    _onProjectChanged(
      notifyController: false,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
      invalidateRenderList: false,
    );
    return true;
  }

  bool moveSelectionUp() => _moveSelection(-1);
}
