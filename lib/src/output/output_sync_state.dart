import '../model/battle_model.dart';
import '../model/render_item.dart';
import 'sync_render_payload.dart';

class OutputSyncState {
  const OutputSyncState({
    required this.renderList,
    required this.flowMessages,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.outputScaleMode,
    required this.currentMode,
    required this.battle,
    required this.lastSyncAt,
    required this.lastSyncError,
  });

  const OutputSyncState.initial()
      : renderList = const [],
        flowMessages = const [],
        canvasWidth = 1920,
        canvasHeight = 1080,
        outputScaleMode = 'stretch',
        currentMode = ProjectMode.scene,
        battle = null,
        lastSyncAt = null,
        lastSyncError = null;

  final List<RenderItem> renderList;
  final List<SyncFlowMessage> flowMessages;
  final double canvasWidth;
  final double canvasHeight;
  final String outputScaleMode;
  final ProjectMode currentMode;
  final SyncBattlePayload? battle;
  final DateTime? lastSyncAt;
  final String? lastSyncError;

  OutputSyncState withError(String error) {
    return OutputSyncState(
      renderList: renderList,
      flowMessages: flowMessages,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputScaleMode: outputScaleMode,
      currentMode: currentMode,
      battle: battle,
      lastSyncAt: lastSyncAt,
      lastSyncError: error,
    );
  }

  OutputSyncState withSync({
    required List<RenderItem> renderList,
    required List<SyncFlowMessage> flowMessages,
    required double canvasWidth,
    required double canvasHeight,
    required String outputScaleMode,
    required ProjectMode currentMode,
    required SyncBattlePayload? battle,
    required DateTime syncedAt,
  }) {
    return OutputSyncState(
      renderList: renderList,
      flowMessages: flowMessages,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputScaleMode: outputScaleMode,
      currentMode: currentMode,
      battle: battle,
      lastSyncAt: syncedAt,
      lastSyncError: null,
    );
  }
}
