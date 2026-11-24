import 'package:flutter/foundation.dart';

class MouseWeapon {
  final String name;
  final String damage;
  final String trait;

  const MouseWeapon({
    required this.name,
    required this.damage,
    required this.trait,
  });

  static MouseWeapon? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final damage = json['damage']?.toString() ?? '';
    if (name.isEmpty && damage.isEmpty) {
      return null;
    }
    return MouseWeapon(
      name: name.isEmpty ? '武器' : name,
      damage: damage,
      trait: json['trait']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'damage': damage,
        'trait': trait,
      };
}

/// 鼠鼠战斗面板的单个玩家快照。
class MousePanelPlayer {
  final String userId;
  final String name;
  final int hp;
  final int hpMax;
  final int armor;
  final int armorMax;
  final String armorType;
  final int slot;
  final int slotMax;
  final int str;
  final int dex;
  final int wil;
  final int lv;
  final String status;
  final List<MouseWeapon> weapons;
  final int updatedAt;

  const MousePanelPlayer({
    required this.userId,
    required this.name,
    required this.hp,
    required this.hpMax,
    required this.armor,
    required this.armorMax,
    required this.armorType,
    required this.slot,
    required this.slotMax,
    required this.str,
    required this.dex,
    required this.wil,
    required this.lv,
    required this.status,
    required this.weapons,
    required this.updatedAt,
  });

  static MousePanelPlayer? fromJson(Map<String, dynamic> json) {
    final userId = json['userId']?.toString() ?? '';
    if (userId.isEmpty) {
      return null;
    }
    final rawWeapons = json['weapons'];
    final weapons = <MouseWeapon>[];
    if (rawWeapons is List) {
      for (final item in rawWeapons) {
        if (item is! Map) {
          continue;
        }
        final weapon = MouseWeapon.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (weapon != null) {
          weapons.add(weapon);
        }
      }
    }
    return MousePanelPlayer(
      userId: userId,
      name: json['name']?.toString() ?? '未命名',
      hp: _asInt(json['hp']) ?? 0,
      hpMax: _asInt(json['hpMax']) ?? 0,
      armor: _asInt(json['armor']) ?? 0,
      armorMax: _asInt(json['armorMax']) ?? 0,
      armorType: json['armorType']?.toString() ?? '',
      slot: _asInt(json['slot']) ?? 0,
      slotMax: _asInt(json['slotMax']) ?? 0,
      str: _asInt(json['str']) ?? 0,
      dex: _asInt(json['dex']) ?? 0,
      wil: _asInt(json['wil']) ?? 0,
      lv: _asInt(json['lv']) ?? 1,
      status: json['status']?.toString() ?? '正常',
      weapons: List.unmodifiable(weapons),
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
        'userId': userId,
        'name': name,
        'hp': hp,
        'hpMax': hpMax,
        'armor': armor,
        'armorMax': armorMax,
        'armorType': armorType,
        'slot': slot,
        'slotMax': slotMax,
        'str': str,
        'dex': dex,
        'wil': wil,
        'lv': lv,
        'status': status,
        'weapons': weapons.map((weapon) => weapon.toJson()).toList(growable: false),
        'updatedAt': updatedAt,
      };
}

class MousePanelSnapshot {
  final String groupId;
  final String endpointId;
  final int updatedAt;
  final List<MousePanelPlayer> players;

  const MousePanelSnapshot({
    required this.groupId,
    required this.endpointId,
    required this.updatedAt,
    required this.players,
  });

  static MousePanelSnapshot? fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId']?.toString() ?? '';
    if (groupId.isEmpty) {
      return null;
    }
    final rawPlayers = json['players'];
    final players = <MousePanelPlayer>[];
    if (rawPlayers is List) {
      for (final item in rawPlayers) {
        if (item is! Map) {
          continue;
        }
        final player = MousePanelPlayer.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (player != null) {
          players.add(player);
        }
      }
    }
    // 鼠鼠规则没有先攻，按名字稳定排序
    players.sort((a, b) => a.name.compareTo(b.name));
    return MousePanelSnapshot(
      groupId: groupId,
      endpointId: json['endpointId']?.toString() ?? '',
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      players: List.unmodifiable(players),
    );
  }
}

