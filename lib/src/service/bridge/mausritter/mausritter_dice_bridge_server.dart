import 'dart:convert';
import 'dart:io';

import '../local_bridge_server.dart';

/// 45871 本地桥接：承载勇敢鼠鼠骰子公式与 COC 战斗面板同步。
class MausritterDiceBridgeServer extends LocalBridgeServer {
  MausritterDiceBridgeServer({
    required this.roll,
    this.reportDiceResult,
    this.clearDiceResult,
    this.syncCocPanel,
    this.syncMousePanel,
    this.mousePanelState,
  }) : super(
          port: bridgePort,
          healthPath: '/dice/health',
          appName: 'gm_hub',
        );

  /// 与辅助表 `static/js/dice-bridge.js` 约定的端口
  static const int bridgePort = 45871;

  /// 结算公式并返回展示文本；返回 null 表示公式无效。
  final String? Function(String expression) roll;

  /// 接收外部页面已结算的结果文本并推送展示，不重新掷骰。
  final void Function(String text)? reportDiceResult;

  /// 清空骰子输出区，与骰子面板的清空按钮一致。
  final void Function()? clearDiceResult;

  /// COC 战斗面板同步；为空时该路由返回不可用。
  final Map<String, Object?> Function(Map<String, dynamic> payload)?
      syncCocPanel;

  /// 鼠鼠战斗面板同步；为空时该路由返回不可用。
  final Map<String, Object?> Function(Map<String, dynamic> payload)?
      syncMousePanel;

  /// 鼠鼠面板快照只读查询（GET /mouse/panel/state），供辅助表等外部页面使用。
  final Map<String, Object?> Function()? mousePanelState;

  @override
  Future<bool> handle(HttpRequest request, HttpResponse response) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/mouse/panel/state') {
      await respond(
        response,
        HttpStatus.ok,
        mousePanelState?.call() ?? {'ok': false, 'error': 'mouse panel unavailable'},
      );
      return true;
    }
    final isCocSync = request.method == 'POST' && path == '/coc/panel/sync';
    final isMouseSync = request.method == 'POST' && path == '/mouse/panel/sync';
    if (isCocSync || isMouseSync) {
      final handler = isMouseSync ? syncMousePanel : syncCocPanel;
      if (handler == null) {
        await respond(response, HttpStatus.serviceUnavailable, {
          'ok': false,
          'error': isMouseSync ? 'mouse panel unavailable' : 'coc panel unavailable',
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
    if (request.method == 'POST' && path == '/dice/clear') {
      final handler = clearDiceResult;
      if (handler == null) {
        await respond(response, HttpStatus.serviceUnavailable, {
          'ok': false,
          'error': 'dice clear unavailable',
        });
        return true;
      }
      handler();
      await respond(response, HttpStatus.ok, {'ok': true});
      return true;
    }
    if (request.method == 'POST' && path == '/dice/report') {
      final handler = reportDiceResult;
      if (handler == null) {
        await respond(response, HttpStatus.serviceUnavailable, {
          'ok': false,
          'error': 'dice report unavailable',
        });
        return true;
      }
      final text = _readReportText(await readBody(request));
      if (text == null) {
        await respond(response, HttpStatus.badRequest, {
          'ok': false,
          'error': 'empty text',
        });
        return true;
      }
      handler(text);
      await respond(response, HttpStatus.ok, {'ok': true});
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

  /// 读取外部页面提交的展示文本，最长 2000 字符。
  String? _readReportText(String body) {
    if (body.isEmpty) {
      return null;
    }
    final payload = jsonDecode(body);
    if (payload is! Map) {
      return null;
    }
    final text = payload['text'];
    if (text is! String) {
      return null;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
  }
}
