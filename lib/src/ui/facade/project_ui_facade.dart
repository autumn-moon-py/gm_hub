import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../model/battle_model.dart';
import '../../model/project_model.dart';
import '../../model/render_item.dart';
import '../../output/sync_render_payload.dart';
import '../../store/project_store.dart';

enum LayerDropPlacement { before, after, into }

class _NotesFontSizeNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

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
        dice = DiceControlFacade(store),
        battle = BattleShellFacade(store);

  final StageEditorFacade stage;
  final LayerTreeFacade layerTree;
  final AudioControlFacade audio;
  final DiceControlFacade dice;
  final BattleShellFacade battle;
}

class BattleShellFacade {
  BattleShellFacade(this._store);

  final ProjectStore _store;

  Listenable get battleListenable => _store.battleListenable;
  BattleModuleModel get battle => _store.project.battle;
  List<NpcTemplateModel> get npcTemplates => battle.library.npcTemplates;
  List<PlayerResourceModel> get playerResources =>
      battle.library.playerResources;
  List<BattleRosterResolvedEntryViewModel> get defaultRosterResolvedEntries {
    final entries = battle.defaultRoster;
    final lastIndex = entries.length - 1;
    return [
      for (var index = 0; index < entries.length; index += 1)
        _resolveDefaultRosterEntry(
          entry: entries[index],
          index: index,
          lastIndex: lastIndex,
        ),
    ];
  }
  List<BattleRosterLibraryCandidateViewModel> get defaultRosterCandidates => [
        ...npcTemplates.map(
          (template) => BattleRosterLibraryCandidateViewModel(
            resourceId: template.id,
            kind: BattleEntityKind.npc,
            name: template.name,
            subtitle: 'NPC 模板',
          ),
        ),
        ...playerResources.map(
          (resource) => BattleRosterLibraryCandidateViewModel(
            resourceId: resource.id,
            kind: BattleEntityKind.player,
            name: resource.name,
            subtitle: '玩家展示对象',
          ),
        ),
      ];
  List<BattleSceneImageCandidate> get currentSceneImageCandidates {
    final candidates = <BattleSceneImageCandidate>[];

    NodeModel? resolvePlayerSourceRoot(NodeModel node) {
      if (node.id == 'group_player') {
        return node;
      }
      if (node.isGroup && node.name.trim() == '玩家') {
        return node;
      }
      for (final child in node.children) {
        final found = resolvePlayerSourceRoot(child);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    void visit(NodeModel node) {
      if (node.type == NodeType.image) {
        final asset = (node.asset ?? '').trim();
        if (asset.isNotEmpty) {
          final name = node.name.trim().isEmpty ? '未命名图层' : node.name.trim();
          candidates.add(
            BattleSceneImageCandidate(
              nodeId: node.id,
              name: name,
              asset: asset,
            ),
          );
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    final playerSourceRoot = resolvePlayerSourceRoot(_store.project.root);
    if (playerSourceRoot == null) {
      return const [];
    }
    visit(playerSourceRoot);
    return candidates;
  }

  List<BattleSceneImageCandidate> get currentSceneNpcImageCandidates {
    final candidates = <BattleSceneImageCandidate>[];

    NodeModel? resolveNpcSourceRoot(NodeModel node) {
      if (node.id == 'group_npc') {
        return node;
      }
      if (node.isGroup && node.name.trim() == 'NPC') {
        return node;
      }
      for (final child in node.children) {
        final found = resolveNpcSourceRoot(child);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    void visit(NodeModel node) {
      if (node.type == NodeType.image) {
        final asset = (node.asset ?? '').trim();
        if (asset.isNotEmpty) {
          final name = node.name.trim().isEmpty ? '未命名图层' : node.name.trim();
          candidates.add(
            BattleSceneImageCandidate(
              nodeId: node.id,
              name: name,
              asset: asset,
            ),
          );
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    final npcSourceRoot = resolveNpcSourceRoot(_store.project.root);
    if (npcSourceRoot == null) {
      return const [];
    }
    visit(npcSourceRoot);
    return candidates;
  }

  BattleEntityModel? get selectedBattleEntity {
    final selectedEntityId = battle.workspace.selectedEntityId;
    if (selectedEntityId == null) {
      return null;
    }
    for (final entity in battle.workspace.entities) {
      if (entity.id == selectedEntityId) {
        return entity;
      }
    }
    return null;
  }

  ProjectMode get currentMode => _store.project.currentMode;
  DiceControlFacade get diceFacade => DiceControlFacade(_store);
  bool get defaultRosterHasMissingResources =>
      _store.hasMissingResourcesInDefaultRoster();
  SyncBattlePayload get previewBattlePayload =>
      SyncBattlePayload.fromStore(_store);
  ProjectModel get project => _store.project;
  String get outputScaleMode => _store.outputScaleMode;
  List<RenderItem> get sceneBackgroundRenderList =>
      _store.buildRenderListForNode('group_background');
  BattleAnimationState get battleAnimation =>
      _store.project.battle.animation;
  Listenable get stageListenable => _store.stageListenable;
  List<FlowMessageItem> get flowMessages => _store.flowMessages;

  void setFlowViewport({required double width, required double height}) {
    _store.setFlowViewport(width: width, height: height);
  }

  void setAnimAction({
    required String activeEntityId,
    required String targetEntityId,
    required BattleAnimAction activeAction,
    required BattleAnimAction targetAction,
  }) {
    _store.setAnimAction(
      activeEntityId: activeEntityId,
      targetEntityId: targetEntityId,
      activeAction: activeAction,
      targetAction: targetAction,
    );
  }

  void triggerAnimation() => _store.triggerAnimation();
  void ensureAnimEntities() => _store.ensureAnimEntities();
  void rebindAnimEntities(String activeEntityId) =>
      _store.rebindAnimEntities(activeEntityId);

  NpcTemplateModel? resolveNpcTemplate(String resourceId) {
    for (final template in battle.library.npcTemplates) {
      if (template.id == resourceId) {
        return template;
      }
    }
    return null;
  }

  PlayerResourceModel? resolvePlayerResource(String resourceId) {
    for (final resource in battle.library.playerResources) {
      if (resource.id == resourceId) {
        return resource;
      }
    }
    return null;
  }

  void setBattlePage(BattlePage page) => _store.setBattlePage(page);
  void setBattleOutputShowing(bool value) =>
      _store.setBattleOutputShowing(value);
  void selectBattleEntity(String? entityId) =>
      _store.selectBattleEntity(entityId);
  void createNpcTemplate() => _store.createNpcTemplate();
  void importNpcTemplatesFromSceneNodeIds(List<String> nodeIds) =>
      _store.importNpcTemplatesFromSceneNodeIds(nodeIds);
  void importPlayerResourcesFromCurrentScene() =>
      _store.importPlayerResourcesFromCurrentScene();
  void importPlayerResourcesFromSceneNodeIds(List<String> nodeIds) =>
      _store.importPlayerResourcesFromSceneNodeIds(nodeIds);
  void updateNpcTemplate({
    required String templateId,
    String? name,
    String? traitText,
    int? maxHp,
    int? keyBonus,
    BattleResourcePortraitBinding? portrait,
    bool updatePortrait = false,
  }) {
    _store.updateNpcTemplate(
      templateId: templateId,
      name: name,
      traitText: traitText,
      maxHp: maxHp,
      keyBonus: keyBonus,
      portrait: portrait,
      updatePortrait: updatePortrait,
    );
  }

  void updateNpcTemplatePortrait(String templateId, String? asset) {
    final trimmedAsset = asset?.trim() ?? '';
    updateNpcTemplate(
      templateId: templateId,
      portrait: trimmedAsset.isEmpty
          ? null
          : BattleResourcePortraitBinding(asset: trimmedAsset),
      updatePortrait: true,
    );
  }

  bool deleteNpcTemplate(String templateId) =>
      _store.deleteNpcTemplate(templateId);

  bool isNpcTemplatePortraitMissing(String templateId) {
    final template = resolveNpcTemplate(templateId);
    return _store.isAssetPathMissing(template?.portrait?.asset);
  }

  Future<bool> relinkNpcTemplatePortrait(String templateId) async {
    final file = await openFile(
      confirmButtonText: '重新选择图片',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '图片',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        ),
      ],
    );
    final path = file?.path;
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    updateNpcTemplatePortrait(templateId, path);
    return true;
  }

  Future<bool> bindNpcTemplatePortraitFromExternal(String templateId) async {
    final file = await openFile(
      confirmButtonText: '选择图片',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '图片',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        ),
      ],
    );
    final path = file?.path;
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    updateNpcTemplatePortrait(templateId, path);
    return true;
  }

  void updatePlayerResource({
    required String resourceId,
    String? name,
    BattleResourcePortraitBinding? portrait,
    bool updatePortrait = false,
  }) {
    _store.updatePlayerResource(
      resourceId: resourceId,
      name: name,
      portrait: portrait,
      updatePortrait: updatePortrait,
    );
  }

  void updatePlayerResourcePortrait(String resourceId, String? asset) {
    final trimmedAsset = asset?.trim() ?? '';
    updatePlayerResource(
      resourceId: resourceId,
      portrait: trimmedAsset.isEmpty
          ? null
          : BattleResourcePortraitBinding(asset: trimmedAsset),
      updatePortrait: true,
    );
  }

  bool isBattleResourceAssetMissing(String? assetPath) =>
      _store.isAssetPathMissing(assetPath);

  Future<bool> relinkPlayerResourcePortrait(String resourceId) async {
    final file = await openFile(
      confirmButtonText: '重新选择图片',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '图片',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
        ),
      ],
    );
    final path = file?.path;
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    updatePlayerResourcePortrait(resourceId, path);
    return true;
  }

  bool deletePlayerResource(String resourceId) =>
      _store.deletePlayerResource(resourceId);

  void appendDefaultRosterEntry({
    required String resourceId,
    required BattleEntityKind kind,
  }) {
    _store.appendDefaultRosterEntry(
      BattleRosterEntryModel(resourceId: resourceId, kind: kind),
    );
  }

  void removeDefaultRosterEntryAt(int index) =>
      _store.removeDefaultRosterEntryAt(index);

  void moveDefaultRosterEntry(int from, int delta) =>
      _store.moveDefaultRosterEntry(from, delta);

  bool materializeCurrentBattleFromDefaultRoster() =>
      _store.materializeCurrentBattleFromDefaultRoster();

  void clearCurrentBattleWorkspace() => _store.clearCurrentBattleWorkspace();

  void updateBattleEntity({
    required String entityId,
    String? displayName,
    Object? currentHp,
    BattleEntityState? state,
    List<String>? markers,
    String? note,
    bool? isForeground,
    bool? isCurrentActor,
  }) {
    _store.updateBattleEntity(
      entityId: entityId,
      displayName: displayName,
      currentHp: currentHp,
      state: state,
      markers: markers,
      note: note,
      isForeground: isForeground,
      isCurrentActor: isCurrentActor,
    );
  }

  void toggleBattleEntityActive(String entityId) {
    final entity = _store.battle.workspace.entities
        .where((e) => e.id == entityId)
        .firstOrNull;
    if (entity == null) return;
    final nextState = entity.state == BattleEntityState.active
        ? BattleEntityState.standby
        : BattleEntityState.active;
    _store.updateBattleEntity(entityId: entityId, state: nextState);
  }

  void removeBattleEntity(String entityId) =>
      _store.removeBattleEntity(entityId);

  bool reorderBattleTurnOrder(int oldIndex, int newIndex) =>
      _store.reorderBattleTurnOrder(oldIndex, newIndex);

  void addEntityToBattle(String resourceId, BattleEntityKind kind) =>
      _store.addEntityToBattle(resourceId, kind);

  String rollDice(String expression) => _store.rollDice(expression);
  String rollPresetDice(int sides) => _store.rollPresetDice(sides);
  String rollFateDice({

    int bonus = 0,
    FateDiceModifierMode modifierMode = FateDiceModifierMode.none,
  }) {
    return _store.rollFateDice(bonus: bonus, modifierMode: modifierMode);
  }

  BattleRosterResolvedEntryViewModel _resolveDefaultRosterEntry({
    required BattleRosterEntryModel entry,
    required int index,
    required int lastIndex,
  }) {
    switch (entry.kind) {
      case BattleEntityKind.npc:
        final template = resolveNpcTemplate(entry.resourceId);
        if (template == null) {
          return BattleRosterResolvedEntryViewModel(
            index: index,
            resourceId: entry.resourceId,
            kind: entry.kind,
            displayName: '资源缺失',
            subtitle: 'ID: ${entry.resourceId}',
            missing: true,
            canMoveUp: index > 0,
            canMoveDown: index < lastIndex,
          );
        }
        return BattleRosterResolvedEntryViewModel(
          index: index,
          resourceId: entry.resourceId,
          kind: entry.kind,
          displayName: template.name,
          subtitle: 'ID: ${template.id}',
          missing: false,
          canMoveUp: index > 0,
          canMoveDown: index < lastIndex,
        );
      case BattleEntityKind.player:
        final resource = resolvePlayerResource(entry.resourceId);
        if (resource == null) {
          return BattleRosterResolvedEntryViewModel(
            index: index,
            resourceId: entry.resourceId,
            kind: entry.kind,
            displayName: '资源缺失',
            subtitle: 'ID: ${entry.resourceId}',
            missing: true,
            canMoveUp: index > 0,
            canMoveDown: index < lastIndex,
          );
        }
        return BattleRosterResolvedEntryViewModel(
          index: index,
          resourceId: entry.resourceId,
          kind: entry.kind,
          displayName: resource.name,
          subtitle: 'ID: ${resource.id}',
          missing: false,
          canMoveUp: index > 0,
          canMoveDown: index < lastIndex,
        );
    }
  }
}

class BattleRosterResolvedEntryViewModel {
  const BattleRosterResolvedEntryViewModel({
    required this.index,
    required this.resourceId,
    required this.kind,
    required this.displayName,
    required this.subtitle,
    required this.missing,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  final int index;
  final String resourceId;
  final BattleEntityKind kind;
  final String displayName;
  final String subtitle;
  final bool missing;
  final bool canMoveUp;
  final bool canMoveDown;

  String get kindLabel {
    switch (kind) {
      case BattleEntityKind.npc:
        return 'NPC';
      case BattleEntityKind.player:
        return '玩家';
    }
  }
}

class BattleRosterLibraryCandidateViewModel {
  const BattleRosterLibraryCandidateViewModel({
    required this.resourceId,
    required this.kind,
    required this.name,
    required this.subtitle,
  });

  final String resourceId;
  final BattleEntityKind kind;
  final String name;
  final String subtitle;

  String get kindLabel {
    switch (kind) {
      case BattleEntityKind.npc:
        return 'NPC';
      case BattleEntityKind.player:
        return '玩家';
    }
  }
}

class BattleSceneImageCandidate {
  const BattleSceneImageCandidate({
    required this.nodeId,
    required this.name,
    required this.asset,
  });

  final String nodeId;
  final String name;
  final String asset;
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

  // Cached viewport scale factors, updated by StageCanvas on each layout.
  double _viewportScaleX = 1;
  double _viewportScaleY = 1;
  void updateViewportScales(double scaleX, double scaleY) {
    _viewportScaleX = scaleX;
    _viewportScaleY = scaleY;
  }

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
  bool alignSelectionToCanvasTop() =>
      _store.alignSelectionToCanvasTop(
        viewportScaleX: _viewportScaleX,
        viewportScaleY: _viewportScaleY,
      );
  bool alignSelectionToCanvasBottom() =>
      _store.alignSelectionToCanvasBottom(
        viewportScaleX: _viewportScaleX,
        viewportScaleY: _viewportScaleY,
      );
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
  double _notesFontSize = 15;
  final _NotesFontSizeNotifier _notesFontSizeNotifier = _NotesFontSizeNotifier();
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
  Future<bool> relinkNodeAsset(String nodeId) => _store.relinkNodeAsset(nodeId);
  bool renameSelection(String newName) => _store.renameSelection(newName);
  bool get layerTreePanelCollapsed => _store.layerTreePanelCollapsed;
  bool get notesPanelCollapsed => _store.notesPanelCollapsed;
  String get notesText => _store.notesText;
  NotesEditorViewState get notesEditorViewState => _notesEditorViewState;
  String? get rangeSelectionAnchorId => _rangeSelectionAnchorId;
  bool get globalLoading => _store.globalLoading;
  Listenable get globalLoadingListenable => _store.globalLoadingListenable;
  double get notesFontSize => _notesFontSize;
  Listenable get notesFontSizeListenable => _notesFontSizeNotifier;

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

  void adjustNotesFontSize(double delta) {
    final next = (_notesFontSize + delta).clamp(8.0, 48.0);
    if ((next - _notesFontSize).abs() < 0.01) {
      return;
    }
    _notesFontSize = next;
    _notesFontSizeNotifier.fire();
  }

  void disposeNotesFontSizeNotifier() {
    _notesFontSizeNotifier.dispose();
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

  Future<void> addImageLayer() => _store.addImageLayer();
  Future<void> importDroppedFiles(List<String> paths) =>
      _store.importDroppedFiles(paths);
  Future<void> importDroppedImageFiles(List<String> paths) =>
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
  Future<bool> relinkTrackAsset(String trackId) =>
      _store.relinkTrackAsset(trackId);
  Future<void> importTrack() => _store.importMp3Track();
  bool moveTrackUp(String trackId) => _store.moveTrackUp(trackId);
  bool moveTrackDown(String trackId) => _store.moveTrackDown(trackId);
  bool reorderTrack(int fromIndex, int toIndex) =>
      _store.reorderTrack(fromIndex, toIndex);
  Future<bool> deleteTrack(String trackId) => _store.deleteTrack(trackId);
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
