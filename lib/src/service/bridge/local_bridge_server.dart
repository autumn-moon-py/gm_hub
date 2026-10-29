import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 跨项目桥接基础服务。
///
/// 统一约定：仅监听回环地址、JSON 报文、CORS 放行、health 探测，
/// 端口被占用时静默放弃；业务路由由各软件项目的桥接子类实现。
abstract class LocalBridgeServer {
  LocalBridgeServer({
    required this.port,
    required this.healthPath,
    required this.appName,
  });

  final int port;
  final String healthPath;
  final String appName;

  static const int _maxBodyBytes = 4096;

  HttpServer? _server;

  /// 处理 health 之外的业务路由；返回 false 表示未命中。
  Future<bool> handle(HttpRequest request, HttpResponse response);

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      server.listen(_dispatch, onError: (Object _) {});
    } catch (_) {
      // 端口被其他实例占用时放弃启动，调用方继续走本地流程。
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _dispatch(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.set('Cache-Control', 'no-store');
    response.headers.contentType = ContentType.json;

    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }
      if (request.method == 'GET' && request.uri.path == healthPath) {
        await respond(response, HttpStatus.ok, {'ok': true, 'app': appName});
        return;
      }
      if (await handle(request, response)) {
        return;
      }
      await respond(response, HttpStatus.notFound, {
        'ok': false,
        'error': 'not found',
      });
    } catch (_) {
      try {
        await respond(response, HttpStatus.badRequest, {
          'ok': false,
          'error': 'bad request',
        });
      } catch (_) {
        // 连接已断开时忽略。
      }
    }
  }

  /// 读取请求体，超出上限时抛出异常。
  Future<String> readBody(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.length > _maxBodyBytes) {
      throw const FormatException('payload too large');
    }
    return body;
  }

  Future<void> respond(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response.statusCode = status;
    response.write(jsonEncode(body));
    await response.close();
  }
}
