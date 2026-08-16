import 'sync_render_payload.dart';
import 'output_sync_state.dart';

OutputSyncState parseSyncRenderPayload({
  required OutputSyncState current,
  required Object? arguments,
  required DateTime now,
}) {
  try {
    final payload = SyncRenderPayload.tryParse(
      arguments,
      fallbackCanvasWidth: current.canvasWidth,
      fallbackCanvasHeight: current.canvasHeight,
      fallbackScaleMode: current.outputScaleMode,
      fallbackCurrentMode: current.currentMode,
      fallbackBattle: current.battle,
    );
    return current.withSync(
      renderList: payload.renderList,
      flowMessages: payload.flowMessages,
      canvasWidth: payload.canvasWidth,
      canvasHeight: payload.canvasHeight,
      outputScaleMode: payload.outputScaleMode,
      currentMode: payload.currentMode,
      battle: payload.battle,
      syncedAt: now,
    );
  } on FormatException catch (e) {
    return current.withError(e.message);
  }
}
