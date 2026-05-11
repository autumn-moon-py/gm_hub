import 'dart:async' as async_lib;

import 'package:flutter/material.dart';

import '../../model/project_model.dart';
import '../../model/render_item.dart';
import '../../store/project_store.dart';

enum LayerDropPlacement { before, after, into }

class NotesEditorViewState {
  const NotesEditorViewState({
    this.selection,
    this.scrollOffset = 0,
  });

  final TextSelection? selection;
  final double scrollOffset;

  NotesEditorViewState copyWith({
    TextSelection? selection,
    bool clearSelection = false,
    double? scrollOffset,
  }) {
    return NotesEditorViewState(
      selection: clearSelection ? null : (selection ?? this.selection),
      scrollOffset: scrollOffset ?? this.scrollOffset,
    );
  }
}

class MainShellUiFacade {
  MainShellUiFacade(ProjectStore store)
      : stage = StageEditorFacade(store),
        layerTree = LayerTreeFacade(store),
        audio = AudioControlFacade(store),
        dice = DiceControlFacade(store);

  final StageEditorFacade stage;
  final LayerTreeFacade layerTree;
  final AudioControlFacade audio;
  final DiceControlFacade dice;
}

class StageEditorFacade {
  StageEditorFacade(this._store);

  final ProjectStore _store;
  ProjectStore get store => _store;
  Listenable get selectionListenable => _store.selectionListenable;
  Listenable get stageListenable => _store.stageListenable;
  Listenable get transformListenable => _store.transformListenable;
  Listenable selectionListenableForNode(String nodeId) =>
      _store.selectionListenableForNode(nodeId);

  List<RenderItem> buildRenderList() => _store.buildRenderList();
  String? get selection => _store.selection;
  ProjectModel get project => _store.project;
  Set<String> get selectedIds => _store.selectedIds;
  NodeModel? get selectedNode => _store.selectedNode;
  List<FlowMessageItem> get flowMessages => _store.flowMessages;
  Listenable get globalLoadingListenable => _store.globalLoadingListenable;

  void selectNode(String id) => _store.selectNode(id);
  void clearSelection() => _store.clearSelection();
  void beginDragSelection() => _store.beginLayerDragUndoTransaction();
  void endDragSelection() => _store.endLayerDragUndoTransaction();
  void nudgeSelection(Offset delta) => _store.nudgeSelection(delta);
  void scaleSelection(double factor) => _store.scaleSelection(factor);
  void rotateSelection(double deltaRadians) =>
      _store.rotateSelection(deltaRadians);
  bool alignLeft() => _store.alignSelected(AlignAction.left);
  bool alignHCenter() => _store.alignSelected(AlignAction.hCenter);
  bool alignRight() => _store.alignSelected(AlignAction.right);
  bool alignTop() => _store.alignSelected(AlignAction.top);
  bool alignVCenter() => _store.alignSelected(AlignAction.vCenter);
  bool alignBottom() => _store.alignSelected(AlignAction.bottom);
  bool distributeH() => _store.alignSelected(AlignAction.distributeH);
  bool distributeV() => _store.alignSelected(AlignAction.distributeV);
  bool centerSelectionHorizontally() => _store.centerSelectionHorizontally();
  bool centerSelectionVertically() => _store.centerSelectionVertically();
  void resetSelectionRotation() => _store.resetSelectionRotation();
  bool resetSelectionImageTransform() => _store.resetSelectionImageTransform();
  bool stretchSelectionToOutputSize() => _store.stretchSelectionToOutputSize();
  bool updateSelectedTextLayer({
    String? text,
    double? fontSize,
    int? textColorValue,
  }) {
    return _store.updateSelectedTextLayer(
      text: text,
      fontSize: fontSize,
      textColorValue: textColorValue,
    );
  }

  void setFlowViewport({
    required double width,
    required double height,
  }) {
    _store.setFlowViewport(width: width, height: height);
  }
}

class LayerTreeFacade {
  LayerTreeFacade(this._store);

