import 'dart:convert';
import 'dart:io';

import '../local_bridge_server.dart';

/// 45871 本地桥接：承载勇敢鼠鼠骰子公式与 COC 战斗面板同步。
class MausritterDiceBridgeServer extends LocalBridgeServer {
  MausritterDiceBridgeServer({
    required this.roll,
    this.syncCocPanel,
  }) : super(
          port: bridgePort,
          healthPath: '/dice/health',
          appName: 'gm_hub',
        );

  /// 与辅助表 `static/js/dice-bridge.js` 约定的端口
  static const int bridgePort = 45871;

  /// 结算公式并返回展示文本；返回 null 表示公式无效。
  final String? Function(String expression) roll;

  /// COC 战斗面板同步；为空时该路由返回不可用。
  final Map<String, Object?> Function(Map<String, dynamic> payload)?
      syncCocPanel;

  @override
  Future<bool> handle(HttpRequest request, HttpResponse response) async {
    if (request.method == 'POST' && request.uri.path == '/coc/panel/sync') {
      final handler = syncCocPanel;
      if (handler == null) {
        await respond(response, HttpStatus.serviceUnavailable, {
          'ok': false,
          'error': 'coc panel unavailable',
        });
        return true;
      }
      final decoded = jsonDecode(await readBody(request));
      if (decoded is! Map) {
        await respond(response, HttpStatus.badRequest, {
          'ok': false,
          'error': 'bad payload',
        });
        return true;
      }
      final result = handler(Map<String, dynamic>.from(decoded));
      await respond(response, HttpStatus.ok, result);
      return true;
    }
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
