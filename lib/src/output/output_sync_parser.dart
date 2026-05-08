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
    );
    return current.withSync(
      renderList: payload.renderList,
      flowMessages: payload.flowMessages,
      canvasWidth: payload.canvasWidth,
      canvasHeight: payload.canvasHeight,
      outputScaleMode: payload.outputScaleMode,
      syncedAt: now,
    );
  } on FormatException catch (e) {
    return current.withError(e.message);
  }
}
