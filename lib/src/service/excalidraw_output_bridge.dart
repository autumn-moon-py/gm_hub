import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 把骰子输出推送到 Excalidraw 桌面端的右下角展示区。
///
/// 单向、只读展示：投递失败时静默丢弃，不影响本地骰子流程。
class ExcalidrawOutputBridge {
  ExcalidrawOutputBridge._();

  static final ExcalidrawOutputBridge instance = ExcalidrawOutputBridge._();

  /// 与 Excalidraw `electron/main.js` 中约定的端口
  static const int _port = 45870;
  static const Duration _timeout = Duration(milliseconds: 400);

  final HttpClient _client = HttpClient()..connectionTimeout = _timeout;

  void pushMessage({
    required String id,
    required String text,
    required int colorValue,
  }) {
    unawaited(
      _post('/dice-output/message', {
        'id': id,
        'text': text,
        'colorValue': colorValue,
      }),
    );
  }

  void clear() {
    unawaited(_post('/dice-output/clear', const <String, Object?>{}));
  }

  Future<void> _post(String path, Map<String, Object?> body) async {
    try {
      final request = await _client.post('127.0.0.1', _port, path);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(_timeout);
      await response.drain<void>();
    } catch (_) {
      // 展示端未启动或已关闭时忽略。
    }
  }

  void dispose() {
    _client.close(force: true);
  }
}
