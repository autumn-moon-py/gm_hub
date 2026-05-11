import 'dart:async' as async_lib;
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

import '../model/project_model.dart';
import '../model/render_item.dart';
import 'project_file_service.dart';

part 'project_store_project_ops.dart';
part 'project_store_node_ops.dart';
part 'project_store_runtime_ops.dart';
part 'project_store_runtime_delegate.dart';
part 'project_store_tree_ops.dart';
part 'project_store_geometry_ops.dart';

enum DropPlacement { before, after, into }

enum AlignAction {
  left,
  hCenter,
  right,
  top,
  vCenter,
  bottom,
  distributeH,
  distributeV,
}

enum FateDiceModifierMode {
  none,
  advantage,
  disadvantage,
}

class FlowMessageItem {
  final String id;
  final String text;
  final Color color;
  final double x;
  final double y;

  const FlowMessageItem({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
  });
}

class _StoreNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

class ProjectStore extends ChangeNotifier {
  ProjectStore({
    ProjectFileService? fileService,
    String? initialProjectFilePath,
  })  : _fileService = fileService ?? ProjectFileService(),
        _project = ProjectModel.initial() {
    final path = (initialProjectFilePath == null ||
            initialProjectFilePath.trim().isEmpty)
        ? p.join(
            Directory.current.path,
            ProjectFileService.defaultProjectFileName,
          )
        : p.normalize(initialProjectFilePath);
    _setProjectFilePath(path);
    _runtime = _ProjectRuntimeDelegate(this);
    _bindAudioPlayer();
    _bootstrap();
  }

  final ProjectFileService _fileService;
  late final _ProjectRuntimeDelegate _runtime;
  ProjectModel _project;
  String? _selection;
  final Set<String> _selectedIds = <String>{};
  late final Set<String> _selectedIdsView = UnmodifiableSetView(_selectedIds);
  final ChangeNotifier _selectionNotifier = ChangeNotifier();
  final ChangeNotifier _stageNotifier = ChangeNotifier();
  final ChangeNotifier _layerTreeNotifier = ChangeNotifier();
  final _StoreNotifier _notesNotifier = _StoreNotifier();
  final ChangeNotifier _audioNotifier = ChangeNotifier();
  final ChangeNotifier _diceNotifier = ChangeNotifier();
  final ChangeNotifier _transformNotifier = ChangeNotifier();
  final ChangeNotifier _globalLoadingNotifier = ChangeNotifier();
  final Map<String, ChangeNotifier> _nodeSelectionNotifiers =
      <String, ChangeNotifier>{};
  final Map<String, ChangeNotifier> _nodeDataNotifiers =
      <String, ChangeNotifier>{};
  final Set<String> _collapsedGroupIds = <String>{};
  bool _layerTreePanelCollapsed = false;
  bool _notesPanelCollapsed = true;
  String _notesText = '';
  String _latestProjectJson = '';
  bool _latestProjectJsonDirty = true;
  int _idSeed = 10;
  String? _projectFilePath;
  String? _projectDirPath;
  String _outputScaleMode = 'stretch';
  final Map<String, Size> _assetSizeCache = <String, Size>{};
  final Map<String, bool> _assetExistsCache = <String, bool>{};
  List<RenderItem>? _renderListCache;
  int _globalLoadingCount = 0;
  final List<_LayerHistorySnapshot> _layerUndoStack = <_LayerHistorySnapshot>[];
  bool _dragUndoTransactionActive = false;
  bool _dragUndoSnapshotCaptured = false;

  static const double _flowTopPadding = 8;
  static const double _flowLeftPadding = 10;
  static const double _flowRowHeight = 24;
  static const double _flowBottomPadding = 8;
  static const double _flowScrollSpeed = 220;
  static const int _audioFadeSteps = 8;
  static const Duration _audioFadeTotalDuration = Duration(seconds: 3);
  static const int _maxLayerUndoEntries = 100;
  static const Duration _globalLoadingMinVisibleDuration =
      Duration(milliseconds: 180);

  DateTime? _globalLoadingVisibleSince;

