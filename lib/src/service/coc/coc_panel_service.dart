import 'package:flutter/foundation.dart';

/// COC 战斗面板的单个玩家快照。
class CocPanelPlayer {
  final String userId;
  final String name;
  final int hp;
  final int? hpMax;
  final int? dex;
  final int? mov;
  final int updatedAt;

  const CocPanelPlayer({
    required this.userId,
    required this.name,
    required this.hp,
    required this.hpMax,
    required this.dex,
    required this.mov,
    required this.updatedAt,
  });

  static CocPanelPlayer? fromJson(Map<String, dynamic> json) {
    final userId = json['userId']?.toString() ?? '';
    if (userId.isEmpty) {
      return null;
    }
    final hp = _asInt(json['hp']) ?? 0;
    return CocPanelPlayer(
      userId: userId,
      name: json['name']?.toString() ?? '未命名',
      hp: hp,
      hpMax: _asInt(json['hpMax']),
      dex: _asInt(json['dex']),
      mov: _asInt(json['mov']),
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
        'userId': userId,
        'name': name,
        'hp': hp,
        'hpMax': hpMax,
        'dex': dex,
        'mov': mov,
        'updatedAt': updatedAt,
      };
}

class CocPanelSnapshot {
  final String groupId;
  final String endpointId;
  final int updatedAt;
  final List<CocPanelPlayer> players;

  const CocPanelSnapshot({
    required this.groupId,
    required this.endpointId,
    required this.updatedAt,
    required this.players,
  });

  static CocPanelSnapshot? fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId']?.toString() ?? '';
    if (groupId.isEmpty) {
      return null;
    }
    final rawPlayers = json['players'];
    final players = <CocPanelPlayer>[];
    if (rawPlayers is List) {
      for (final item in rawPlayers) {
        if (item is! Map) {
          continue;
        }
        final player = CocPanelPlayer.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (player != null) {
          players.add(player);
        }
      }
    }
    players.sort((a, b) {
      final dexA = a.dex;
      final dexB = b.dex;
      if (dexA != dexB) {
        if (dexA == null) return 1;
        if (dexB == null) return -1;
        return dexB.compareTo(dexA);
      }
      return a.name.compareTo(b.name);
    });
    return CocPanelSnapshot(
      groupId: groupId,
      endpointId: json['endpointId']?.toString() ?? '',
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      players: List.unmodifiable(players),
    );
  }
}

class CocPanelCommand {
  final int seq;
  final String type;
  final String groupId;
  final String userId;
  final String op;
  final int value;

  const CocPanelCommand({
    required this.seq,
    required this.type,
    required this.groupId,
    required this.userId,
    required this.op,
    required this.value,
  });

  Map<String, Object?> toJson() => {
        'seq': seq,
        'type': type,
        'groupId': groupId,
        'userId': userId,
        'op': op,
        'value': value,
      };
}

/// 接收海豹插件推送的战斗面板快照，并维护待下发的改血指令。
class CocPanelService extends ChangeNotifier {
  CocPanelService({required this.configuredGroupId})
      : sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  /// 返回 gm_hub 当前配置的 QQ 群号；为空时取插件推送的第一个群。
  final String Function() configuredGroupId;

  final String sessionId;

  int _nextSeq = 1;
  int _lastSyncAt = 0;
  bool _refreshRequested = false;
  final Map<String, CocPanelSnapshot> _snapshots =
      <String, CocPanelSnapshot>{};
  final List<CocPanelCommand> _pending = <CocPanelCommand>[];

  /// 只返回当前关联群号的快照，绝不回退到其它群。
  /// 插件上报的是 `QQ-Group:138165759` 这类平台 ID，这里按最后一段数字匹配。
  CocPanelSnapshot? get _selectedSnapshot {
    final target = _normalizeGroupId(configuredGroupId());
    if (target.isEmpty) {
      return null;
    }
    return _snapshots[target];
  }

  CocPanelSnapshot? get snapshot => _selectedSnapshot;

  bool get connected =>
      _lastSyncAt > 0 &&
      DateTime.now().millisecondsSinceEpoch - _lastSyncAt < 5000;

  Map<String, Object?> get panelPayload {
    final target = configuredGroupId().trim();
    final current = _selectedSnapshot;
    return {
      'groupId': target,
      'connected': connected,
      'syncedAt': _lastSyncAt,
      'updatedAt': current?.updatedAt ?? 0,
      'players': current?.players
              .map((player) => player.toJson())
              .toList(growable: false) ??
          const <Object?>[],
    };
  }

  /// 处理插件的一次同步请求，返回本次可下发的指令。
  Map<String, Object?> handleSync(Map<String, dynamic> payload) {
    final lastSessionId = payload['lastSessionId']?.toString() ?? '';
    final processedSeq = _asInt(payload['processedSeq']) ?? 0;
    final effectiveProcessed =
        lastSessionId == sessionId ? processedSeq : 0;

    _pending.removeWhere((command) => command.seq <= effectiveProcessed);

    final groups = payload['groups'];
    if (groups is List) {
      final nextSnapshots = <String, CocPanelSnapshot>{};
      for (final item in groups) {
        if (item is! Map) {
          continue;
        }
        final next = CocPanelSnapshot.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (next != null) {
          nextSnapshots[_normalizeGroupId(next.groupId)] = next;
        }
      }
      _snapshots
        ..clear()
        ..addAll(nextSnapshots);
    }
    _lastSyncAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();

    final commands = _pending
        .where((command) => command.seq > effectiveProcessed)
        .map((command) => command.toJson())
        .toList(growable: false);
    final refresh = _refreshRequested;
    _refreshRequested = false;
    return {
      'ok': true,
      'sessionId': sessionId,
      'commands': commands,
      'refresh': refresh,
    };
  }

  /// 面板点击改血时调用；返回 false 表示当前快照里没有该玩家。
  bool queueHpCommand({
    required String userId,
    required String op,
    required int value,
  }) {
    if (op != 'delta' && op != 'set') {
      return false;
    }
    final current = _selectedSnapshot;
    if (current == null) {
      return false;
    }
    final exists = current.players.any((player) => player.userId == userId);
    if (!exists) {
      return false;
    }
    _pending.add(
      CocPanelCommand(
        seq: _nextSeq++,
        type: 'hp',
        groupId: current.groupId,
        userId: userId,
        op: op,
        value: value,
      ),
    );
    return true;
  }

  /// 关联群号变化后通知面板立即刷新，避免继续显示旧群数据。
  void onConfiguredGroupChanged() {
    notifyListeners();
  }

  /// 面板手动刷新：让插件在下一次同步时立即回推一次快照。
  void requestRefresh() {
    _refreshRequested = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _pending.clear();
    super.dispose();
  }
}

int? _asInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// `QQ-Group:138165759` 与 `138165759` 视为同一个群。
String _normalizeGroupId(String value) {
  final trimmed = value.trim();
  final index = trimmed.lastIndexOf(':');
  return index >= 0 ? trimmed.substring(index + 1) : trimmed;
}
