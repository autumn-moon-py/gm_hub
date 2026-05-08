import 'package:flutter/material.dart';

import '../facade/project_ui_facade.dart';

class FlowMessagePanel extends StatefulWidget {
  final StageEditorFacade facade;
  final double width;
  final double height;

  const FlowMessagePanel({
    super.key,
    required this.facade,
    this.width = 280,
    this.height = 130,
  });

  @override
  State<FlowMessagePanel> createState() => _FlowMessagePanelState();
}

class _FlowMessagePanelState extends State<FlowMessagePanel> {
  Size? _lastViewport;
  bool _viewportUpdateScheduled = false;
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  void _scheduleViewportUpdate(Size viewport) {
    if (_viewportUpdateScheduled) {
      return;
    }
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (!mounted) {
        return;
      }
      widget.facade.setFlowViewport(
        width: viewport.width,
        height: viewport.height,
      );
    });
  }

  bool _viewportChanged(Size next) {
    final current = _lastViewport;
    if (current == null) {
      return true;
    }
    return (current.width - next.width).abs() > 0.5 ||
        (current.height - next.height).abs() > 0.5;
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
          final items = widget.facade.flowMessages;
          if (items.length != _lastMessageCount) {
            _lastMessageCount = items.length;
            _scheduleScrollToBottom();
          }
          return IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0x88000000)),
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