  ProjectModel get project => _project;
  String? get projectFilePath => _projectFilePath;
  String? get projectDirPath => _projectDirPath;
  String? get selection => _selection;
  String get latestProjectJson {
    if (_latestProjectJsonDirty) {
      _latestProjectJson = _projectWithRuntimeUiState().toPrettyJson();
      _latestProjectJsonDirty = false;
    }
    return _latestProjectJson;
  }

  String? get audioError => _runtime.audioError;
  String get outputScaleMode => _outputScaleMode;
  bool get layerTreePanelCollapsed => _layerTreePanelCollapsed;
  bool get notesPanelCollapsed => _notesPanelCollapsed;
  String get notesText => _notesText;
  bool get dicePanelCollapsed => _runtime.dicePanelCollapsed;
  bool get darkDiceEnabled => _runtime.darkDiceEnabled;
  bool get globalLoading => _globalLoadingCount > 0;
  List<FlowMessageItem> get flowMessages => _runtime.flowMessages;
  Set<String> get selectedIds => _selectedIdsView;
  Listenable get globalLoadingListenable => _globalLoadingNotifier;
  Listenable get selectionListenable => _selectionNotifier;
  Listenable get stageListenable => _stageNotifier;
  Listenable get layerTreeListenable => _layerTreeNotifier;
  Listenable get notesListenable => _notesNotifier;
  Listenable get audioListenable => _audioNotifier;
  Listenable get diceListenable => _diceNotifier;
  Listenable get transformListenable => _transformNotifier;
  Listenable selectionListenableForNode(String nodeId) {
    return _nodeSelectionNotifiers.putIfAbsent(nodeId, ChangeNotifier.new);
  }

  Listenable nodeDataListenableForNode(String nodeId) {
    return _nodeDataNotifiers.putIfAbsent(nodeId, ChangeNotifier.new);
  }

  NodeModel? getNodeById(String nodeId) => _findNodeById(_project.root, nodeId);

  String? get selectionName {
    final id = _selection;
    if (id == null) {
      return null;
    }
    return _findNodeById(_project.root, id)?.name;
  }

  NodeModel? get selectedNode {
    final id = _selection;
    if (id == null) {
      return null;
    }
    return _findNodeById(_project.root, id);
  }

  ProjectModel _projectWithRuntimeUiState() {
    return _project.copyWith(
      uiState: UiStateModel(
        collapsedGroupIds: _collapsedGroupIds.toList(),
        outputScaleMode: _outputScaleMode,
        layerTreePanelCollapsed: _layerTreePanelCollapsed,
        notesPanelCollapsed: _notesPanelCollapsed,
        notesText: _notesText,
      ),
    );
  }

  void _markLatestProjectJsonDirty() {
    _latestProjectJsonDirty = true;
  }

  void _pushLayerHistorySnapshot() {
    _layerUndoStack.add(
      _LayerHistorySnapshot(
        project: _project.copyWith(),
        selection: _selection,
        selectedIds: Set<String>.from(_selectedIds),
      ),
    );
    if (_layerUndoStack.length > _maxLayerUndoEntries) {
      _layerUndoStack.removeAt(0);
    }
  }

  void _clearLayerHistory() {
    _layerUndoStack.clear();
  }

  bool undoLayerChange() {
    if (_layerUndoStack.isEmpty) {
      return false;
    }
    final previousSelectedIds = Set<String>.from(_selectedIds);
    final previousPrimarySelection = _selection;
    final snapshot = _layerUndoStack.removeLast();
    _project = snapshot.project;
    _selection = snapshot.selection;
    _selectedIds
      ..clear()
      ..addAll(snapshot.selectedIds);
    _invalidateDerivedCaches(renderList: true, assetExists: true);
    _assetSizeCache.clear();
    _refreshIdSeedFromProject();
    _markLatestProjectJsonDirty();
    _notifySelectionListeners(
      previousSelectedIds: previousSelectedIds,
      previousPrimarySelection: previousPrimarySelection,
    );
    _notifyStoreListeners(
      notifyController: true,
      notifyStage: true,
      notifyLayerTree: true,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: true,
    );
    return true;
  }

