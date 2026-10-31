import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../model/battle_model.dart';
import '../output/sync_render_payload.dart';
import '../store/project_store.dart';

class ProjectController extends GetxController {
  ProjectController({String? initialProjectFilePath})
    : store = ProjectStore(initialProjectFilePath: initialProjectFilePath);

  final ProjectStore store;

  int? _outputWindowId;
  String _lastSentSignature = '';
  bool _syncQueued = false;
  bool _syncInFlight = false;
  bool _pendingSyncRequested = false;
  bool _pendingSyncForce = false;
  Timer? _syncRetryTimer;
  int? _diceWindowId;
  int? _musicWindowId;
  String _lastMusicSignature = '';

  bool get outputWindowOpen => _outputWindowId != null;
  bool get diceWindowOpen => _diceWindowId != null;
  bool get musicWindowOpen => _musicWindowId != null;

  void switchToSceneMode() {
    store.setProjectMode(ProjectMode.scene);
    update();
    _scheduleOutputSync(force: true);
  }

  void switchToBattleMode() {
    store.setProjectMode(ProjectMode.battle);
    update();
    _scheduleOutputSync(force: true);
  }

  @override
  void onInit() {
    super.onInit();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      return _handleMethodCall(call, fromWindowId);
    });
    store.addListener(_onStoreChanged);
    store.audioListenable.addListener(_onAudioChanged);
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    switch (call.method) {
      case 'select_node':
        return _handleSelectNode(call, fromWindowId);
      case 'dice_get_state':
        return _handleDiceGetState();
      case 'dice_roll_preset':
        return _handleDiceRollPreset(call.arguments);
      case 'dice_roll_fate':
        return _handleDiceRollFate(call.arguments);
      case 'dice_roll_custom':
        return _handleDiceRollCustom(call.arguments);
      case 'dice_set_dark':
        return _handleDiceSetDark(call.arguments);
      case 'dice_clear_flow':
        store.clearFlowMessages();
        return null;
      case 'music_get_state':
        return _buildAudioSyncPayload();
      case 'music_play_pause':
        store.playPause();
        return null;
      case 'music_stop':
        store.stop();
        return null;
      case 'music_toggle_loop':
        store.toggleLoop();
        return null;
      case 'music_set_volume':
        store.setVolume(_extractDouble(call.arguments, 'value', 0.3));
        return null;
      case 'music_set_track':
        final trackId = _extractString(call.arguments, 'trackId', '');
        store.setTrack(trackId.isEmpty ? null : trackId);
        return null;
      default:
        return null;
    }
  }

  Map<String, dynamic> _buildAudioSyncPayload() {
    final project = store.project;
    return {
      'tracks': [
        for (final track in project.tracks)
          {'id': track.id, 'name': track.name, 'tags': track.tags},
      ],
      'currentTrackId': project.audioState.currentTrackId,
      'isPlaying': project.audioState.isPlaying,
      'loop': project.audioState.loop,
      'volume': project.audioState.volume,
    };
  }

  void _onAudioChanged() {
    if (_musicWindowId == null) {
      return;
    }
    unawaited(_syncMusicWindow());
  }

  Future<void> _syncMusicWindow({bool force = false}) async {
    final targetId = _musicWindowId;
    if (targetId == null) {
      return;
    }
    final payload = _buildAudioSyncPayload();
    final signature = jsonEncode(payload);
    if (!force && signature == _lastMusicSignature) {
      return;
    }
    try {
      await DesktopMultiWindow.invokeMethod(targetId, 'audio_sync', payload);
      if (_musicWindowId != targetId) {
        return;
      }
      _lastMusicSignature = signature;
    } catch (_) {
      // 子窗口可能尚未就绪或已关闭，静默忽略；窗口初始化时会主动拉取状态
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (!ids.contains(targetId) && _musicWindowId == targetId) {
        _musicWindowId = null;
        _lastMusicSignature = '';
        update();
      }
    }
  }

  Future<dynamic> _handleSelectNode(MethodCall call, int fromWindowId) async {
    if (_outputWindowId != null && fromWindowId != _outputWindowId) {
      return null;
    }

    final id = _parseSelectedNodeId(call.arguments);
    if (id == null || id.isEmpty) {
      return null;
    }

    store.selectNode(id);
    return null;
  }

  Map<String, dynamic> _handleDiceGetState() {
    return {'darkDice': store.darkDiceEnabled};
  }

  Map<String, dynamic> _handleDiceRollPreset(dynamic arguments) {
    final sides = _extractInt(arguments, 'sides', 20);
    final result = store.rollPresetDice(sides);
    update();
    return {'result': result};
  }

  Map<String, dynamic> _handleDiceRollFate(dynamic arguments) {
    final bonus = _extractInt(arguments, 'bonus', 0);
    final modeStr = _extractString(arguments, 'modifierMode', 'none');
    final mode = _parseFateModifierMode(modeStr);
    final result = store.rollFateDice(bonus: bonus, modifierMode: mode);
    update();
    return {'result': result};
  }

  Map<String, dynamic> _handleDiceRollCustom(dynamic arguments) {
    final expression = _extractString(arguments, 'expression', '');
    final result = store.rollDice(expression);
    update();
    return {'result': result};
  }

  Map<String, dynamic> _handleDiceSetDark(dynamic arguments) {
    final enabled = _extractBool(arguments, 'enabled', false);
    store.setDarkDiceEnabled(enabled);
    update();
    return {'darkDice': store.darkDiceEnabled};
  }

  int _extractInt(dynamic arguments, String key, int defaultValue) {
    if (arguments is Map) {
      final v = arguments[key];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? defaultValue;
    }
    return defaultValue;
  }

  String _extractString(dynamic arguments, String key, String defaultValue) {
    if (arguments is Map) {
      final v = arguments[key];
      if (v is String) return v;
    }
    return defaultValue;
  }

  bool _extractBool(dynamic arguments, String key, bool defaultValue) {
    if (arguments is Map) {
      final v = arguments[key];
      if (v is bool) return v;
    }
    return defaultValue;
  }

  double _extractDouble(dynamic arguments, String key, double defaultValue) {
    if (arguments is Map) {
      final v = arguments[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? defaultValue;
    }
    return defaultValue;
  }

  FateDiceModifierMode _parseFateModifierMode(String mode) {
    switch (mode) {
      case 'advantage':
        return FateDiceModifierMode.advantage;
      case 'disadvantage':
        return FateDiceModifierMode.disadvantage;
      default:
        return FateDiceModifierMode.none;
    }
  }

  String? _parseSelectedNodeId(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    }
    if (arguments is Map) {
      final id = arguments['id'];
      if (id is String) {
        return id;
      }
    }
    return null;
  }

  Future<void> openOutputWindow() async {
    final currentId = _outputWindowId;
    if (currentId != null) {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (ids.contains(currentId)) {
        await _syncOutputWindow(force: true);
        return;
      }
      _clearOutputWindowState(notify: false);
    }

    final controller = await DesktopMultiWindow.createWindow('output');
    await controller.setFrame(const Rect.fromLTWH(60, 60, 1280, 760));
    await controller.center();
    await controller.setTitle('主持中枢 - 玩家输出');
    await controller.show();

    _outputWindowId = controller.windowId;
    update();
    await _syncOutputWindow(force: true);
  }

  Future<void> openDiceWindow() async {
    final currentId = _diceWindowId;
    if (currentId != null) {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (ids.contains(currentId)) {
        return;
      }
      _diceWindowId = null;
    }

    final controller = await DesktopMultiWindow.createWindow('dice');
    await controller.setFrame(const Rect.fromLTWH(100, 100, 300, 480));
    await controller.setTitle('骰子区');
    await controller.show();

    _diceWindowId = controller.windowId;
    update();
  }

  Future<void> openMusicWindow() async {
    final currentId = _musicWindowId;
    if (currentId != null) {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (ids.contains(currentId)) {
        await _syncMusicWindow(force: true);
        return;
      }
      _musicWindowId = null;
      _lastMusicSignature = '';
    }

    final controller = await DesktopMultiWindow.createWindow('music');
    await controller.setFrame(const Rect.fromLTWH(160, 120, 300, 520));
    await controller.setTitle('音乐悬浮窗');
    await controller.show();

    _musicWindowId = controller.windowId;
    _lastMusicSignature = '';
    update();
    await _syncMusicWindow(force: true);
  }

  Future<void> openProjectDir() async {
    await store.chooseAndOpenProjectDirectory();
    _scheduleOutputSync(force: true);
  }

  Future<void> createProject(String name) async {
    await store.chooseDirectoryAndCreateNewProject(name: name);
    _scheduleOutputSync(force: true);
  }

  Future<void> importImage() async {
    await store.importImageAsLayer();
    _scheduleOutputSync(force: true);
  }

  Future<void> importMp3() async {
    await store.importMp3Track();
    _scheduleOutputSync(force: true);
  }

  Future<bool> saveProject() async {
    final filePath = store.projectFilePath;
    if (filePath == null || filePath.isEmpty) {
      // 新项目还没有落盘路径，保存时先让用户选择位置
      return saveProjectAs();
    }
    final saveSw = Stopwatch()..start();
    final ok = await store.saveProject();
    if (ok) {
      _scheduleOutputSync(force: true);
    }
    debugPrint(
      '[保存耗时] controller.saveProject 总计: ${saveSw.elapsedMilliseconds}ms '
      '(含输出窗口同步调度)',
    );
    return ok;
  }

  Future<bool> saveProjectAs() async {
    final ok = await store.saveProjectAs();
    if (ok) {
      _scheduleOutputSync(force: true);
    }
    return ok;
  }

  Future<ConvertFormatOutcome> convertToNewFormat({
    required Future<bool> Function(List<String> missing) confirmMissing,
  }) async {
    final outcome = await store.convertToNewFormat(
      confirmMissing: confirmMissing,
    );
    _scheduleOutputSync(force: true);
    return outcome;
  }

  Future<void> clearProject() async {
    await store.clearProject();
    _scheduleOutputSync(force: true);
  }

  void deleteSelected() {
    store.deleteSelected();
    _scheduleOutputSync(force: true);
  }

  void undoLayerChange() {
    if (!store.undoLayerChange()) {
      return;
    }
    _scheduleOutputSync(force: true);
  }

  void _onStoreChanged() {
    update();
    if (_outputWindowId != null) {
      _scheduleOutputSync(force: false);
    }
  }

  void _scheduleOutputSync({required bool force}) {
    _pendingSyncRequested = true;
    _pendingSyncForce = _pendingSyncForce || force;
    if (_syncQueued || _syncInFlight) {
      return;
    }
    _syncQueued = true;
    scheduleMicrotask(() {
      _syncQueued = false;
      unawaited(_flushPendingOutputSync());
    });
  }

  Future<void> _flushPendingOutputSync() async {
    if (_syncInFlight) {
      return;
    }
    _syncInFlight = true;
    try {
      while (_pendingSyncRequested) {
        final force = _pendingSyncForce;
        _pendingSyncRequested = false;
        _pendingSyncForce = false;
        await _syncOutputWindow(force: force);
      }
    } finally {
      _syncInFlight = false;
      if (_pendingSyncRequested) {
        _scheduleOutputSync(force: false);
      }
    }
  }

  void _clearOutputWindowState({bool notify = true}) {
    _cancelOutputRetry();
    _outputWindowId = null;
    _lastSentSignature = '';
    if (notify) {
      update();
    }
  }

  void _cancelOutputRetry() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  void _scheduleOutputRetry(int targetId) {
    if (_outputWindowId != targetId) {
      return;
    }
    if (_syncRetryTimer?.isActive ?? false) {
      return;
    }
    _syncRetryTimer = Timer(const Duration(milliseconds: 400), () {
      _syncRetryTimer = null;
      if (_outputWindowId != targetId) {
        return;
      }
      _scheduleOutputSync(force: true);
    });
  }

  Future<void> _reconcileOutputWindowState(
    int targetId, {
    bool retryIfAlive = false,
  }) async {
    final ids = await DesktopMultiWindow.getAllSubWindowIds();
    if (!ids.contains(targetId)) {
      if (_outputWindowId == targetId) {
        _clearOutputWindowState();
      }
      return;
    }
    if (retryIfAlive && _outputWindowId == targetId) {
      _scheduleOutputRetry(targetId);
    }
  }

  Future<void> _syncOutputWindow({required bool force}) async {
    final targetId = _outputWindowId;
    if (targetId == null) {
      return;
    }
    final payload = _buildSyncPayload();
    final signature = jsonEncode(payload);
    if (!force && signature == _lastSentSignature) {
      return;
    }

    final syncSw = Stopwatch()..start();
    try {
      await DesktopMultiWindow.invokeMethod(targetId, 'sync_render', payload);
      debugPrint(
        '[保存耗时] 输出窗口同步: ${syncSw.elapsedMilliseconds}ms '
        '(payload ${signature.length ~/ 1024}KB)',
      );
      if (_outputWindowId != targetId) {
        return;
      }
      _lastSentSignature = signature;
      _cancelOutputRetry();
    } catch (_) {
      await _reconcileOutputWindowState(targetId, retryIfAlive: true);
    }
  }

  Map<String, dynamic> _buildSyncPayload() {
    return SyncRenderPayload.fromStore(store).toMap();
  }

  @override
  void onClose() {
    _cancelOutputRetry();
    _diceWindowId = null;
    _musicWindowId = null;
    DesktopMultiWindow.setMethodHandler(null);
    store.audioListenable.removeListener(_onAudioChanged);
    store.removeListener(_onStoreChanged);
    store.dispose();
    super.onClose();
  }
}
