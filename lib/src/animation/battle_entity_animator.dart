import 'package:flutter/material.dart';

import '../model/battle_model.dart';

class BattleEntityAnimator extends StatefulWidget {
  const BattleEntityAnimator({
    super.key,
    required this.entityId,
    required this.triggerId,
    required this.action,
    required this.kind,
    required this.child,
    this.containerWidth = 400,
  });

  final String entityId;
  final int triggerId;
  final BattleAnimAction? action;
  final BattleEntityKind kind;
  final Widget child;
  final double containerWidth;

  @override
  State<BattleEntityAnimator> createState() => _BattleEntityAnimatorState();
}

class _BattleEntityAnimatorState extends State<BattleEntityAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _lastTriggerId = 0;
  int _playedTriggerId = 0;
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _lastTriggerId = widget.triggerId;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.addStatusListener(_onAnimStatus);
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _going) {
      _going = false;
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant BattleEntityAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerId != _lastTriggerId && widget.action != null) {
      _lastTriggerId = widget.triggerId;
      _play(widget.action!);
    }
  }

  void _play(BattleAnimAction action) {
    if (_playedTriggerId == _lastTriggerId) return;
    _playedTriggerId = _lastTriggerId;

    switch (action) {
      case BattleAnimAction.attack:
        _controller.duration = const Duration(milliseconds: 200);
        break;
      case BattleAnimAction.dodge:
        _controller.duration = const Duration(milliseconds: 400);
        break;
      case BattleAnimAction.counter:
        _controller.duration = const Duration(milliseconds: 250);
        break;
    }
    _going = true;
    _controller.reset();
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.action == null || _lastTriggerId == 0) {
      return widget.child;
    }

    final isPlayer = widget.kind == BattleEntityKind.player;
    final side = isPlayer ? 1.0 : -1.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final status = _controller.status;
        if (status == AnimationStatus.dismissed ||
            status == AnimationStatus.completed) {
          return child!;
        }
        final t = _controller.value;
        final goingForward = _going;

        double offsetX = 0;
        double offsetY = 0;
        double scale = 1.0;
        double opacity = 1.0;
        double redFlash = 0.0;

        switch (widget.action!) {
          case BattleAnimAction.attack:
            final dx = widget.containerWidth * 0.3 * side;
            final dy = widget.containerWidth * 0.12 * (-side);
            if (goingForward) {
              final v = Curves.easeInQuad.transform(t);
              offsetX = dx * v;
              offsetY = dy * v;
              scale = 1.0 + 0.08 * v;
            } else {
              final v = Curves.easeOutBack.transform(t);
              offsetX = dx * v;
              offsetY = dy * v;
              scale = 1.0 + 0.08 * v;
            }
            break;
          case BattleAnimAction.dodge:
            final distance = widget.containerWidth * 0.15 * (-side);
            if (goingForward) {
              if (t <= 0.3) {
                offsetX = distance * Curves.easeOutSine.transform(t / 0.3);
              } else {
                offsetX = distance;
              }
            } else {
              offsetX = distance * Curves.easeInCubic.transform(t);
            }
            break;
          case BattleAnimAction.counter:
            final lunge = widget.containerWidth * 0.22 * side;
            if (goingForward) {
              final v = Curves.easeInCubic.transform(t);
              scale = 1.0 - 0.25 * v;
              offsetX = lunge * (-0.12) * v;
              redFlash = 0.0 + 0.45 * v;
            } else {
              final u = Curves.easeOutBack.transform(1.0 - t);
              scale = 1.0 - 0.25 * (1.0 - u);
              offsetX = lunge * (-0.12) * (1.0 - u);
              redFlash = 0.45 * (1.0 - Curves.easeOutCubic.transform(1.0 - t));
            }
            break;
        }

        Widget transformed = Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child!,
            ),
          ),
        );

        if (redFlash > 0.0) {
          transformed = ColorFiltered(
            colorFilter: ColorFilter.mode(
              Color.fromARGB(
                  (redFlash * 240).round().clamp(0, 255), 229, 57, 53),
              BlendMode.srcATop,
            ),
            child: transformed,
          );
        }

        return transformed;
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