  void beginLayerDragUndoTransaction() {
    _dragUndoTransactionActive = true;
    _dragUndoSnapshotCaptured = false;
  }

  void endLayerDragUndoTransaction() {
    _dragUndoTransactionActive = false;
    _dragUndoSnapshotCaptured = false;
  }

  void _notifyStoreListeners({
    bool notifyController = true,
    bool notifyStage = true,
    bool notifyLayerTree = true,
    bool notifyAudio = true,
    bool notifyDice = true,
    bool notifyTransform = true,
  }) {
    if (notifyStage) {
      _stageNotifier.notifyListeners();
    }
    if (notifyLayerTree) {
      _layerTreeNotifier.notifyListeners();
    }
    if (notifyAudio) {
      _audioNotifier.notifyListeners();
    }
    if (notifyDice) {
      _diceNotifier.notifyListeners();
    }
    if (notifyTransform) {
      _transformNotifier.notifyListeners();
    }
    if (notifyController) {
      notifyListeners();
    }
  }

  void _notifySelectionListeners({
    Set<String>? previousSelectedIds,
    String? previousPrimarySelection,
  }) {
    final affectedIds = <String>{};
    if (previousSelectedIds != null) {
      affectedIds.addAll(previousSelectedIds);
    }
    affectedIds.addAll(_selectedIds);
    if (previousPrimarySelection != null &&
        previousPrimarySelection.isNotEmpty) {
      affectedIds.add(previousPrimarySelection);
    }
    final currentSelection = _selection;
    if (currentSelection != null && currentSelection.isNotEmpty) {
      affectedIds.add(currentSelection);
    }
    _selectionNotifier.notifyListeners();
    for (final id in affectedIds) {
      _nodeSelectionNotifiers[id]?.notifyListeners();
    }
  }

  void _notifyNodeDataListeners(Iterable<String> nodeIds) {
    final seen = <String>{};
    for (final id in nodeIds) {
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      _nodeDataNotifiers[id]?.notifyListeners();
    }
  }

  void _invalidateDerivedCaches({
    bool renderList = true,
    bool assetExists = false,
  }) {
    if (renderList) {
      _renderListCache = null;
    }
    if (assetExists) {
      _assetExistsCache.clear();
    }
  }

  void _pushGlobalLoading() {
    _globalLoadingCount += 1;
    if (_globalLoadingCount == 1) {
      _globalLoadingVisibleSince = DateTime.now();
      _globalLoadingNotifier.notifyListeners();
    }
  }

  Future<void> _popGlobalLoading() async {
    if (_globalLoadingCount <= 0) {
      _globalLoadingCount = 0;
      return;
    }
    if (_globalLoadingCount == 1) {
      final visibleSince = _globalLoadingVisibleSince;
      if (visibleSince != null) {
        final elapsed = DateTime.now().difference(visibleSince);
        final remaining = _globalLoadingMinVisibleDuration - elapsed;
        if (remaining > Duration.zero) {
          await async_lib.Future<void>.delayed(remaining);
        }
      }
      _globalLoadingCount = 0;
      _globalLoadingVisibleSince = null;
      _globalLoadingNotifier.notifyListeners();
      return;
    }
    _globalLoadingCount -= 1;
  }

  Future<T> runWithGlobalLoading<T>(Future<T> Function() action) async {
    _pushGlobalLoading();
    try {
      await SchedulerBinding.instance.endOfFrame;
      return await action();
    } finally {
      await _popGlobalLoading();
    }
  }

  @override
  void dispose() {
    for (final notifier in _nodeSelectionNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _nodeDataNotifiers.values) {
      notifier.dispose();
    }
    _selectionNotifier.dispose();
    _stageNotifier.dispose();
    _layerTreeNotifier.dispose();
    _notesNotifier.dispose();
    _audioNotifier.dispose();
    _diceNotifier.dispose();
    _transformNotifier.dispose();
    _globalLoadingNotifier.dispose();
    _runtime.dispose();
    super.dispose();
  }

  static const double _textDragHandleHeight = 14;