  final ProjectStore _store;
  NotesEditorViewState _notesEditorViewState = const NotesEditorViewState();
  String? _rangeSelectionAnchorId;
  ProjectStore get store => _store;
  Listenable get selectionListenable => _store.selectionListenable;
  Listenable get treeListenable => _store.layerTreeListenable;
  Listenable get notesListenable => _store.notesListenable;
  Listenable selectionListenableForNode(String nodeId) =>
      _store.selectionListenableForNode(nodeId);
  Listenable nodeDataListenableForNode(String nodeId) =>
      _store.nodeDataListenableForNode(nodeId);

  ProjectModel get project => _store.project;
  String? get selection => _store.selection;
  String? get selectionName => _store.selectionName;
  Set<String> get selectedIds => _store.selectedIds;
  NodeModel? getNodeById(String nodeId) => _store.getNodeById(nodeId);

  bool isGroupCollapsed(String nodeId) => _store.isGroupCollapsed(nodeId);
  bool isNodeAssetMissing(String nodeId) => _store.isNodeAssetMissing(nodeId);
  bool isAssetPathMissing(String? assetPath) =>
      _store.isAssetPathMissing(assetPath);
  String? getNodeAssetPath(String nodeId) => _store.getNodeAssetPath(nodeId);
  async_lib.Future<bool> relinkNodeAsset(String nodeId) =>
      _store.relinkNodeAsset(nodeId);
  bool renameSelection(String newName) => _store.renameSelection(newName);
  bool get layerTreePanelCollapsed => _store.layerTreePanelCollapsed;
  bool get notesPanelCollapsed => _store.notesPanelCollapsed;
  String get notesText => _store.notesText;
  NotesEditorViewState get notesEditorViewState => _notesEditorViewState;
  String? get rangeSelectionAnchorId => _rangeSelectionAnchorId;
  bool get globalLoading => _store.globalLoading;
  Listenable get globalLoadingListenable => _store.globalLoadingListenable;

  void selectNode(String id) {
    _store.selectNode(id);
    _rangeSelectionAnchorId = id;
  }

  void clearSelection() {
    _store.clearSelection();
    _rangeSelectionAnchorId = null;
  }

  void selectNodeRange(String id, List<String> orderedNodeIds) {
    if (orderedNodeIds.isEmpty) {
      selectNode(id);
      _rangeSelectionAnchorId = id;
      return;
    }
    final anchorId = _rangeSelectionAnchorId ?? selection ?? id;
    final anchorIndex = orderedNodeIds.indexOf(anchorId);
    final targetIndex = orderedNodeIds.indexOf(id);
    if (anchorIndex < 0 || targetIndex < 0) {
      selectNode(id);
      _rangeSelectionAnchorId = id;
      return;
    }
    final start = anchorIndex < targetIndex ? anchorIndex : targetIndex;
    final end = anchorIndex > targetIndex ? anchorIndex : targetIndex;
    _store.selectNodeRange(
      orderedNodeIds.sublist(start, end + 1),
      primaryId: id,
    );
    _rangeSelectionAnchorId = anchorId;
  }

  void toggleMultiSelect(String id) {
    _store.toggleMultiSelect(id);
    if (selectedIds.contains(id)) {
      _rangeSelectionAnchorId = id;
    } else if (_rangeSelectionAnchorId == id) {
      _rangeSelectionAnchorId = selection;
    }
  }

  void toggleGroupCollapse(String nodeId) => _store.toggleGroupCollapse(nodeId);
  void toggleNodeVisible(String nodeId) => _store.toggleNodeVisible(nodeId);
  void toggleNodeLocked(String nodeId) => _store.toggleNodeLocked(nodeId);
  void toggleLayerTreePanelCollapsed() =>
      _store.toggleLayerTreePanelCollapsed();
  void toggleNotesPanelCollapsed() => _store.toggleNotesPanelCollapsed();
  void updateNotesText(String value) => _store.updateNotesText(value);
  void updateNotesEditorViewState(NotesEditorViewState value) {
    _notesEditorViewState = value;
  }

  bool canDropNode({
    required String draggedId,
    required String targetId,
    LayerDropPlacement placement = LayerDropPlacement.before,
  }) {
    final mapped = _mapDropPlacement(placement);
    return _store.canDropNode(
      draggedId: draggedId,
      targetId: targetId,
      placement: mapped,
    );
  }

