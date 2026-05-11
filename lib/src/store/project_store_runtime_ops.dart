part of 'project_store.dart';

extension ProjectStoreRuntimeOps on ProjectStore {
  bool updateCanvasSize({required double width, required double height}) {
    if (!width.isFinite || !height.isFinite) {
      return false;
    }
    final nextWidth = width.clamp(16.0, 16384.0);
    final nextHeight = height.clamp(16.0, 16384.0);
    final current = _project.canvas;
    if ((current.width - nextWidth).abs() < 0.0001 &&
        (current.height - nextHeight).abs() < 0.0001) {
      return false;
    }
    _pushLayerHistorySnapshot();
    _project = _project.copyWith(
      canvas: CanvasModel(width: nextWidth, height: nextHeight),
    );
    _onProjectChanged();
    return true;
  }

  void setOutputScaleMode(String mode) {
    final next = mode == 'stretch' ? 'stretch' : 'contain';
    if (_outputScaleMode == next) {
      return;
    }
    _outputScaleMode = next;
    _onProjectChanged();
  }

  void toggleOutputScaleMode() {
    setOutputScaleMode(_outputScaleMode == 'contain' ? 'stretch' : 'contain');
  }

  void setLayerTreePanelCollapsed(bool collapsed) {
    final nextLayerTreeCollapsed = collapsed;
    final nextNotesCollapsed = collapsed ? _notesPanelCollapsed : true;
    if (_layerTreePanelCollapsed == nextLayerTreeCollapsed &&
        _notesPanelCollapsed == nextNotesCollapsed) {
      return;
    }
    _layerTreePanelCollapsed = nextLayerTreeCollapsed;
    _notesPanelCollapsed = nextNotesCollapsed;
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

  void toggleLayerTreePanelCollapsed() {
    setLayerTreePanelCollapsed(!_layerTreePanelCollapsed);
  }

  void setNotesPanelCollapsed(bool collapsed) {
    final nextNotesCollapsed = collapsed;
    final nextLayerTreeCollapsed = collapsed ? _layerTreePanelCollapsed : true;
    if (_notesPanelCollapsed == nextNotesCollapsed &&
        _layerTreePanelCollapsed == nextLayerTreeCollapsed) {
      return;
    }
    _notesPanelCollapsed = nextNotesCollapsed;
    _layerTreePanelCollapsed = nextLayerTreeCollapsed;
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

  void toggleNotesPanelCollapsed() {
    setNotesPanelCollapsed(!_notesPanelCollapsed);
  }

  void updateNotesText(String value) {
    if (_notesText == value) {
      return;
    }
    _notesText = value;
    _markLatestProjectJsonDirty();
    _notesNotifier.emit();
  }

  void setDicePanelCollapsed(bool collapsed) {
    _runtime.setDicePanelCollapsed(collapsed);
  }

  void toggleDicePanelCollapsed() {
    _runtime.toggleDicePanelCollapsed();
  }

  bool get darkDiceEnabled => _runtime.darkDiceEnabled;

  void setDarkDiceEnabled(bool enabled) {
    _runtime.setDarkDiceEnabled(enabled);
  }

  /// Global flowing-text output interface.
  /// Keep this API stable so future features can push text without coupling to UI.
  void pushFlowMessage(String text, {Color color = Colors.white}) {
    _runtime.pushFlowMessage(text, color: color);
  }

  void clearFlowMessages() {
    _runtime.clearFlowMessages();
  }

  void setFlowViewport({required double width, required double height}) {
    _runtime.setFlowViewport(width: width, height: height);
  }

  String rollDice(String expression) {
    return _runtime.rollDice(expression);
  }

  String rollPresetDice(int sides) {
    return _runtime.rollPresetDice(sides);
  }

  String rollFateDice({
    int count = 4,
    int bonus = 0,
    FateDiceModifierMode modifierMode = FateDiceModifierMode.none,
  }) {
    return _runtime.rollFateDice(
      count: count,
      bonus: bonus,
      modifierMode: modifierMode,
    );
  }

  void setTrack(String? trackId) {
    _runtime.setTrack(trackId);
  }

  bool isNodeAssetMissing(String nodeId) {
    final node = _findNodeById(_project.root, nodeId);
    if (node == null || node.type != NodeType.image) {
      return false;
    }
    return !_assetPathExists(node.asset);
  }

  bool isAssetPathMissing(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) {
      return false;
    }
    return !_assetPathExists(assetPath);
  }

  String? getNodeAssetPath(String nodeId) {
    final node = _findNodeById(_project.root, nodeId);
    if (node == null || node.type != NodeType.image) {
      return null;
    }
    return _resolveAssetAbsolutePath(node.asset);
  }

  async_lib.Future<bool> relinkNodeAsset(String nodeId) async {
    final node = _findNodeById(_project.root, nodeId);
    if (node == null || node.type != NodeType.image) {
      return false;
    }
    return runWithGlobalLoading(() async {
      final file = await openFile(
        confirmButtonText: '重新选择图片',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '图片',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
          ),
        ],
      );
      if (file == null) {
        return false;
      }
      final nextPath = await _fileService.importImageFile(file.path);
      _pushLayerHistorySnapshot();
      _project = _project.copyWith(
        root: _mutateNode(
          _project.root,
          nodeId,
          (current) => current.copyWith(asset: nextPath),
        ),
      );
      _assetSizeCache.clear();
      _notifyNodeDataListeners([nodeId]);
      _onProjectChanged(
        notifyController: true,
        notifyStage: true,
        notifyLayerTree: false,
        notifyAudio: false,
        notifyDice: false,
        notifyTransform: false,
        invalidateAssetExists: true,
      );
      return true;
    });
  }

  bool isTrackAssetMissing(String trackId) {
    return _runtime.isTrackAssetMissing(trackId);
  }

  String? getTrackAssetPath(String trackId) {
    return _runtime.getTrackAssetPath(trackId);
  }

  async_lib.Future<bool> relinkTrackAsset(String trackId) async {
    return _runtime.relinkTrackAsset(trackId);
  }

  bool moveTrackUp(String trackId) {
    return _runtime.moveTrack(trackId, -1);
  }

  bool moveTrackDown(String trackId) {
    return _runtime.moveTrack(trackId, 1);
  }

  async_lib.Future<bool> deleteTrack(String trackId) async {
    return _runtime.deleteTrack(trackId);
  }

  bool updateTrackTags(String trackId, List<String> tags) {
    return _runtime.updateTrackTags(trackId, tags);
  }

  void toggleLoop() {
    _runtime.toggleLoop();
  }

  void setVolume(double value) {
    _runtime.setVolume(value);
  }

  void playPause() {
    _runtime.playPause();
  }

  void stop() {
    _runtime.stop();
  }

  void _bindAudioPlayer() {
    _runtime.bindAudioPlayer();
  }

  async_lib.Future<void> _applyAudioStateToPlayer() async {
    await _runtime.applyAudioStateToPlayer();
  }

  async_lib.Future<void> _stopAudioSession() async {
    await _runtime.stopAudioSession();
  }

  void _resetRuntimeUiState() {
    _runtime.resetUiState();
  }

  void clearAudioError() {
    _runtime.clearAudioError();
  }

  void _setAudioError(String? value) {
    _runtime.setAudioError(value);
  }

  void _onProjectChanged({
    bool notifyController = true,
    bool notifyStage = true,
    bool notifyLayerTree = true,
    bool notifyAudio = true,
    bool notifyDice = true,
    bool notifyTransform = true,
    bool invalidateRenderList = true,
    bool invalidateAssetExists = false,
  }) {
    _invalidateDerivedCaches(
      renderList: invalidateRenderList,
      assetExists: invalidateAssetExists,
    );
    _markLatestProjectJsonDirty();
    _notifyStoreListeners(
      notifyController: notifyController,
      notifyStage: notifyStage,
      notifyLayerTree: notifyLayerTree,
      notifyAudio: notifyAudio,
      notifyDice: notifyDice,
      notifyTransform: notifyTransform,
    );
  }

  async_lib.Future<void> _saveNow() async {
    final filePath = _projectFilePath;
    if (filePath == null || filePath.isEmpty) {
      return;
    }
    await _fileService.saveProject(filePath, _projectWithRuntimeUiState());
  }
}
