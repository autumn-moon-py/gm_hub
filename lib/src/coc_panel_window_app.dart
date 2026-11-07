import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'service/coc/coc_panel_service.dart';

const Color _accent = Color(0xFF006B5E);
const Color _ink = Color(0xFF1B2B33);
const Color _muted = Color(0xFF6B7F8A);
const Color _border = Color(0xFFD9E5EB);

class CocPanelWindowApp extends StatefulWidget {
  final int windowId;

  const CocPanelWindowApp({super.key, required this.windowId});

  @override
  State<CocPanelWindowApp> createState() => _CocPanelWindowAppState();
}

class _CocPanelWindowAppState extends State<CocPanelWindowApp> {
  List<CocPanelPlayer> _players = const <CocPanelPlayer>[];
  final Map<String, bool> _plusMode = <String, bool>{};
  String _groupId = '';
  int _syncedAt = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'coc_panel_sync') {
        _applyPayload(call.arguments);
      }
      return null;
    });
    _loadInitialState();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAlwaysOnTop();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    try {
      final data = await DesktopMultiWindow.invokeMethod(
        0,
        'coc_panel_get_state',
        {},
      ).timeout(const Duration(seconds: 2));
      _applyPayload(data);
    } catch (_) {
      // 主窗口未就绪时保持空面板，后续同步会补齐
    }
  }

  Future<void> _requestRefresh() async {
    try {
      await DesktopMultiWindow.invokeMethod(0, 'coc_panel_refresh', {});
    } catch (_) {
      // 主窗口未就绪时静默忽略
    }
  }

  void _applyPayload(dynamic data) {
    if (data is! Map) {
      return;
    }
    final groupId = data['groupId']?.toString() ?? '';
    final rawSyncedAt = data['syncedAt'];
    final syncedAt = rawSyncedAt is num ? rawSyncedAt.toInt() : 0;
    final rawPlayers = data['players'];
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
    if (!mounted) {
      return;
    }
    setState(() {
      _groupId = groupId;
      _syncedAt = syncedAt;
      _players = players;
    });
  }

  void _setAlwaysOnTop() {
    if (!Platform.isWindows) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final getForegroundWindow = user32
          .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
      final setWindowPos = user32.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');

      final hwnd = getForegroundWindow();
      if (hwnd != 0) {
        const hwndTopmost = -1;
        const swpNomove = 0x0002;
        const swpNosize = 0x0001;
        setWindowPos(hwnd, hwndTopmost, 0, 0, 0, 0, swpNomove | swpNosize);
      }
    } catch (_) {}
  }

  Future<void> _sendHp(CocPanelPlayer player, String op, int value) async {
    if (op == 'delta') {
      if (value < 0 && player.hp <= 0) {
        return;
      }
      final hpMax = player.hpMax;
      if (value > 0 && hpMax != null && player.hp >= hpMax) {
        return;
      }
    } else if (value == player.hp) {
      return;
    }
    try {
      await DesktopMultiWindow.invokeMethod(0, 'coc_panel_hp', {
        'userId': player.userId,
        'op': op,
        'value': value,
      });
    } catch (_) {
      // 主窗口未就绪时静默忽略
    }
  }

  void _applyNumber(CocPanelPlayer player, int amount) {
    final plus = _plusMode[player.userId] == true;
    _sendHp(player, 'delta', plus ? amount : -amount);
  }

  String _syncText() {
    if (_syncedAt <= 0) {
      return '尚未收到数据';
    }
    final time = DateTime.fromMillisecondsSinceEpoch(_syncedAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '最近同步 $hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      title: 'COC 战斗面板',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F8FA),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    final connected =
        _syncedAt > 0 &&
        DateTime.now().millisecondsSinceEpoch - _syncedAt < 5000;
    final statusColor = connected
        ? const Color(0xFF2E9E5B)
        : const Color(0xFF9AA7B1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'COC 战斗面板',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                connected ? '已同步' : '未同步',
                style: TextStyle(fontSize: 11, color: statusColor),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: _requestRefresh,
                tooltip: '手动刷新同步',
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _groupId.isEmpty ? '未关联群号    ${_syncText()}' : '群 $_groupId    ${_syncText()}',
            style: const TextStyle(fontSize: 11, color: _muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _players.isEmpty
                ? Center(
                    child: Text(
                      _groupId.isEmpty
                          ? '未关联群，请在 QQ 桥接卡片填写群号'
                          : connected
                          ? '该群暂无已录卡玩家'
                          : '等待海豹插件同步...',
                      style: const TextStyle(fontSize: 12, color: _muted),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: _players.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildPlayerCard(_players[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(CocPanelPlayer player) {
    final hpMax = player.hpMax;
    final hasMax = hpMax != null && hpMax > 0;
    final ratio = hasMax ? (player.hp / hpMax).clamp(0.0, 1.0) : 0.0;
    final plus = _plusMode[player.userId] == true;
    final canMinus = player.hp > 0;
    final canPlus = !hasMax || player.hp < hpMax;
    final canFull = hasMax && player.hp < hpMax;
    final canZero = player.hp > 0;
    final barColor = hasMax && ratio <= 0.3
        ? const Color(0xFFC0392B)
        : _accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              _badge('先攻 ${player.dex ?? '-'}'),
              const SizedBox(width: 4),
              _badge('MOV ${player.mov ?? '-'}'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                hasMax ? 'HP ${player.hp}/$hpMax' : 'HP ${player.hp}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: hasMax ? ratio : 0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE7EEF3),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _signButton(
                Icons.add,
                plus,
                () => setState(() => _plusMode[player.userId] = true),
              ),
              _signButton(
                Icons.remove,
                !plus,
                () => setState(() => _plusMode[player.userId] = false),
              ),
              for (final amount in [1, 2, 3, 4])
                _numberButton(
                  amount,
                  plus ? canPlus : canMinus,
                  () => _applyNumber(player, amount),
                ),
              _actionButton(
                '满血',
                canFull,
                () => _sendHp(player, 'set', hpMax!),
              ),
              _actionButton('0血', canZero, () => _sendHp(player, 'set', 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2F8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
      ),
    );
  }

  Widget _signButton(IconData icon, bool selected, VoidCallback onTap) {
    return SizedBox(
      width: 30,
      height: 30,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: selected ? _accent : const Color(0xFFF0F5F8),
          foregroundColor: selected ? Colors.white : _ink,
          side: BorderSide(color: selected ? _accent : _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _numberButton(int amount, bool enabled, VoidCallback onTap) {
    return SizedBox(
      width: 30,
      height: 30,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text('$amount', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _actionButton(String label, bool enabled, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
