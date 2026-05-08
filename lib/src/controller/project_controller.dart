import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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

  bool get outputWindowOpen => _outputWindowId != null;

  @override
  void onInit() {
    super.onInit();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      return _handleMethodCall(call, fromWindowId);
    });
    store.addListener(_onStoreChanged);
  }

  Future<dynamic> _handleMethodCall(MethodCall call, int fromWindowId) async {
    if (call.method != 'select_node') {
      return null;
    }
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
    final ok = await store.saveProject();
    if (ok) {
      _scheduleOutputSync(force: true);
    }
    return ok;
  }

  Future<bool> saveProjectAs() async {
    final ok = await store.saveProjectAs();
    if (ok) {
      _scheduleOutputSync(force: true);
    }
    return ok;
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
    if (_outputWindowId == null) {
      return;
    }
    _scheduleOutputSync(force: false);
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

    try {
      await DesktopMultiWindow.invokeMethod(targetId, 'sync_render', payload);
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
    DesktopMultiWindow.setMethodHandler(null);
    store.removeListener(_onStoreChanged);
    store.dispose();
    super.onClose();
  }
}
