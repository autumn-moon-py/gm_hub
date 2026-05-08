import 'dart:async';

import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';
import 'layer_tree_panel.dart';

class RightSidebarPanel extends StatelessWidget {
  const RightSidebarPanel({super.key, required this.facade});

  final LayerTreeFacade facade;

  static const double _sectionHeaderHeight = 42;
  static const double _sectionBorderWidth = 1;
  static const double _sectionSpacing = 8;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: facade.treeListenable,
      builder: (context, child) {
        final notesCollapsed = facade.notesPanelCollapsed;
        final treeCollapsed = facade.layerTreePanelCollapsed;
        return Container(
          color: const Color(0xFFF3F7FA),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!notesCollapsed)
                Expanded(
                  child: _SidebarSection(
                    title: '笔记区',
                    onToggle: facade.toggleNotesPanelCollapsed,
                    child: ListenableBuilder(
                      listenable: facade.notesListenable,
                      builder: (context, child) {
                        return _NotesEditor(facade: facade);
                      },
                    ),
                  ),
                ),
              if (notesCollapsed)
                _SidebarCollapsedSection(
                  title: '笔记区',
                  onToggle: facade.toggleNotesPanelCollapsed,
                ),
              const SizedBox(height: _sectionSpacing),
              if (!treeCollapsed)
                Expanded(
                  child: _SidebarSection(
                    title: '图层树',
                    onToggle: facade.toggleLayerTreePanelCollapsed,
                    trailing: LayerTreeSelectionActions(facade: facade),
                    child: LayerTreePanel(facade: facade, showHeader: false),
                  ),
                ),
              if (treeCollapsed)
                _SidebarCollapsedSection(
                  title: '图层树',
                  onToggle: facade.toggleLayerTreePanelCollapsed,
                ),
            ],
          ),
        );
      },
    );
  }

  static const double _collapsedSectionHeight =
      _sectionHeaderHeight + _sectionBorderWidth * 2;
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.title,
    required this.onToggle,
    required this.child,
    this.trailing,
  });

  final String title;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        border: Border.all(color: const Color(0xFFD7E0E6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            _SidebarHeader(
              title: title,
              onToggle: onToggle,
              trailing: trailing,
              collapsed: false,
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SidebarCollapsedSection extends StatelessWidget {
  const _SidebarCollapsedSection({required this.title, required this.onToggle});

  final String title;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: RightSidebarPanel._collapsedSectionHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7FA),
          border: Border.all(color: const Color(0xFFD7E0E6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: _SidebarHeader(
            title: title,
            onToggle: onToggle,
            collapsed: true,
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.title,
    required this.onToggle,
    required this.collapsed,
    this.trailing,
  });

  final String title;
  final VoidCallback onToggle;
  final bool collapsed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDDE5EA),
      child: InkWell(
        onTap: onToggle,
        child: SizedBox(
          height: RightSidebarPanel._sectionHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) ...[
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: const Color(0xFF42515C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesEditor extends StatefulWidget {
  const _NotesEditor({required this.facade, this.showExpandButton = true});

  final LayerTreeFacade facade;
  final bool showExpandButton;

  @override
  State<_NotesEditor> createState() => _NotesEditorState();
}

class _NotesEditorState extends State<_NotesEditor> {
  static const double _expandButtonSize = 34;
  static const double _expandButtonRightInset = 10;
  static const double _expandButtonBottomInset = 10;
  static const Duration _notesSyncDebounceDuration = Duration(
    milliseconds: 120,
  );

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  Timer? _notesSyncTimer;
  String _syncedText = '';

  @override
  void initState() {
    super.initState();
    _syncedText = widget.facade.notesText;
    _controller = TextEditingController(text: _syncedText);
    _focusNode = FocusNode(debugLabel: 'notes editor');
    _scrollController = ScrollController(
      initialScrollOffset: widget.facade.notesEditorViewState.scrollOffset,
    );
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_saveViewState);
    _scrollController.addListener(_saveViewState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode.hasFocus) {
        return;
      }
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _NotesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.facade.notesText;
    if (nextText == _syncedText || nextText == _controller.text) {
      return;
    }
    if (_focusNode.hasFocus || _controller.value.composing.isValid) {
      return;
    }
    final savedSelection = widget.facade.notesEditorViewState.selection;
    final baseOffset = savedSelection == null
        ? nextText.length
        : savedSelection.baseOffset.clamp(0, nextText.length);
    final extentOffset = savedSelection == null
        ? nextText.length
        : savedSelection.extentOffset.clamp(0, nextText.length);
    _syncedText = nextText;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: savedSelection == null
          ? TextSelection.collapsed(offset: nextText.length)
          : TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
    );
  }

  @override
  void dispose() {
    _flushPendingNotesSync();
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_saveViewState);
    _scrollController.removeListener(_saveViewState);
    _notesSyncTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final nextText = _controller.text;
    if (nextText == _syncedText) {
      return;
    }
    _syncedText = nextText;
    _notesSyncTimer?.cancel();
    _notesSyncTimer = Timer(_notesSyncDebounceDuration, () {
      _notesSyncTimer = null;
      if (!mounted) {
        return;
      }
      widget.facade.updateNotesText(nextText);
      _saveViewState();
    });
  }

  void _flushPendingNotesSync() {
    final timer = _notesSyncTimer;
    if (timer == null) {
      return;
    }
    timer.cancel();
    _notesSyncTimer = null;
    widget.facade.updateNotesText(_syncedText);
  }

  void _saveViewState() {
    widget.facade.updateNotesEditorViewState(
      widget.facade.notesEditorViewState.copyWith(
        selection: _controller.selection,
        scrollOffset: _scrollController.hasClients
            ? _scrollController.offset
            : 0,
      ),
    );
  }

  void _openFullscreenEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NotesFullscreenPage(facade: widget.facade),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                right: 0,
                bottom: widget.showExpandButton
                    ? _expandButtonBottomInset + _expandButtonSize + 8
                    : 0,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                scrollController: _scrollController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF22323A),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                  hintText: '在这里记录笔记...',
                ),
              ),
            ),
          ),
          if (widget.showExpandButton)
            Positioned(
              right: _expandButtonRightInset,
              bottom: _expandButtonBottomInset,
              child: Tooltip(
                message: '全屏编辑',
                child: Material(
                  color: const Color(0xFFF1F4F6),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _openFullscreenEditor,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 18,
                        color: Color(0xFF42515C),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesFullscreenPage extends StatelessWidget {
  const _NotesFullscreenPage({required this.facade});

  final LayerTreeFacade facade;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(title: const Text('笔记区')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD7E0E6)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListenableBuilder(
              listenable: facade.notesListenable,
              builder: (context, child) {
                return _NotesEditor(facade: facade, showExpandButton: false);
              },
            ),
          ),
        ),
      ),
    );
  }
}
