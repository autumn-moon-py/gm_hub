import '../local_bridge_client.dart';

/// 把骰子输出推送到 Excalidraw 桌面端的右下角展示区。
///
/// 单向、只读展示：投递失败时静默丢弃，不影响本地骰子流程。
class ExcalidrawOutputBridge {
  ExcalidrawOutputBridge._();

  static final ExcalidrawOutputBridge instance = ExcalidrawOutputBridge._();

  /// 与 Excalidraw `electron/main.js` 中约定的端口
  static const int _port = 45870;

  final LocalBridgeClient _client = LocalBridgeClient(port: _port);

  void pushMessage({
    required String id,
    required String text,
    required int colorValue,
  }) {
    _client.postSilently('/dice-output/message', {
      'id': id,
      'text': text,
      'colorValue': colorValue,
    });
  }

  void clear() {
    _client.postSilently('/dice-output/clear', const <String, Object?>{});
  }

  void dispose() {
    _client.dispose();
  }
}