  bool moveNodeByDrop({
    required String draggedId,
    required String targetId,
    LayerDropPlacement placement = LayerDropPlacement.before,
  }) {
    final mapped = _mapDropPlacement(placement);
    return _store.moveNodeByDrop(
      draggedId: draggedId,
      targetId: targetId,
      placement: mapped,
    );
  }

  List<String> resolveDraggedNodeIds(String draggedId) {
    final selected =
        selectedIds.where((id) => id != 'root').toList(growable: false);
    if (!selected.contains(draggedId)) {
      return [draggedId];
    }
    return selected;
  }

  DropPlacement _mapDropPlacement(LayerDropPlacement placement) {
    switch (placement) {
      case LayerDropPlacement.before:
        return DropPlacement.before;
      case LayerDropPlacement.after:
        return DropPlacement.after;
      case LayerDropPlacement.into:
        return DropPlacement.into;
    }
  }

  async_lib.Future<void> addImageLayer() => _store.addImageLayer();
  async_lib.Future<void> importDroppedFiles(List<String> paths) =>
      _store.importDroppedFiles(paths);
  async_lib.Future<void> importDroppedImageFiles(List<String> paths) =>
      _store.importDroppedImageFiles(paths);
  void addTextLayer() => _store.addTextLayer();
  void addGroup() => _store.addGroup();
  bool groupSelected() => _store.groupSelected();
  bool ungroupSelection() => _store.ungroupSelection();
  bool moveSelectionUp() => _store.moveSelectionUp();
  bool moveSelectionDown() => _store.moveSelectionDown();
  void deleteSelected() => _store.deleteSelected();
}

class AudioControlFacade {
  AudioControlFacade(this._store);

  final ProjectStore _store;
  ProjectStore get store => _store;
  Listenable get audioListenable => _store.audioListenable;

  AudioStateModel get audioState => _store.project.audioState;
  List<AudioTrackModel> get tracks => _store.project.tracks;
  String? get audioError => _store.audioError;
  bool get globalLoading => _store.globalLoading;
  Listenable get globalLoadingListenable => _store.globalLoadingListenable;

  void setTrack(String? trackId) => _store.setTrack(trackId);
  bool isTrackAssetMissing(String trackId) =>
      _store.isTrackAssetMissing(trackId);
  String? getTrackAssetPath(String trackId) =>
      _store.getTrackAssetPath(trackId);
  async_lib.Future<bool> relinkTrackAsset(String trackId) =>
      _store.relinkTrackAsset(trackId);
  async_lib.Future<void> importTrack() => _store.importMp3Track();
  bool moveTrackUp(String trackId) => _store.moveTrackUp(trackId);
  bool moveTrackDown(String trackId) => _store.moveTrackDown(trackId);
  async_lib.Future<bool> deleteTrack(String trackId) =>
      _store.deleteTrack(trackId);
  bool updateTrackTags(String trackId, List<String> tags) =>
      _store.updateTrackTags(trackId, tags);
  void playPause() => _store.playPause();
  void stop() => _store.stop();
  void toggleLoop() => _store.toggleLoop();
  void setVolume(double value) => _store.setVolume(value);
  void clearAudioError() => _store.clearAudioError();
}

class DiceControlFacade {
  DiceControlFacade(this._store);

  final ProjectStore _store;
  ProjectStore get store => _store;
  Listenable get diceListenable => _store.diceListenable;

  bool get dicePanelCollapsed => _store.dicePanelCollapsed;
  bool get darkDiceEnabled => _store.darkDiceEnabled;
  bool get globalLoading => _store.globalLoading;
  Listenable get globalLoadingListenable => _store.globalLoadingListenable;
  void toggleDicePanelCollapsed() => _store.toggleDicePanelCollapsed();
  void setDarkDiceEnabled(bool enabled) => _store.setDarkDiceEnabled(enabled);
  String rollDice(String expression) => _store.rollDice(expression);
  String rollPresetDice(int sides) => _store.rollPresetDice(sides);
  String rollFateDice({
    int bonus = 0,
    FateDiceModifierMode modifierMode = FateDiceModifierMode.none,
  }) =>
      _store.rollFateDice(bonus: bonus, modifierMode: modifierMode);
  void clearFlowMessages() => _store.clearFlowMessages();
}
