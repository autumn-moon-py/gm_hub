import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 跨项目桥接基础客户端。
///
/// 统一约定：固定回环端口、JSON 报文、短超时、失败静默。
/// 具体软件项目在此基础上封装自己的端点，例如 Excalidraw 输出桥接。
class LocalBridgeClient {
  LocalBridgeClient({
    required int port,
    Duration timeout = const Duration(milliseconds: 400),
  })  : _port = port,
        _timeout = timeout,
        _client = HttpClient()..connectionTimeout = timeout;

  final int _port;
  final Duration _timeout;
  final HttpClient _client;

  /// 等待响应的投递；对方未启动、超时或出错时返回 false。
  Future<bool> post(String path, Map<String, Object?> body) {
    return _send('POST', path, body);
  }

  /// 发送后不等待结果，失败静默。
  void postSilently(String path, Map<String, Object?> body) {
    unawaited(_send('POST', path, body));
  }

  Future<bool> _send(
    String method,
    String path,
    Map<String, Object?>? body,
  ) async {
    try {
      final request = await _client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:$_port$path'),
      );
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(_timeout);
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // 对方未启动或已关闭时忽略。
      return false;
    }
  }

  void dispose() {
    _client.close(force: true);
  }
}
