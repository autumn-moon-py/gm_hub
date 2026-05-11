part of 'project_store.dart';

class _ProjectRuntimeDelegate {
  _ProjectRuntimeDelegate(this._store) : _audioPlayer = AudioPlayer();

  final ProjectStore _store;
  final AudioPlayer _audioPlayer;
  final AudioPlayer _diceAudioPlayer = AudioPlayer();

  async_lib.StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _audioError;
  String? _loadedTrackId;
  int _audioTransitionVersion = 0;
  bool _isSwitchingTrackWithFade = false;
  final List<_FlowMessageState> _flowMessages = <_FlowMessageState>[];
  final math.Random _random = math.Random();
  async_lib.Timer? _flowTicker;
  double _flowAreaWidth = 360;
  double _flowAreaHeight = 160;
  double _flowScrollOffset = 0;
  double _flowTargetScrollOffset = 0;
  bool _dicePanelCollapsed = false;
  bool _darkDiceEnabled = false;

  String? get audioError => _audioError;
  bool get dicePanelCollapsed => _dicePanelCollapsed;
  bool get darkDiceEnabled => _darkDiceEnabled;
  List<FlowMessageItem> get flowMessages => _flowMessages
      .map(
        (e) => FlowMessageItem(
          id: e.id,
          text: e.text,
          color: e.color,
          x: e.x,
          y: e.y,
        ),
      )
      .toList(growable: false);