  Size _resolveAssetSize(String? assetAbsolutePath) {
    const fallback = Size(220, 140);
    final path = assetAbsolutePath;
    if (path == null || path.isEmpty) {
      return fallback;
    }
    final cached = _assetSizeCache[path];
    if (cached != null) {
      return cached;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _assetSizeCache[path] = fallback;
      return fallback;
    }
    try {
      final decoded = img.decodeImage(file.readAsBytesSync());
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        _assetSizeCache[path] = fallback;
        return fallback;
      }
      final size = Size(decoded.width.toDouble(), decoded.height.toDouble());
      _assetSizeCache[path] = size;
      return size;
    } catch (_) {
      _assetSizeCache[path] = fallback;
      return fallback;
    }
  }

  Future<Size> _resolveAssetSizeAsync(String? assetAbsolutePath) async {
    const fallback = Size(220, 140);
    final path = assetAbsolutePath;
    if (path == null || path.isEmpty) {
      return fallback;
    }
    final cached = _assetSizeCache[path];
    if (cached != null) {
      return cached;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _assetSizeCache[path] = fallback;
      return fallback;
    }
    try {
      final bytes = await file.readAsBytes();
      final dimensions = await compute(_decodeImageDimensions, bytes);
      if (dimensions == null || dimensions.length != 2) {
        _assetSizeCache[path] = fallback;
        return fallback;
      }
      final size = Size(dimensions[0].toDouble(), dimensions[1].toDouble());
      _assetSizeCache[path] = size;
      return size;
    } catch (_) {
      _assetSizeCache[path] = fallback;
      return fallback;
    }
  }

  Size _resolveNodeBaseSize(NodeModel node, String? assetAbsolutePath) {
    final width = node.width;
    final height = node.height;
    if (width != null &&
        height != null &&
        width.isFinite &&
        height.isFinite &&
        width > 0 &&
        height > 0) {
      return Size(width, height);
    }
    if (node.type == NodeType.text) {
      return _resolveTextNodeSize(node);
    }
    return _resolveAssetSize(assetAbsolutePath);
  }

  Size _resolveTextNodeSize(NodeModel node) {
    final value = (node.text ?? '').trim().isEmpty ? '文字' : node.text!.trim();
    final fontSize = (node.fontSize ?? 34).clamp(8.0, 256.0);
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Color(node.textColorValue ?? 0xFFFFFFFF),
        ),
      ),
      maxLines: 8,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 1200);
    return Size(
      (painter.width + 20).clamp(60, 1300),
      (painter.height + _textDragHandleHeight + 10).clamp(30, 900),
    );
  }
}

List<int>? _decodeImageDimensions(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }
  return [decoded.width, decoded.height];
}

class _NodeLocation {
  final String parentId;
  final int index;
  final NodeModel node;

  const _NodeLocation({
    required this.parentId,
    required this.index,
    required this.node,
  });
}

class _NodeWorldTransform {
  final Offset position;
  final double scale;
  final double rotation;

  const _NodeWorldTransform({
    required this.position,
    required this.scale,
    required this.rotation,
  });

  const _NodeWorldTransform.identity()
      : position = Offset.zero,
        scale = 1,
        rotation = 0;
}

class _NodeWorldInfo {
  final String id;
  final Rect bounds;
  final double parentWorldScale;
  final double parentWorldRotation;
  final bool lockedByAncestor;

  const _NodeWorldInfo({
    required this.id,
    required this.bounds,
    required this.parentWorldScale,
    required this.parentWorldRotation,
    required this.lockedByAncestor,
  });
}

class _LayerHistorySnapshot {
  final ProjectModel project;
  final String? selection;
  final Set<String> selectedIds;

  const _LayerHistorySnapshot({
    required this.project,
    required this.selection,
    required this.selectedIds,
  });
}

class _FlowMessageState {
  final String id;
  final String text;
  final Color color;
  double x;
  double y;

  _FlowMessageState({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
  });
}

class _DiceRollResult {
  final String normalized;
  final int total;
  final String detail;

  const _DiceRollResult({
    required this.normalized,
    required this.total,
    required this.detail,
  });
}
