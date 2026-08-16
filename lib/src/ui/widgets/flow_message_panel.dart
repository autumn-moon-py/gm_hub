import 'package:flutter/material.dart';

import '../../store/project_store.dart';

class FlowMessagePanel extends StatefulWidget {
  const FlowMessagePanel({
    super.key,
    required this.messages,
    this.onViewportChanged,
    this.width = 280,
    this.height = 130,
  });

  final List<FlowMessageItem> messages;
  final ValueChanged<Size>? onViewportChanged;
  final double width;
  final double height;

  @override
  State<FlowMessagePanel> createState() => _FlowMessagePanelState();
}

class _FlowMessagePanelState extends State<FlowMessagePanel> {
  Size? _lastViewport;
  bool _viewportUpdateScheduled = false;
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  void _scheduleViewportUpdate(Size viewport) {
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted) return;
      widget.onViewportChanged?.call(viewport);
    });
  }

  bool _viewportChanged(Size next) {
    final current = _lastViewport;
    if (current == null) return true;
    return (current.width - next.width).abs() > 0.5 ||
        (current.height - next.height).abs() > 0.5;
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController
          .jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewportChanged(viewport)) {
            _lastViewport = viewport;
            _scheduleViewportUpdate(viewport);
          }
          final items = widget.messages;
          if (items.length != _lastMessageCount) {
            _lastMessageCount = items.length;
            _scheduleScrollToBottom();
          }
          return IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration:
                    const BoxDecoration(color: Color(0x88000000)),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        item.text,
                        softWrap: true,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(
                              blurRadius: 6,
                              color: Color(0xAA000000),
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
