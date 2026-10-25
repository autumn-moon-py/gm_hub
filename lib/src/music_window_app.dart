import 'dart:ffi' hide Size;
import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const Color _accent = Color(0xFF006B5E);
const Color _accentSoft = Color(0xFFE2F2EF);
const Color _ink = Color(0xFF1B2B33);
const Color _muted = Color(0xFF6B7F8A);
const Color _cardBorder = Color(0xFFD9E5EB);

class _MiniTrack {
  final String id;
  final String name;
  final List<String> tags;

  const _MiniTrack({required this.id, required this.name, required this.tags});
}

class MusicWindowApp extends StatefulWidget {
  final int windowId;

  const MusicWindowApp({super.key, required this.windowId});

  @override
  State<MusicWindowApp> createState() => _MusicWindowAppState();
}

class _MusicWindowAppState extends State<MusicWindowApp> {
  List<_MiniTrack> _tracks = const [];
  String? _currentTrackId;
  bool _isPlaying = false;
  bool _loop = true;
  double _volume = 0.3;
  bool _initialized = false;
  bool _volumeDragging = false;

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'audio_sync') {
        _applyPayload(call.arguments);
      }
      return null;
    });
    _initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAlwaysOnTop();
    });
  }

  Future<void> _initState() async {
    try {
      final state = await DesktopMultiWindow.invokeMethod(
        0,
        'music_get_state',
        {},
      );
      _applyPayload(state);
    } catch (_) {}
    if (mounted && !_initialized) {
      setState(() {
        _initialized = true;
      });
    }
  }

  void _applyPayload(dynamic data) {
    if (data is! Map) {
      return;
    }
    final rawTracks = data['tracks'];
    final tracks = <_MiniTrack>[];
    if (rawTracks is List) {
      for (final item in rawTracks) {
        if (item is! Map) {
          continue;
        }
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }
        final rawTags = item['tags'];
        tracks.add(
          _MiniTrack(
            id: id,
            name: item['name']?.toString() ?? '未命名曲目',
            tags: rawTags is List
                ? rawTags.map((tag) => tag.toString()).toList(growable: false)
                : const [],
          ),
        );
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _tracks = tracks;
      _currentTrackId = data['currentTrackId']?.toString();
      _isPlaying = data['isPlaying'] == true;
      _loop = data['loop'] != false;
      final volume = data['volume'];
      if (!_volumeDragging && volume is num) {
        _volume = volume.toDouble().clamp(0.0, 1.0);
      }
      _initialized = true;
    });
  }

  void _setAlwaysOnTop() {
    if (!Platform.isWindows) {
      return;
    }
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final getForegroundWindow = user32
          .lookupFunction<IntPtr Function(), int Function()>(
            'GetForegroundWindow',
          );
      final setWindowPos = user32
          .lookupFunction<
            Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
            int Function(int, int, int, int, int, int, int)
          >('SetWindowPos');

      final hwnd = getForegroundWindow();
      if (hwnd != 0) {
        const hwndTopmost = -1;
        const swpNomove = 0x0002;
        const swpNosize = 0x0001;
        setWindowPos(hwnd, hwndTopmost, 0, 0, 0, 0, swpNomove | swpNosize);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    DesktopMultiWindow.setMethodHandler(null);
    super.dispose();
  }

  Future<void> _send(String method, [Map<String, dynamic>? arguments]) async {
    try {
      await DesktopMultiWindow.invokeMethod(0, method, arguments ?? const {});
    } catch (_) {}
  }

  void _togglePlay() {
    if (_tracks.isEmpty) {
      return;
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
    _send('music_play_pause');
  }

  void _stop() {
    setState(() {
      _isPlaying = false;
    });
    _send('music_stop');
  }

  void _toggleLoop() {
    setState(() {
      _loop = !_loop;
    });
    _send('music_toggle_loop');
  }

  void _selectTrack(String trackId) {
    if (trackId == _currentTrackId) {
      return;
    }
    setState(() {
      _currentTrackId = trackId;
    });
    _send('music_set_track', {'trackId': trackId});
  }

  _MiniTrack? get _currentTrack {
    final currentId = _currentTrackId;
    if (currentId == null) {
      return null;
    }
    for (final track in _tracks) {
      if (track.id == currentId) {
        return track;
      }
    }
    return null;
  }

  String get _title {
    final track = _currentTrack;
    if (track != null) {
      return track.name;
    }
    return _tracks.isEmpty ? '暂无音频' : '未选择曲目';
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
      title: '音乐悬浮窗',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFEAF1F6),
        body: _initialized
            ? _buildContent()
            : const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
      ),
    );
  }

  Widget _buildContent() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7FBFD), Color(0xFFE6EFF5)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlayerCard(),
            Expanded(child: _buildTrackListCard()),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard() {
    final hasTracks = _tracks.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          Text(
            _title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPlayButton(hasTracks),
              const SizedBox(width: 10),
              _buildIconButton(
                icon: Icons.stop_rounded,
                tooltip: '停止',
                onTap: hasTracks ? _stop : null,
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: _loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                tooltip: _loop ? '关闭循环' : '开启循环',
                active: _loop,
                onTap: _toggleLoop,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_volumeIcon, size: 16, color: _muted),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: _accent,
                    inactiveTrackColor: const Color(0xFFDCE7EC),
                    thumbColor: _accent,
                    overlayColor: const Color(0x1A006B5E),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 13,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: 1,
                    value: _volume,
                    onChanged: (value) {
                      setState(() {
                        _volumeDragging = true;
                        _volume = value;
                      });
                    },
                    onChangeEnd: (value) {
                      _volumeDragging = false;
                      _send('music_set_volume', {'value': value});
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${(_volume * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _volumeIcon {
    if (_volume <= 0.001) {
      return Icons.volume_off_rounded;
    }
    if (_volume < 0.5) {
      return Icons.volume_down_rounded;
    }
    return Icons.volume_up_rounded;
  }

  Widget _buildPlayButton(bool enabled) {
    final background = enabled ? _accent : const Color(0xFFB9C8CF);
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? _togglePlay : null,
        child: SizedBox(
          width: 35,
          height: 35,
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _accentSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: active ? const Color(0xFFAFD8D2) : _cardBorder,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              size: 19,
              color: active ? _accent : const Color(0xFF546E7A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackListCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white),
      child: _tracks.isEmpty ? _buildEmptyState() : _buildTrackList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, size: 28, color: Color(0xFFA9BBC4)),
            SizedBox(height: 8),
            Text(
              '暂无音频',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '可在主窗口的音频库中导入 MP3',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _tracks.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        indent: 38,
        color: Color(0xFFEEF3F6),
      ),
      itemBuilder: (context, index) => _buildTrackTile(_tracks[index]),
    );
  }

  Widget _buildTrackTile(_MiniTrack track) {
    final selected = track.id == _currentTrackId;
    final icon = selected
        ? (_isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded)
        : Icons.music_note_rounded;
    return InkWell(
      onTap: () => _selectTrack(track.id),
      child: Container(
        color: selected ? _accentSoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? _accent : const Color(0xFFA0B3BD),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? _accent : _ink,
                    ),
                  ),
                  if (track.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        track.tags.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: _muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
