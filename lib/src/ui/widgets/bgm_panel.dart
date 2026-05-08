import 'package:flutter/material.dart';

import '../../model/project_model.dart';
import '../facade/project_ui_facade.dart';
import 'bgm/bgm_panel_actions.dart';

class BgmPanel extends StatelessWidget {
  final AudioControlFacade facade;

  const BgmPanel({super.key, required this.facade});

  AudioTrackModel? _findTrackById(String? trackId) {
    if (trackId == null) {
      return null;
    }
    for (final track in facade.tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }

  List<Widget> _buildTagPreview(List<String> tags, {int maxVisible = 4}) {
    final visibleTags = tags.take(maxVisible).toList(growable: false);
    final children = <Widget>[
      for (final tag in visibleTags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];
    final hiddenCount = tags.length - visibleTags.length;
    if (hiddenCount > 0) {
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '+$hiddenCount',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF546E7A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return children;
  }

  String _currentTrackTitle(AudioTrackModel? currentTrack) {
    final hasTracks = facade.tracks.isNotEmpty;
    return currentTrack?.name ?? (hasTracks ? '未选择当前曲目' : '暂无音频');
  }

  String _currentTrackSubtitle({
    required AudioStateModel audio,
    required AudioTrackModel? currentTrack,
    required bool currentTrackMissing,
  }) {
    final hasTracks = facade.tracks.isNotEmpty;
    return currentTrack == null
        ? (hasTracks ? '已导入音频，请在音频库中选择当前曲目。' : '打开音频库后可导入 MP3。')
        : (currentTrackMissing ? '文件丢失，请在音频库中重新关联。' : '可直接播放、暂停或调整音量。');
  }

  Widget? _buildCurrentTrackBadge({
    required AudioStateModel audio,
    required bool currentTrackMissing,
  }) {
    if (currentTrackMissing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '文件缺失',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFC62828),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (audio.isPlaying) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '播放中',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildCurrentTrackInline({
    required AudioStateModel audio,
    required AudioTrackModel? currentTrack,
    required bool currentTrackMissing,
  }) {
    final title = _currentTrackTitle(currentTrack);
    final subtitle = _currentTrackSubtitle(
      audio: audio,
      currentTrack: currentTrack,
      currentTrackMissing: currentTrackMissing,
    );
    final stateBadge = _buildCurrentTrackBadge(
      audio: audio,
      currentTrackMissing: currentTrackMissing,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = constraints.maxWidth >= 620
            ? 220.0
            : (constraints.maxWidth * 0.34).clamp(120.0, 220.0).toDouble();
        final subtitleWidth = constraints.maxWidth >= 760
            ? 320.0
            : (constraints.maxWidth * 0.46).clamp(160.0, 320.0).toDouble();

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleWidth),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?stateBadge,
            if (currentTrack != null && currentTrack.tags.isNotEmpty)
              ..._buildTagPreview(currentTrack.tags, maxVisible: 3),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: subtitleWidth),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: currentTrackMissing
                      ? const Color(0xFFC62828)
                      : const Color(0xFF607D8B),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackLibraryButton(BuildContext context) {
    return FilledButton(
      onPressed: () => showTrackLibraryDialog(context, facade: facade),
      child: const Text('音频库'),
    );
  }

  Widget _buildControlButtons(BuildContext context, AudioStateModel audio) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          onPressed: facade.playPause,
          tooltip: '播放/暂停',
          icon: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          onPressed: facade.stop,
          tooltip: '停止',
          icon: const Icon(Icons.stop),
        ),
        IconButton(
          onPressed: facade.toggleLoop,
          tooltip: audio.loop ? '关闭循环' : '开启循环',
          icon: Icon(
            audio.loop ? Icons.repeat_one : Icons.repeat,
            color: audio.loop ? const Color(0xFF1565C0) : null,
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                showVolumeDialog(context, facade: facade, volume: audio.volume),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD7E0E7)),
              ),
              child: Text(
                '音量 ${(audio.volume * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF455A64),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlBar(
    BuildContext context,
    AudioStateModel audio, {
    required AudioTrackModel? currentTrack,
    required bool currentTrackMissing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E0E7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackInfo = _buildCurrentTrackInline(
            audio: audio,
            currentTrack: currentTrack,
            currentTrackMissing: currentTrackMissing,
          );
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControlButtons(context, audio),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrackLibraryButton(context),
                    const SizedBox(width: 10),
                    Expanded(child: trackInfo),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              _buildControlButtons(context, audio),
              const SizedBox(width: 12),
              _buildTrackLibraryButton(context),
              const SizedBox(width: 10),
              Expanded(child: trackInfo),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAudioErrorPanel(
    BuildContext context, {
    required String audioError,
  }) {
    final preview = audioError.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          title: const Text(
            '音频异常',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectionArea(
                child: Text(
                  audioError,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC62828),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => copyText(context, audioError),
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                  label: const Text('复制'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      showTrackLibraryDialog(context, facade: facade),
                  icon: const Icon(Icons.library_music_outlined, size: 18),
                  label: const Text('打开音频库'),
                ),
                TextButton(
                  onPressed: facade.clearAudioError,
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = facade.audioState;
    final currentTrackId = audio.currentTrackId;
    final currentTrack = _findTrackById(currentTrackId);
    final currentTrackMissing =
        currentTrackId != null && facade.isTrackAssetMissing(currentTrackId);
    final audioError = facade.audioError;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFCFD8DC))),
        color: Color(0xFFF6FAFC),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildControlBar(
            context,
            audio,
            currentTrack: currentTrack,
            currentTrackMissing: currentTrackMissing,
          ),
          if (audioError != null && audioError.isNotEmpty)
            _buildAudioErrorPanel(context, audioError: audioError),
        ],
      ),
    );
  }
}