class MousePanelCommand {
  final int seq;
  final String type;
  final String groupId;
  final String userId;
  final String text;

  const MousePanelCommand({
    required this.seq,
    required this.type,
    required this.groupId,
    required this.userId,
    required this.text,
  });

  Map<String, Object?> toJson() => {
        'seq': seq,
        'type': type,
        'groupId': groupId,
        'userId': userId,
        'text': text,
      };
}

/// 接收海豹鼠鼠插件推送的战斗面板快照，并维护待下发的推荐指令。
class MousePanelService extends ChangeNotifier {
  MousePanelService({required this.configuredGroupId})
      : sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  /// 返回 gm_hub 当前配置的 QQ 群号；为空时取插件推送的第一个群。
  final String Function() configuredGroupId;

  final String sessionId;

  int _nextSeq = 1;
  int _lastSyncAt = 0;
  bool _refreshRequested = false;
  final Map<String, MousePanelSnapshot> _snapshots =
      <String, MousePanelSnapshot>{};
  final List<MousePanelCommand> _pending = <MousePanelCommand>[];

  MousePanelSnapshot? get snapshot {
    final target = _normalizeGroupId(configuredGroupId());
    if (target.isEmpty) {
      return null;
    }
    return _snapshots[target];
  }

  bool get connected =>
      _lastSyncAt > 0 &&
      DateTime.now().millisecondsSinceEpoch - _lastSyncAt < 5000;

  Map<String, Object?> get panelPayload {
    final target = configuredGroupId().trim();
    final current = snapshot;
    return {
      'system': 'mouse',
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

  /// 供辅助表等外部页面读取的完整群快照，不按 GmHub 配置群过滤。
  Map<String, Object?> get statePayload {
    final groups = _snapshots.values
        .map((snapshot) => <String, Object?>{
              'groupId': snapshot.groupId,
              'endpointId': snapshot.endpointId,
              'updatedAt': snapshot.updatedAt,
              'players': snapshot.players
                  .map((player) => player.toJson())
                  .toList(growable: false),
            })
        .toList(growable: false);
    groups.sort(
      (a, b) => ((b['updatedAt'] as int?) ?? 0).compareTo(
        (a['updatedAt'] as int?) ?? 0,
      ),
    );
    return {
      'ok': true,
      'connected': connected,
      'syncedAt': _lastSyncAt,
      'configuredGroupId': _normalizeGroupId(configuredGroupId()),
      'count': groups.fold<int>(
        0,
        (total, group) => total + (group['players'] as List<Object?>).length,
      ),
      'groups': groups,
    };
  }

  /// 处理插件的一次同步请求，返回本次可下发的推荐指令。
  Map<String, Object?> handleSync(Map<String, dynamic> payload) {
    final lastSessionId = payload['lastSessionId']?.toString() ?? '';
    final processedSeq = _asInt(payload['processedSeq']) ?? 0;
    final effectiveProcessed =
        lastSessionId == sessionId ? processedSeq : 0;

    _pending.removeWhere((command) => command.seq <= effectiveProcessed);

    final groups = payload['groups'];
    if (groups is List) {
      final nextSnapshots = <String, MousePanelSnapshot>{};
      for (final item in groups) {
        if (item is! Map) {
          continue;
        }
        final next = MousePanelSnapshot.fromJson(
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

  /// 面板点击推荐时调用；返回 false 表示当前快照里没有该玩家。
  bool queueRecommend({required String userId, required String text}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final current = snapshot;
    if (current == null) {
      return false;
    }
    final exists = current.players.any((player) => player.userId == userId);
    if (!exists) {
      return false;
    }
    _pending.add(
      MousePanelCommand(
        seq: _nextSeq++,
        type: 'recommend',
        groupId: current.groupId,
        userId: userId,
        text: trimmed,
      ),
    );
    return true;
  }

  /// 关联群号变化后通知面板立即刷新。
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
