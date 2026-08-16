import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../model/project_model.dart';
import '../../facade/project_ui_facade.dart';

AudioTrackModel? _findTrackById(
  List<AudioTrackModel> tracks,
  String? trackId,
) {
  if (trackId == null) {
    return null;
  }
  for (final track in tracks) {
    if (track.id == trackId) {
      return track;
    }
  }
  return null;
}

List<String> _parseTrackTagsInput(String raw) {
  final result = <String>[];
  final seen = <String>{};
  for (final part in raw.split(RegExp(r'[\r\n,，;；]+'))) {
    final value = part.trim();
    if (value.isEmpty) {
      continue;
    }
    final key = value.toLowerCase();
    if (seen.add(key)) {
      result.add(value);
    }
  }
  return result;
}

bool _sameTrackTags(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

Widget _buildTrackBadge(
  String text, {
  required Color backgroundColor,
  required Color foregroundColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: foregroundColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _buildTrackSection({
  required String title,
  required Widget child,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF607D8B),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      child,
    ],
  );
}

String _buildTrackTagSummary(List<String> tags) {
  if (tags.isEmpty) {
    return '暂无标签';
  }
  final previewTags = tags.take(3).toList(growable: false);
  final hiddenTagCount = tags.length - previewTags.length;
  final summary = previewTags.join(' · ');
  if (hiddenTagCount <= 0) {
    return summary;
  }
  return '$summary · +$hiddenTagCount';
}

class _InlineTrackTagEditor extends StatefulWidget {
  const _InlineTrackTagEditor({
    required this.facade,
    required this.track,
  });

  final AudioControlFacade facade;
  final AudioTrackModel track;

  @override
  State<_InlineTrackTagEditor> createState() => _InlineTrackTagEditorState();
}

class _InlineTrackTagEditorState extends State<_InlineTrackTagEditor> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.track.tags.join('，'));
    _scrollController = ScrollController(keepScrollOffset: false);
  }

  @override
  void didUpdateWidget(covariant _InlineTrackTagEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameTrackTags(oldWidget.track.tags, widget.track.tags)) {
      return;
    }
    if (_sameTrackTags(_parseTrackTagsInput(_controller.text), widget.track.tags)) {
      return;
    }
    final nextText = widget.track.tags.join('，');
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _saveTags(String raw) {
    final nextTags = _parseTrackTagsInput(raw);
    if (_sameTrackTags(nextTags, widget.track.tags)) {
      return;
    }
    widget.facade.updateTrackTags(widget.track.id, nextTags);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      scrollController: _scrollController,
      minLines: 1,
      maxLines: 2,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintText: '用逗号或换行分隔标签',
      ),
      onChanged: _saveTags,
      onSubmitted: _saveTags,
    );
  }
}

Widget _buildTrackCard({
  required AudioControlFacade facade,
  required AudioTrackModel track,
  required int position,
  required int trackCount,
  required bool isCurrent,
  VoidCallback? onDragHandleLongPress,
  VoidCallback? onDragHandleEnd,
  double? dragFeedbackWidth,
}) {
  return _TrackCard(
    facade: facade,
    track: track,
    position: position,
    trackCount: trackCount,
    isCurrent: isCurrent,
    onDragHandleLongPress: onDragHandleLongPress,
    onDragHandleEnd: onDragHandleEnd,
    dragFeedbackWidth: dragFeedbackWidth,
  );
}

class _TrackCard extends StatefulWidget {
  const _TrackCard({
    required this.facade,
    required this.track,
    required this.position,
    required this.trackCount,
    required this.isCurrent,
    this.onDragHandleLongPress,
    this.onDragHandleEnd,
    this.dragFeedbackWidth,
  });

