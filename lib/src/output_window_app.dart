import 'dart:async' as async_lib;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'model/battle_model.dart';
import 'model/project_model.dart';
import 'output/battle_output_view.dart';
import 'output/output_layout.dart';
import 'output/output_render_tile.dart';
import 'output/output_sync_parser.dart';
import 'output/output_sync_state.dart';
import 'render/render_color.dart';
import 'ui/widgets/stage/stage_hit_test.dart';

class OutputWindowApp extends StatefulWidget {
  final int windowId;
  final GlobalKey<NavigatorState> navigatorKey;

  const OutputWindowApp({
    super.key,
    required this.windowId,
    required this.navigatorKey,
  });

  @override
  State<OutputWindowApp> createState() => _OutputWindowAppState();
}

class _OutputWindowAppState extends State<OutputWindowApp> {
  OutputSyncState _syncState = const OutputSyncState.initial();
  final ScrollController _flowScrollController = ScrollController();
  String _lastFlowMessageSignature = '';

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      return _handleMethodCall(call, fromWindowId);
    });
  }

  async_lib.Future<dynamic> _handleMethodCall(
    MethodCall call,
    int fromWindowId,
  ) async {
    if (call.method != 'sync_render') {
      return null;
    }
    try {
      _syncState = parseSyncRenderPayload(
        current: _syncState,
        arguments: call.arguments,
        now: DateTime.now(),
      );
    } catch (e) {
      _syncState = _syncState.withError('sync_render 处理失败: $e');
    }

    if (mounted) {
      setState(() {});
    }
    return null;
  }

  @override
  void dispose() {
    DesktopMultiWindow.setMethodHandler(null);
    _flowScrollController.dispose();
    super.dispose();
  }

  void _scheduleFlowScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_flowScrollController.hasClients) {
        return;
      }
      _flowScrollController.jumpTo(
        _flowScrollController.position.maxScrollExtent,
      );
    });
  }

  Widget _buildFlowMessageOverlay() {
    final items = _syncState.flowMessages;
    return Positioned(
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        child: SizedBox(
          width: 280,
          height: 130,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0x88000000)),
              child: ListView.builder(
                controller: _flowScrollController,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item.text,
                      softWrap: true,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: Color(item.colorValue),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Color(0xAA000000),
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  async_lib.Future<void> _selectNode(String id) async {
    if (id.isEmpty) {
      return;
    }
    try {
      await DesktopMultiWindow.invokeMethod(0, 'select_node', {'id': id});
    } catch (_) {
      // 主窗口暂不可达时保持静默，避免打断输出窗口显示。
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      navigatorKey: widget.navigatorKey,
      title: '玩家输出 ${widget.windowId}',
      home: Scaffold(
        backgroundColor: const Color(0xFF182028),
        body: ColoredBox(
          color: const Color(0xFF182028),
          child: _buildOutputBody(),
        ),
      ),
    );
  }

  Widget _buildOutputBody() {
    final hasFlowMessages = _syncState.flowMessages.isNotEmpty;
    final flowSignature = _syncState.flowMessages.map((item) => item.id).join('|');
    if (flowSignature != _lastFlowMessageSignature) {
      _lastFlowMessageSignature = flowSignature;
      if (hasFlowMessages) {
        _scheduleFlowScrollToBottom();
      }
    }
    final isBattleMode = _syncState.currentMode == ProjectMode.battle;
    final showingBattle =
        isBattleMode && (_syncState.battle?.showingBattle ?? false);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: showingBattle
              ? BattleOutputView(
                  battle: _syncState.battle!,
                  canvasWidth: _syncState.canvasWidth,
                  canvasHeight: _syncState.canvasHeight,
                  outputScaleMode: _syncState.outputScaleMode,
                  backgroundItems: _syncState.renderList,
                )
              : _buildSceneOutput(hasFlowMessages: hasFlowMessages),
        ),
        if (hasFlowMessages) _buildFlowMessageOverlay(),
      ],
    );
  }

  Widget _buildSceneOutput({required bool hasFlowMessages}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = computeOutputLayout(
          constraints: constraints,
          canvasWidth: _syncState.canvasWidth,
          canvasHeight: _syncState.canvasHeight,
          outputScaleMode: _syncState.outputScaleMode,
        );
        final renderableItems = _syncState.renderList.where(isRenderableItem).toList();
        final uniformScale = layout.renderScaleX < layout.renderScaleY
            ? layout.renderScaleX
            : layout.renderScaleY;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) {
            final hitId = hitTestTopDown(
              renderList: renderableItems,
              localPosition:
                  details.localPosition - Offset(layout.offsetX, layout.offsetY),
              scaleX: layout.renderScaleX,
              scaleY: layout.renderScaleY,
              useFullBoundsHit: true,
            );
            if (hitId == null || hitId.isEmpty) {
              return;
            }
            _selectNode(hitId);
          },
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (_syncState.renderList.isEmpty && !hasFlowMessages)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 780),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _statusText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final item in renderableItems)
                Positioned(
                  left: layout.offsetX + item.worldPosition.dx * layout.renderScaleX,
                  top: layout.offsetY + item.worldPosition.dy * layout.renderScaleY,
                  child: Opacity(
                    opacity: (item.visible ? item.opacity : 0.0).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: item.worldRotation,
                      alignment: Alignment.center,
                      child: item.type == NodeType.text
                          ? Transform.scale(
                              scale: item.worldScale,
                              alignment: Alignment.center,
                              child: IntrinsicWidth(
                                child: IntrinsicHeight(
                                  child: OutputRenderTile(
                                    item: item,
                                    renderedHeight: null,
                                  ),
                                ),
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final backgroundColor = item.type == NodeType.image
                                    ? Colors.transparent
                                    : colorFromSeed(item.id);
                                return Container(
                                  width: item.baseWidth *
                                      item.worldScale *
                                      (item.preserveAspect
                                          ? uniformScale
                                          : layout.renderScaleX),
                                  height: item.baseHeight *
                                      item.worldScale *
                                      (item.preserveAspect
                                          ? uniformScale
                                          : layout.renderScaleY),
                                  decoration: BoxDecoration(color: backgroundColor),
                                  child: OutputRenderTile(
                                    item: item,
                                    renderedHeight: item.baseHeight *
                                        item.worldScale *
                                        (item.preserveAspect
                                            ? uniformScale
                                            : layout.renderScaleY),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _statusText() {
    if (_syncState.lastSyncError != null &&
        _syncState.lastSyncError!.isNotEmpty) {
      return '输出同步异常\n${_syncState.lastSyncError}';
    }
    final last = _syncState.lastSyncAt;
    if (last == null) {
      return '等待主窗口同步渲染数据...';
    }
    final hh = last.hour.toString().padLeft(2, '0');
    final mm = last.minute.toString().padLeft(2, '0');
    final ss = last.second.toString().padLeft(2, '0');
    return '已连接主窗口，但当前没有可渲染内容\n最近同步: $hh:$mm:$ss';
  }
}
