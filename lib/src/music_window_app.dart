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
  bool _searchVisible = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
      if (tracks.isEmpty) {
        _searchVisible = false;
        _query = '';
        _searchController.clear();
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
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _toggleSearch() {
    if (_tracks.isEmpty) {
      return;
    }
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _query = '';
        _searchController.clear();
      }
    });
    if (_searchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
    });
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }

  bool _matchesQuery(_MiniTrack track, String query) {
    if (track.name.toLowerCase().contains(query)) {
      return true;
    }
    for (final tag in track.tags) {
      if (tag.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  List<_MiniTrack> get _visibleTracks {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return _tracks;
    }
    return [
      for (final track in _tracks)
        if (_matchesQuery(track, query)) track,
    ];
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
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 38),
                  child: Text(
                    _title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.25,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: _buildSearchToggleButton(hasTracks),
                ),
              ],
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

  /// 播放器卡片右上角的圆形搜索按钮。
  Widget _buildSearchToggleButton(bool enabled) {
    final active = _searchVisible;
    final iconColor = !enabled
        ? const Color(0xFFB0BEC5)
        : (active ? _accent : const Color(0xFF546E7A));
    return Tooltip(
      message: active ? '关闭搜索' : '搜索音频',
      child: Material(
        color: active ? _accentSoft : Colors.white,
        shape: CircleBorder(
          side: BorderSide(
            color: active ? const Color(0xFFAFD8D2) : _cardBorder,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? _toggleSearch : null,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(Icons.search_rounded, size: 18, color: iconColor),
          ),
        ),
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
    if (_tracks.isEmpty) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white),
        child: _buildEmptyState(),
      );
    }
    final visibleTracks = _visibleTracks;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          if (_searchVisible) _buildSearchField(),
          Expanded(
            child: visibleTracks.isEmpty
                ? _buildNoResultState()
                : _buildTrackList(visibleTracks),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(fontSize: 12.5, color: _ink),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF3F8FA),
          hintText: '搜索名称或标签',
          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF90A4AE)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: _muted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 30,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearQuery,
                  tooltip: '清空',
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: _muted,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 28,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _updateQuery,
      ),
    );
  }

  Widget _buildNoResultState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 26, color: Color(0xFFA9BBC4)),
            SizedBox(height: 8),
            Text(
              '没有匹配的音频',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildTrackList(List<_MiniTrack> tracks) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 6),
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        indent: 38,
        color: Color(0xFFEEF3F6),
      ),
      itemBuilder: (context, index) => _buildTrackTile(tracks[index]),
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