  void bindAudioPlayer() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (_isSwitchingTrackWithFade) {
        return;
      }
      final playing = state == PlayerState.playing;
      if (_store._project.audioState.isPlaying == playing) {
        return;
      }
      _store._project = _store._project.copyWith(
        audioState: _store._project.audioState.copyWith(isPlaying: playing),
      );
      _store._notifyStoreListeners(
        notifyController: false,
        notifyStage: false,
        notifyLayerTree: false,
        notifyAudio: true,
        notifyDice: false,
        notifyTransform: false,
      );
    });
  }

  void dispose() {
    _flowTicker?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _diceAudioPlayer.dispose();
  }

  void resetUiState() {
    _setAudioError(null, notify: false);
    _clearFlowMessages(notify: false);
    _dicePanelCollapsed = false;
  }

  Future<void> stopAudioSession() async {
    _beginAudioTransition();
    await _audioPlayer.stop();
    _loadedTrackId = null;
    _isSwitchingTrackWithFade = false;
  }

  void setDicePanelCollapsed(bool collapsed) {
    if (_dicePanelCollapsed == collapsed) {
      return;
    }
    _dicePanelCollapsed = collapsed;
    _store._notifyStoreListeners(
      notifyController: false,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: true,
      notifyTransform: false,
    );
  }

  void toggleDicePanelCollapsed() {
    setDicePanelCollapsed(!_dicePanelCollapsed);
  }

  void setDarkDiceEnabled(bool enabled) {
    if (_darkDiceEnabled == enabled) {
      return;
    }
    _darkDiceEnabled = enabled;
    _store._notifyStoreListeners(
      notifyController: false,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: true,
      notifyTransform: false,
    );
  }

  void pushFlowMessage(String text, {Color color = Colors.white}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final id = _store._nextId('flow');
    _flowMessages.add(
      _FlowMessageState(
        id: id,
        text: trimmed,
        color: color,
        x: ProjectStore._flowLeftPadding,
        y: ProjectStore._flowTopPadding,
      ),
    );
    _recomputeFlowLayout();
    _ensureFlowTickerRunning();
    _store._notifyStoreListeners(
      notifyController: true,
      notifyStage: true,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
    );
  }

  void clearFlowMessages() {
    _clearFlowMessages(notify: true);
  }

  void setFlowViewport({required double width, required double height}) {
    final nextWidth = width.clamp(200.0, 1200.0);
    final nextHeight = height.clamp(100.0, 800.0);
    if ((_flowAreaWidth - nextWidth).abs() < 0.5 &&
        (_flowAreaHeight - nextHeight).abs() < 0.5) {
      return;
    }
    _flowAreaWidth = nextWidth;
    _flowAreaHeight = nextHeight;
    _recomputeFlowLayout();
    _ensureFlowTickerRunning();
    _store._notifyStoreListeners(
      notifyController: false,
      notifyStage: true,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
    );
  }

  String rollDice(String expression) {
    final result = _rollDiceInternal(expression);
    if (result == null) {
      return '骰子公式无效：$expression';
    }
    final exprForDisplay = _formatDiceExpressionForDisplay(result.normalized);
    final summary = '掷出了 $exprForDisplay=${result.total}';
    final detailed = '$summary\n详细结果: ${result.detail}';
    _pushDiceResult(summary: summary, detailed: detailed);
    return detailed;
  }

  String rollPresetDice(int sides) {
    return rollDice('1d$sides');
  }

  String rollFateDice({
    int count = 4,
    int bonus = 0,
    FateDiceModifierMode modifierMode = FateDiceModifierMode.none,
  }) {
    final diceCount = count <= 0 ? 4 : count;
    final rolls = List<int>.generate(diceCount, (_) => _random.nextInt(3) - 1);
    final baseTotal = rolls.fold<int>(0, (sum, value) => sum + value);
    int? modifierRoll;
    var modifierDelta = 0;
    switch (modifierMode) {
      case FateDiceModifierMode.none:
        break;
      case FateDiceModifierMode.advantage:
        modifierRoll = _random.nextInt(2) + 1;
        modifierDelta = modifierRoll;
        break;
      case FateDiceModifierMode.disadvantage:
        modifierRoll = _random.nextInt(2) + 1;
        modifierDelta = -modifierRoll;
        break;
    }
    final totalResult = baseTotal + bonus + modifierDelta;

    String valueLabel(int value) {
      if (value > 0) {
        return '+1';
      }
      if (value < 0) {
        return '-1';
      }
      return '0';
    }

    String cocDifficulty;
    int hpMark;
    if (totalResult == -4) {
      cocDifficulty = '大失败';
      hpMark = 4;
    } else if (totalResult == 4) {
      cocDifficulty = '大成功';
      hpMark = 4;
    } else if (totalResult <= -1) {
      cocDifficulty = '失败';
      hpMark = 0;
    } else if (totalResult >= 0 && totalResult <= 3) {
      cocDifficulty = '常规';
      hpMark = 1;
    } else if (totalResult >= 4 && totalResult <= 6) {
      cocDifficulty = '困难';
      hpMark = 2;
    } else if (totalResult >= 7) {
      cocDifficulty = '极难';
      hpMark = 3;
    } else {
      cocDifficulty = '未定义';
      hpMark = 0;
    }

    final diceText = rolls.map(valueLabel).join(', ');
    final summary = '掷出了 命运骰=$totalResult';
    final bonusText = '数值加值: ${bonus >= 0 ? '+' : '-'}${bonus.abs()}';
    String modifierText;
    if (modifierMode == FateDiceModifierMode.advantage) {
      modifierText = '额外修正: 优势 d2=$modifierRoll';
    } else if (modifierMode == FateDiceModifierMode.disadvantage) {
      modifierText = '额外修正: 劣势 d2=$modifierRoll';
    } else {
      modifierText = '额外修正: 无';
    }
    final totalSegments = <String>[baseTotal.toString()];
    if (bonus != 0) {
      totalSegments.add('${bonus >= 0 ? '+' : '-'} ${bonus.abs()}');
    }
    if (modifierRoll != null) {
      final sign = modifierMode == FateDiceModifierMode.advantage ? '+' : '-';
      totalSegments.add('$sign $modifierRoll');
    }
    final totalLine = '总结果: ${totalSegments.join(' ')} = $totalResult';
    final detailed = [
      summary,
      '本次结果: [$diceText]',
      bonusText,
      modifierText,
      totalLine,
      'CoC判定: $cocDifficulty',
      '标记血量: $hpMark',
    ].join('\n');
    _pushDiceResult(summary: summary, detailed: detailed);
    return detailed;
  }

  void _pushDiceResult({
    required String summary,
    required String detailed,
  }) {
    final flowText = _darkDiceEnabled ? '黑暗的角落里，传来命运转动的声音' : summary;
    async_lib.unawaited(_playDiceSound());
    pushFlowMessage(flowText, color: const Color(0xFFFFF59D));
  }

  async_lib.Future<void> _playDiceSound() async {
    try {
      await _diceAudioPlayer.stop();
      await _diceAudioPlayer.setReleaseMode(ReleaseMode.stop);
      await _diceAudioPlayer.setVolume(0.35);
      await _diceAudioPlayer.play(AssetSource('骰子.mp3'),
          mode: PlayerMode.lowLatency);
    } catch (_) {
      // 骰子音效失败不影响主流程。
    }
  }

  void setTrack(String? trackId) {
    async_lib.unawaited(_setTrack(trackId));
  }

  bool isTrackAssetMissing(String trackId) {
    final track = _store._findTrackById(trackId);
    if (track == null) {
      return false;
    }
    return !_store._assetPathExists(track.asset);
  }

  String? getTrackAssetPath(String trackId) {
    final track = _store._findTrackById(trackId);
    if (track == null) {
      return null;
    }
    return _store._resolveAssetAbsolutePath(track.asset);
  }

  async_lib.Future<bool> relinkTrackAsset(String trackId) async {
    final track = _store._findTrackById(trackId);
    if (track == null) {
      return false;
    }
    return _store.runWithGlobalLoading(() async {
      final file = await openFile(
        confirmButtonText: '重新选择音频',
        acceptedTypeGroups: const [
          XTypeGroup(label: '音频', extensions: ['mp3']),
        ],
      );
      if (file == null) {
        return false;
      }
      final nextPath = await _store._fileService.importAudioFile(file.path);
      final nextTracks = _store._project.tracks
          .map(
            (item) =>
                item.id == trackId ? item.copyWith(asset: nextPath) : item,
          )
          .toList();
      _store._project = _store._project.copyWith(tracks: nextTracks);
      _setAudioError(null);

      final currentTrackId = _store._project.audioState.currentTrackId;
      if (currentTrackId == trackId) {
        await stopAudioSession();
        _store._project = _store._project.copyWith(
          audioState: _store._project.audioState.copyWith(isPlaying: false),
        );
      }

      _store._onProjectChanged(invalidateAssetExists: true);
      return true;
    });
  }

  bool updateTrackTags(String trackId, List<String> tags) {
    final tracks = _store._project.tracks;
    final trackIndex = tracks.indexWhere((item) => item.id == trackId);
    if (trackIndex < 0) {
      return false;
    }

    final nextTracks = [...tracks];
    nextTracks[trackIndex] = nextTracks[trackIndex].copyWith(tags: tags);
    _store._project = _store._project.copyWith(tracks: nextTracks);
    _store._onProjectChanged();
    return true;
  }

  bool moveTrack(String trackId, int delta) {
    final tracks = _store._project.tracks;
    final fromIndex = tracks.indexWhere((item) => item.id == trackId);
    if (fromIndex < 0) {
      return false;
    }
    final toIndex = fromIndex + delta;
    if (toIndex < 0 || toIndex >= tracks.length) {
      return false;
    }

    final nextTracks = [...tracks];
    final movedTrack = nextTracks.removeAt(fromIndex);
    nextTracks.insert(toIndex, movedTrack);
    _store._project = _store._project.copyWith(tracks: nextTracks);
    _store._onProjectChanged();
    return true;
  }

  async_lib.Future<bool> deleteTrack(String trackId) async {
    final tracks = _store._project.tracks;
    final deleteIndex = tracks.indexWhere((item) => item.id == trackId);
    if (deleteIndex < 0) {
      return false;
    }

    final nextTracks = [...tracks]..removeAt(deleteIndex);
    final currentTrackId = _store._project.audioState.currentTrackId;
    final deletedCurrentTrack = currentTrackId == trackId;
    final shouldStopSession = deletedCurrentTrack || _loadedTrackId == trackId;

    String? nextCurrentTrackId = currentTrackId;
    if (deletedCurrentTrack) {
      if (nextTracks.isEmpty) {
        nextCurrentTrackId = null;
      } else {
        final fallbackIndex = math.min(deleteIndex, nextTracks.length - 1);
        nextCurrentTrackId = nextTracks[fallbackIndex].id;
      }
    }

    if (shouldStopSession) {
      await stopAudioSession();
    }

    _store._project = _store._project.copyWith(
      tracks: nextTracks,
      audioState: _store._project.audioState.copyWith(
        currentTrackId:
            deletedCurrentTrack ? nextCurrentTrackId : currentTrackId,
        isPlaying:
            shouldStopSession ? false : _store._project.audioState.isPlaying,
      ),
    );
    _setAudioError(null);
    _store._onProjectChanged();
    return true;
  }

  void toggleLoop() {
    async_lib.unawaited(_toggleLoop());
  }

  void setVolume(double value) {
    async_lib.unawaited(_setVolume(value));
  }

  void playPause() {
    async_lib.unawaited(_playPause());
  }

  void stop() {
    async_lib.unawaited(_stopPlayback());
  }

  async_lib.Future<void> applyAudioStateToPlayer() async {
    await _audioPlayer.setVolume(_store._project.audioState.volume);
    await _audioPlayer.setReleaseMode(
      _store._project.audioState.loop ? ReleaseMode.loop : ReleaseMode.stop,
    );
  }

  void clearAudioError() {
    _setAudioError(null);
  }

  void setAudioError(String? value) {
    _setAudioError(value);
  }

  void _clearFlowMessages({required bool notify}) {
    if (_flowMessages.isEmpty) {
      if (!notify) {
        _flowTicker?.cancel();
        _flowTicker = null;
        _flowScrollOffset = 0;
        _flowTargetScrollOffset = 0;
      }
      return;
    }
    _flowMessages.clear();
    _flowTicker?.cancel();
    _flowTicker = null;
    _flowScrollOffset = 0;
    _flowTargetScrollOffset = 0;
    if (notify) {
      _store._notifyStoreListeners(
        notifyController: true,
        notifyStage: true,
        notifyLayerTree: false,
        notifyAudio: false,
        notifyDice: false,
        notifyTransform: false,
      );
    }
  }

  void _ensureFlowTickerRunning() {
    if (_flowMessages.isEmpty) {
      _flowTicker?.cancel();
      _flowTicker = null;
      return;
    }
    if ((_flowTargetScrollOffset - _flowScrollOffset).abs() < 0.5) {
      return;
    }
    if (_flowTicker != null) {
      return;
    }
    _flowTicker = async_lib.Timer.periodic(const Duration(milliseconds: 33), (
      _,
    ) {
      if (_flowMessages.isEmpty) {
        _flowTicker?.cancel();
        _flowTicker = null;
        return;
      }
      final delta = _flowTargetScrollOffset - _flowScrollOffset;
      if (delta.abs() < 0.5) {
        _flowScrollOffset = _flowTargetScrollOffset;
        _recomputeFlowLayout();
        _store._notifyStoreListeners(
          notifyController: false,
          notifyStage: true,
          notifyLayerTree: false,
          notifyAudio: false,
          notifyDice: false,
          notifyTransform: false,
        );
        _flowTicker?.cancel();
        _flowTicker = null;
        return;
      }
      final step = ProjectStore._flowScrollSpeed * 0.033;
      _flowScrollOffset += delta.sign * math.min(delta.abs(), step);
      _recomputeFlowLayout();
      _store._notifyStoreListeners(
        notifyController: false,
        notifyStage: true,
        notifyLayerTree: false,
        notifyAudio: false,
        notifyDice: false,
        notifyTransform: false,
      );
    });
  }

  void _recomputeFlowLayout() {
    final contentHeight = ProjectStore._flowTopPadding +
        _flowMessages.length * ProjectStore._flowRowHeight +
        ProjectStore._flowBottomPadding;
    _flowTargetScrollOffset = math.max(0.0, contentHeight - _flowAreaHeight);
    if (_flowScrollOffset > _flowTargetScrollOffset) {
      _flowScrollOffset = _flowTargetScrollOffset;
    }
    for (var i = 0; i < _flowMessages.length; i++) {
      final msg = _flowMessages[i];
      msg.x = ProjectStore._flowLeftPadding;
      msg.y = ProjectStore._flowTopPadding +
          i * ProjectStore._flowRowHeight -
          _flowScrollOffset;
    }
  }

  String _formatDiceExpressionForDisplay(String normalized) {
    final tokenPattern = RegExp(r'[+-]?[^+-]+');
    final tokens = tokenPattern
        .allMatches(normalized)
        .map((m) => m.group(0)!)
        .where((e) => e.isNotEmpty)
        .toList();
    final out = <String>[];
    for (final token in tokens) {
      var sign = '';
      var body = token;
      if (body.startsWith('+')) {
        sign = '+';
        body = body.substring(1);
      } else if (body.startsWith('-')) {
        sign = '-';
        body = body.substring(1);
      }
      final m = RegExp(r'^1d(\d+)$').firstMatch(body);
      if (m != null) {
        body = 'd${m.group(1)!}';
      }
      if (out.isEmpty && sign == '+') {
        sign = '';
      }
      out.add('$sign$body');
    }
    return out.join();
  }

  _DiceRollResult? _rollDiceInternal(String expression) {
    final normalized =
        expression.toLowerCase().replaceAll(' ', '').replaceAll('-', '+-');
    if (normalized.isEmpty) {
      return null;
    }
    final tokenPattern = RegExp(r'[+-]?[^+-]+');
    final tokens = tokenPattern
        .allMatches(normalized)
        .map((m) => m.group(0)!)
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty || tokens.join() != normalized) {
      return null;
    }

    var total = 0;
    final details = <String>[];
    for (final token in tokens) {
      var sign = 1;
      var body = token;
      if (body.startsWith('+')) {
        body = body.substring(1);
      } else if (body.startsWith('-')) {
        sign = -1;
        body = body.substring(1);
      }
      if (body.isEmpty) {
        return null;
      }
      final dIndex = body.indexOf('d');
      if (dIndex >= 0) {
        final countRaw = body.substring(0, dIndex);
        final sidesRaw = body.substring(dIndex + 1);
        final count = countRaw.isEmpty ? 1 : int.tryParse(countRaw);
        final sides = int.tryParse(sidesRaw);
        if (count == null || sides == null) {
          return null;
        }
        if (count <= 0 || count > 100 || sides <= 1 || sides > 1000) {
          return null;
        }
        var part = 0;
        final rolls = <int>[];
        for (var i = 0; i < count; i++) {
          final roll = _random.nextInt(sides) + 1;
          rolls.add(roll);
          part += roll;
        }
        total += part * sign;
        final prefix = sign < 0 ? '-' : (details.isEmpty ? '' : '+');
        details.add('$prefix$count'
            'd$sides'
            '[${rolls.join(',')}]');
      } else {
        final value = int.tryParse(body);
        if (value == null) {
          return null;
        }
        total += value * sign;
        final prefix = sign < 0 ? '-' : (details.isEmpty ? '' : '+');
        details.add('$prefix$value');
      }
    }
    return _DiceRollResult(
      normalized: normalized,
      total: total,
      detail: details.join(' '),
    );
  }

  int _beginAudioTransition() {
    _audioTransitionVersion += 1;
    _isSwitchingTrackWithFade = false;
    return _audioTransitionVersion;
  }

  bool _isAudioTransitionCurrent(int version) {
    return _audioTransitionVersion == version;
  }

  async_lib.Future<bool> _fadePlayerVolume({
    required double from,
    required double to,
    required int transitionVersion,
  }) async {
    final start = from.clamp(0.0, 1.0).toDouble();
    final end = to.clamp(0.0, 1.0).toDouble();
    final fadeStepCount = ProjectStore._audioFadeSteps;
    final stepDelayMilliseconds = fadeStepCount <= 1
        ? 0
        : (ProjectStore._audioFadeTotalDuration.inMilliseconds /
                (fadeStepCount - 1))
            .round();
    final stepDelay = stepDelayMilliseconds <= 0
        ? Duration.zero
        : Duration(milliseconds: stepDelayMilliseconds);
    if (!_isAudioTransitionCurrent(transitionVersion)) {
      return false;
    }
    if ((start - end).abs() < 0.0001) {
      await _audioPlayer.setVolume(end);
      return _isAudioTransitionCurrent(transitionVersion);
    }
    for (var step = 1; step <= fadeStepCount; step++) {
      if (!_isAudioTransitionCurrent(transitionVersion)) {
        return false;
      }
      final progress = step / fadeStepCount;
      final volume = start + (end - start) * progress;
      await _audioPlayer.setVolume(volume);
      if (step < fadeStepCount && stepDelay > Duration.zero) {
        await async_lib.Future<void>.delayed(stepDelay);
      }
    }
    return _isAudioTransitionCurrent(transitionVersion);
  }

  async_lib.Future<bool> _startCurrentTrackPlayback({
    double? initialVolume,
    int? transitionVersion,
  }) async {
    var trackId = _store._project.audioState.currentTrackId;
    if (trackId == null && _store._project.tracks.isNotEmpty) {
      trackId = _store._project.tracks.first.id;
      _store._project = _store._project.copyWith(
        audioState:
            _store._project.audioState.copyWith(currentTrackId: trackId),
      );
    }
    if (trackId == null) {
      _setAudioError('未选择音频曲目。');
      return false;
    }
    final track = _store._findTrackById(trackId);
    final absPath =
        track == null ? null : _store._resolveAssetAbsolutePath(track.asset);
    if (absPath == null || absPath.isEmpty || !File(absPath).existsSync()) {
      _setAudioError(track == null ? '音频路径无效。' : '未找到音频文件：${track.asset}');
      return false;
    }
    if (transitionVersion != null &&
        !_isAudioTransitionCurrent(transitionVersion)) {
      return false;
    }

    final startVolume = (initialVolume ?? _store._project.audioState.volume)
        .clamp(0.0, 1.0)
        .toDouble();
    await _audioPlayer.setReleaseMode(
      _store._project.audioState.loop ? ReleaseMode.loop : ReleaseMode.stop,
    );
    await _audioPlayer.setVolume(startVolume);
    if (transitionVersion != null &&
        !_isAudioTransitionCurrent(transitionVersion)) {
      return false;
    }

    if (_loadedTrackId == trackId) {
      await _audioPlayer.resume();
    } else {
      await _audioPlayer.play(DeviceFileSource(absPath));
      _loadedTrackId = trackId;
    }
    await _audioPlayer.setVolume(startVolume);
    if (transitionVersion != null &&
        !_isAudioTransitionCurrent(transitionVersion)) {
      return false;
    }

    _setAudioError(null);
    _store._project = _store._project.copyWith(
      audioState: _store._project.audioState.copyWith(isPlaying: true),
    );
    _store._onProjectChanged();
    return true;
  }

  async_lib.Future<void> _switchTrackWithFade(int transitionVersion) async {
    _isSwitchingTrackWithFade = true;
    try {
      final fadeOutStartVolume =
          _store._project.audioState.volume.clamp(0.0, 1.0).toDouble();
      final fadedOut = await _fadePlayerVolume(
        from: fadeOutStartVolume,
        to: 0,
        transitionVersion: transitionVersion,
      );
      if (!fadedOut || !_isAudioTransitionCurrent(transitionVersion)) {
        return;
      }

      await _audioPlayer.stop();
      if (!_isAudioTransitionCurrent(transitionVersion)) {
        return;
      }
      _loadedTrackId = null;

      final started = await _startCurrentTrackPlayback(
        initialVolume: 0,
        transitionVersion: transitionVersion,
      );
      if (!started || !_isAudioTransitionCurrent(transitionVersion)) {
        if (_isAudioTransitionCurrent(transitionVersion)) {
          _store._project = _store._project.copyWith(
            audioState: _store._project.audioState.copyWith(isPlaying: false),
          );
          _store._onProjectChanged();
        }
        return;
      }

      final fadeInTargetVolume =
          _store._project.audioState.volume.clamp(0.0, 1.0).toDouble();
      final fadedIn = await _fadePlayerVolume(
        from: 0,
        to: fadeInTargetVolume,
        transitionVersion: transitionVersion,
      );
      if (!fadedIn || !_isAudioTransitionCurrent(transitionVersion)) {
        return;
      }
      await _audioPlayer.setVolume(fadeInTargetVolume);
      _store._onProjectChanged();
    } finally {
      if (_isAudioTransitionCurrent(transitionVersion)) {
        _isSwitchingTrackWithFade = false;
      }
    }
  }

  async_lib.Future<void> _setTrack(String? trackId) async {
    final wasPlaying = _store._project.audioState.isPlaying;
    final transitionVersion = _beginAudioTransition();
    try {
      _setAudioError(null);
      _store._project = _store._project.copyWith(
        audioState: _store._project.audioState.copyWith(
          currentTrackId: trackId,
          isPlaying: trackId != null && wasPlaying,
        ),
      );
      _store._onProjectChanged(
        notifyController: false,
        notifyStage: false,
        notifyLayerTree: false,
        notifyAudio: true,
        notifyDice: false,
        notifyTransform: false,
        invalidateRenderList: false,
      );
      if (trackId == null) {
        await stopAudioSession();
        return;
      }
      if (wasPlaying) {
        await _switchTrackWithFade(transitionVersion);
        return;
      }
      if (_loadedTrackId != trackId) {
        await stopAudioSession();
      }
    } catch (e, st) {
      debugPrint('setTrack failed: $e\n$st');
      _setAudioError('音频控制异常: $e');
    }
  }

  async_lib.Future<void> _toggleLoop() async {
    try {
      final next = !_store._project.audioState.loop;
      _store._project = _store._project.copyWith(
        audioState: _store._project.audioState.copyWith(loop: next),
      );
      await _audioPlayer.setReleaseMode(
        next ? ReleaseMode.loop : ReleaseMode.stop,
      );
      _store._onProjectChanged();
    } catch (e, st) {
      debugPrint('toggleLoop failed: $e\n$st');
      _setAudioError('音频控制异常: $e');
    }
  }

  async_lib.Future<void> _setVolume(double value) async {
    final nextVolume = value.clamp(0.0, 1.0).toDouble();
    try {
      _store._project = _store._project.copyWith(
        audioState: _store._project.audioState.copyWith(volume: nextVolume),
      );
      await _audioPlayer.setVolume(nextVolume);
      _store._onProjectChanged();
    } catch (e, st) {
      debugPrint('setVolume failed: $e\n$st');
      _setAudioError('音频控制异常: $e');
    }
  }

  async_lib.Future<void> _playPause() async {
    final transitionVersion = _beginAudioTransition();
    try {
      if (_store._project.audioState.isPlaying) {
        await _audioPlayer.pause();
        _store._project = _store._project.copyWith(
          audioState: _store._project.audioState.copyWith(isPlaying: false),
        );
        _store._onProjectChanged();
        return;
      }
      await _startCurrentTrackPlayback(transitionVersion: transitionVersion);
    } catch (e, st) {
      debugPrint('playPause failed: $e\n$st');
      _setAudioError('音频控制异常: $e');
    }
  }

  async_lib.Future<void> _stopPlayback() async {
    _beginAudioTransition();
    try {
      await _audioPlayer.stop();
      _loadedTrackId = null;
      _store._project = _store._project.copyWith(
        audioState: _store._project.audioState.copyWith(isPlaying: false),
      );
      _store._onProjectChanged();
    } catch (e, st) {
      debugPrint('stopPlayback failed: $e\n$st');
      _setAudioError('音频控制异常: $e');
    }
  }

  void _setAudioError(String? value, {bool notify = true}) {
    if (_audioError == value) {
      return;
    }
    _audioError = value;
    if (notify) {
      _store._notifyStoreListeners(
        notifyController: false,
        notifyStage: false,
        notifyLayerTree: false,
        notifyAudio: true,
        notifyDice: false,
        notifyTransform: false,
      );
    }
  }
}
