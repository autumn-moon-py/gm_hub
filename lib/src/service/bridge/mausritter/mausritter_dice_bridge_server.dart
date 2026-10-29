import 'dart:convert';
import 'dart:io';

import '../local_bridge_server.dart';

/// 接收勇敢鼠鼠辅助表投递的骰子公式，由本项目统一结算。
class MausritterDiceBridgeServer extends LocalBridgeServer {
  MausritterDiceBridgeServer({required this.roll})
      : super(
          port: bridgePort,
          healthPath: '/dice/health',
          appName: 'gm_hub',
        );

  /// 与辅助表 `static/js/dice-bridge.js` 约定的端口
  static const int bridgePort = 45871;

  /// 结算公式并返回展示文本；返回 null 表示公式无效。
  final String? Function(String expression) roll;

  @override
  Future<bool> handle(HttpRequest request, HttpResponse response) async {
    if (request.method != 'POST' || request.uri.path != '/dice/roll') {
      return false;
    }
    final expression = _readExpression(await readBody(request));
    if (expression == null) {
      await respond(response, HttpStatus.badRequest, {
        'ok': false,
        'error': 'empty expression',
      });
      return true;
    }
    final text = roll(expression);
    if (text == null) {
      await respond(response, HttpStatus.badRequest, {
        'ok': false,
        'error': 'invalid expression',
      });
      return true;
    }
    await respond(response, HttpStatus.ok, {'ok': true, 'text': text});
    return true;
  }

  String? _readExpression(String body) {
    if (body.isEmpty) {
      return null;
    }
    final payload = jsonDecode(body);
    if (payload is! Map) {
      return null;
    }
    final expression = payload['expression'];
    if (expression is! String) {
      return null;
    }
    final trimmed = expression.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
