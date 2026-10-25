import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// NapCat WebSocket 连接状态。
enum QQGroupBridgeStatus { connecting, connected, disconnected }

/// 连接 NapCat 的 OneBot WebSocket 服务，获取指定群内骰娘发送的文本消息。
///
/// NapCat 登录账号通常就是骰娘本身，其发出的消息不会以普通 message 事件上报，
/// 因此这里以群历史轮询为主、message/message_sent 事件为辅。
class QQGroupBridge {
  QQGroupBridge({
    required this.onDiceMessage,
    required this.onStatusChanged,
    this.wsUrl = 'ws://127.0.0.1:3001',
    this.accessToken = '9mXsigBR6Fd6BbP.',
    this.diceUserId = 1024120029,
  });

  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _historyCount = 30;

  final void Function(String text) onDiceMessage;
  final void Function(QQGroupBridgeStatus status) onStatusChanged;
  final String wsUrl;
  final String accessToken;
  final int diceUserId;

  String _groupId = '';
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  QQGroupBridgeStatus _status = QQGroupBridgeStatus.disconnected;
  bool _disposed = false;
  bool _baselineReady = false;
  final LinkedHashSet<String> _seenMessageIds = LinkedHashSet<String>();
  int _echoSeed = 0;
  String? _pendingHistoryEcho;

  QQGroupBridgeStatus get status => _status;

  void updateGroupId(String groupId) {
    final next = groupId.trim();
    if (_groupId == next) {
      return;
    }
    _groupId = next;
    _baselineReady = false;
    _seenMessageIds.clear();
    _pendingHistoryEcho = null;
    if (next.isNotEmpty) {
      _requestHistory();
    }
  }

  Future<void> start() async {
    if (_disposed || _socket != null) {
      return;
    }
    _setStatus(QQGroupBridgeStatus.connecting);
    try {
      final socket = await WebSocket.connect(
        _buildUri().toString(),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _setStatus(QQGroupBridgeStatus.connected);
      _subscription = socket.listen(
        _handleRawMessage,
        onDone: _handleDisconnected,
        onError: (_) => _handleDisconnected(),
        cancelOnError: true,
      );
      _startPolling();
    } catch (_) {
      _handleDisconnected();
    }
  }

  Uri _buildUri() {
    final base = Uri.parse(wsUrl);
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'access_token': accessToken,
      },
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _requestHistory());
    _requestHistory();
  }

  void _requestHistory() {
    final socket = _socket;
    final groupId = _groupId;
    if (socket == null || groupId.isEmpty) {
      return;
    }
    final echo = 'history_${_echoSeed++}';
    _pendingHistoryEcho = echo;
    try {
      socket.add(
        jsonEncode({
          'action': 'get_group_msg_history',
          'params': {
            'group_id': int.tryParse(groupId) ?? groupId,
            'count': _historyCount,
          },
          'echo': echo,
        }),
      );
    } catch (_) {
      _pendingHistoryEcho = null;
    }
  }

  void _handleDisconnected() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingHistoryEcho = null;
    _subscription?.cancel();
    _subscription = null;
    _socket = null;
    if (_disposed) {
      return;
    }
    _setStatus(QQGroupBridgeStatus.disconnected);
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      unawaited(start());
    });
  }

  void _setStatus(QQGroupBridgeStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    onStatusChanged(status);
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) {
      return;
    }
    if (decoded.containsKey('post_type')) {
      _handleEvent(decoded);
    } else {
      _handleActionResponse(decoded);
    }
  }

  /// 兼容 message（他人消息）与 message_sent（NapCat 自身账号发出的消息）。
  void _handleEvent(Map decoded) {
    final postType = decoded['post_type']?.toString();
    if (postType != 'message' && postType != 'message_sent') {
      return;
    }
    if (decoded['message_type'] != 'group') {
      return;
    }
    final groupId = decoded['group_id']?.toString() ?? '';
    if (_groupId.isEmpty || groupId != _groupId) {
      return;
    }
    final senderId =
        decoded['user_id']?.toString() ?? decoded['self_id']?.toString();
    if (senderId != diceUserId.toString()) {
      return;
    }
    final messageId = _readInt(decoded['message_id']);
    if (messageId > 0 && !_rememberMessage(messageId)) {
      return;
    }
    final text = _extractMessageText(decoded['message']);
    if (text.isEmpty) {
      return;
    }
    onDiceMessage(text);
  }

  void _handleActionResponse(Map decoded) {
    final echo = decoded['echo']?.toString();
    if (echo == null || echo != _pendingHistoryEcho) {
      return;
    }
    _pendingHistoryEcho = null;
    final data = decoded['data'];
    if (data is! Map) {
      return;
    }
    final messages = data['messages'];
    if (messages is! List) {
      _baselineReady = true;
      return;
    }

    final parsed = <_HistoryMessage>[];
    for (final raw in messages) {
      if (raw is! Map) {
        continue;
      }
      final id = _readInt(raw['message_id']);
      if (id <= 0) {
        continue;
      }
      final sender = raw['sender'];
      final senderId = _readInt(
        raw['user_id'] ?? (sender is Map ? sender['user_id'] : null),
      );
      parsed.add(
        _HistoryMessage(
          id: id,
          senderId: senderId,
          time: _readInt(raw['time']),
          text: _extractMessageText(raw['message']),
        ),
      );
    }
    parsed.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    if (parsed.isEmpty) {
      _baselineReady = true;
      return;
    }

    if (!_baselineReady) {
      // 首次只记录基线，避免把历史消息当作新消息刷出。
      _baselineReady = true;
      for (final message in parsed) {
        _rememberMessage(message.id);
      }
      return;
    }

    for (final message in parsed) {
      if (!_rememberMessage(message.id)) {
        continue;
      }
      if (message.senderId == diceUserId && message.text.isNotEmpty) {
        onDiceMessage(message.text);
      }
    }
  }

  /// 返回 true 表示该消息首次出现；message_id 在 NapCat 中并非单调递增，
  /// 因此用集合去重而不是 ID 大小游标。
  bool _rememberMessage(int messageId) {
    final added = _seenMessageIds.add(messageId.toString());
    if (_seenMessageIds.length > 2000) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
    return added;
  }

  /// 兼容 Array / String 两种消息格式，图片与表情以占位文本呈现。
  String _extractMessageText(dynamic message) {
    if (message is String) {
      return message.trim();
    }
    if (message is! List) {
      return '';
    }
    final buffer = StringBuffer();
    for (final segment in message) {
      if (segment is! Map) {
        continue;
      }
      final type = segment['type']?.toString();
      final data = segment['data'];
      switch (type) {
        case 'text':
          if (data is Map) {
            buffer.write(data['text']?.toString() ?? '');
          }
          break;
        case 'at':
          if (data is Map) {
            final qq = data['qq']?.toString() ?? '';
            buffer.write('@$qq');
          }
          break;
        case 'image':
          buffer.write('[图片]');
          break;
        case 'face':
          buffer.write('[表情]');
          break;
      }
    }
    return buffer.toString().trim();
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
  }
}

class _HistoryMessage {
  const _HistoryMessage({
    required this.id,
    required this.senderId,
    required this.time,
    required this.text,
  });

  final int id;
  final int senderId;
  final int time;
  final String text;
}