  final AudioControlFacade facade;
  final AudioTrackModel track;
  final int position;
  final int trackCount;
  final bool isCurrent;
  final VoidCallback? onDragHandleLongPress;
  final VoidCallback? onDragHandleEnd;
  final double? dragFeedbackWidth;

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.facade.isTrackAssetMissing(widget.track.id);
  }

  @override
  void didUpdateWidget(covariant _TrackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id == widget.track.id) {
      return;
    }
    _expanded = widget.facade.isTrackAssetMissing(widget.track.id);
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  void _setCurrentTrack() {
    if (widget.isCurrent) {
      return;
    }
    widget.facade.setTrack(widget.track.id);
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.facade.isTrackAssetMissing(widget.track.id);
    final fullPath =
        widget.facade.getTrackAssetPath(widget.track.id) ?? widget.track.asset;
    final tagSummary = _buildTrackTagSummary(widget.track.tags);
    final subtitleColor = widget.track.tags.isEmpty
        ? const Color(0xFF90A4AE)
        : const Color(0xFF1565C0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.isCurrent ? const Color(0xFFEAF4FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: missing
              ? const Color(0xFFFFCDD2)
              : widget.isCurrent
                  ? const Color(0xFF90CAF9)
                  : const Color(0xFFD8E3EA),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  InkWell(
                    onTap: _toggleExpanded,
                    onDoubleTap: _setCurrentTrack,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 10, 12, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.track.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (missing)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: _buildTrackBadge(
                                          '文件缺失',
                                          backgroundColor: const Color(0xFFFFEBEE),
                                          foregroundColor: const Color(0xFFC62828),
                                        ),
                                      ),
                                    if (widget.isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: _buildTrackBadge(
                                          '当前',
                                          backgroundColor: const Color(0xFF1565C0),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tagSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: widget.track.tags.isEmpty
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: const Color(0xFF607D8B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 40,
                    child: Draggable<int>(
                      data: widget.position,
                      onDragStarted: widget.onDragHandleLongPress,
                      onDragEnd: (_) => widget.onDragHandleEnd?.call(),
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: widget.dragFeedbackWidth ?? 200,
                          child: Opacity(
                            opacity: 0.85,
                            child: _buildTrackCard(
                              facade: widget.facade,
                              track: widget.track,
                              position: widget.position,
                              trackCount: widget.trackCount,
                              isCurrent: widget.isCurrent,
                            ),
                          ),
                        ),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Center(
                          child: Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: const Color(0xFF90A4AE),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              _buildTrackSection(
                                title: '完整路径',
                                child: SelectionArea(
                                  child: Text(
                                    fullPath,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: missing
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF455A64),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildTrackSection(
                                title: '标签',
                                child: _InlineTrackTagEditor(
                                  facade: widget.facade,
                                  track: widget.track,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildTrackSection(
                                title: '操作',
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await widget.facade.relinkTrackAsset(
                                          widget.track.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.folder_open_outlined,
                                        size: 16,
                                      ),
                                      label: Text(missing ? '重新关联' : '更换文件'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await widget.facade.deleteTrack(
                                          widget.track.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      label: const Text('删除'),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        foregroundColor:
                                            const Color(0xFFC62828),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableTrackGrid extends StatefulWidget {
  const _DraggableTrackGrid({
    required this.facade,
    required this.tracks,
  });

  final AudioControlFacade facade;
  final List<AudioTrackModel> tracks;

  @override
  State<_DraggableTrackGrid> createState() => _DraggableTrackGridState();
}

class _DraggableTrackGridState extends State<_DraggableTrackGrid> {
  int? _draggingIndex;
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < widget.tracks.length; i++)
                _buildDraggableItem(
                  index: i,
                  cardWidth: cardWidth,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableItem({
    required int index,
    required double cardWidth,
  }) {
    final track = widget.tracks[index];
    final isCurrent = track.id == widget.facade.audioState.currentTrackId;
    final isDragging = _draggingIndex == index;
    final isHovered = _hoverIndex == index && _draggingIndex != null && _draggingIndex != index;

    return SizedBox(
      width: cardWidth,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            _hoverIndex = index;
          });
          return true;
        },
        onLeave: (_) {
          if (_hoverIndex == index) {
            setState(() {
              _hoverIndex = null;
            });
          }
        },
        onAcceptWithDetails: (details) {
          final fromIndex = details.data;
          if (fromIndex != index) {
            widget.facade.reorderTrack(fromIndex, index);
          }
          setState(() {
            _draggingIndex = null;
            _hoverIndex = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHovered
                  ? Border.all(color: const Color(0xFF1565C0), width: 2)
                  : null,
            ),
            child: Opacity(
              opacity: isDragging ? 0.3 : 1.0,
              child: _buildTrackCard(
                facade: widget.facade,
                track: track,
                position: index,
                trackCount: widget.tracks.length,
                isCurrent: isCurrent,
                onDragHandleLongPress: () {
                  setState(() {
                    _draggingIndex = index;
                  });
                },
                onDragHandleEnd: () {
                  setState(() {
                    _draggingIndex = null;
                    _hoverIndex = null;
                  });
                },
                dragFeedbackWidth: cardWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> showTrackLibraryDialog(
  BuildContext context, {
  required AudioControlFacade facade,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      const preferredDialogHeight = 705.0;
      final availableDialogHeight =
          MediaQuery.sizeOf(dialogContext).height - 32;
      final dialogHeight = availableDialogHeight < preferredDialogHeight
          ? availableDialogHeight
          : preferredDialogHeight;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SizedBox(
          width: 860,
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: ListenableBuilder(
              listenable: facade.audioListenable,
              builder: (context, _) {
                final tracks = facade.tracks;
                final currentTrack = _findTrackById(
                  tracks,
                  facade.audioState.currentTrackId,
                );
                var missingCount = 0;
                for (final track in tracks) {
                  if (facade.isTrackAssetMissing(track.id)) {
                    missingCount += 1;
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '音频库',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD9E4EA)),
                      ),
                      child: Text(
                        tracks.isEmpty
                            ? '还没有导入任何音频。'
                            : '共 ${tracks.length} 首音频'
                                '${currentTrack == null ? '，未选择当前曲目' : '，当前：${currentTrack.name}'}'
                                '${missingCount > 0 ? '，$missingCount 首文件缺失' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF455A64),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (tracks.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await facade.importTrack();
                          },
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 18,
                          ),
                          label: const Text('导入 MP3'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (tracks.isEmpty)
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FBFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDCE6EC),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.library_music_outlined,
                                  size: 32,
                                  color: Color(0xFF78909C),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await facade.importTrack();
                                  },
                                  icon: const Icon(
                                    Icons.file_upload_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('导入 MP3'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _DraggableTrackGrid(facade: facade, tracks: tracks),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
}

Future<void> showVolumeDialog(
  BuildContext context, {
  required AudioControlFacade facade,
  required double volume,
}) async {
  var currentVolume = volume;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            child: SizedBox(
              width: 260,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '音量',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      min: 0,
                      max: 1,
                      value: currentVolume,
                      onChanged: (value) {
                        setState(() {
                          currentVolume = value;
                        });
                        facade.setVolume(value);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('${(currentVolume * 100).round()}%'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

IconData volumeIcon(double volume) {
  if (volume <= 0.001) {
    return Icons.volume_off;
  }
  if (volume < 0.5) {
    return Icons.volume_down;
  }
  return Icons.volume_up;
}
