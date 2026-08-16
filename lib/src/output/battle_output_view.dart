import 'dart:io';

import 'package:flutter/material.dart';

import '../model/battle_model.dart';
import '../model/project_model.dart';
import '../model/render_item.dart';
import '../animation/battle_entity_animator.dart';
import 'output_layout.dart';
import 'sync_render_payload.dart';

class BattleOutputView extends StatelessWidget {
  const BattleOutputView({
    super.key,
    required this.battle,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.outputScaleMode,
    required this.backgroundItems,
  });

  final SyncBattlePayload battle;
  final double canvasWidth;
  final double canvasHeight;
  final String outputScaleMode;
  final List<RenderItem> backgroundItems;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = computeOutputLayout(
          constraints: constraints,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          outputScaleMode: outputScaleMode,
        );

        final entities = battle.entities;
        final mainPlayer = _pickMainEntity(entities, BattleEntityKind.player);
        final mainNpc = _pickMainEntity(entities, BattleEntityKind.npc);
        final standbyPlayers =
            _cornerEntities(entities, BattleEntityKind.player);
        final standbyNpcs =
            _cornerEntities(entities, BattleEntityKind.npc);
        final currentActor = _findCurrentActor();

        final portraitSize = constraints.maxWidth * 0.16;
        final thumbSize = portraitSize * 0.30;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF141A24),
                      Color(0xFF0A0D14),
                    ],
                  ),
                ),
              ),
              ...backgroundItems
                  .where((item) =>
                      item.visible &&
                      item.type == NodeType.image &&
                      _hasAsset(item.assetAbsolutePath))
                  .map((item) => Positioned(
                        left: layout.offsetX +
                            item.worldPosition.dx * layout.renderScaleX,
                        top: layout.offsetY +
                            item.worldPosition.dy * layout.renderScaleY,
                        child: Transform.rotate(
                          angle: item.worldRotation,
                          child: Opacity(
                            opacity: item.opacity.clamp(0.0, 1.0),
                            child: Image.file(
                              File(item.assetAbsolutePath!),
                              width: item.baseWidth *
                                  item.worldScale *
                                  layout.renderScaleX,
                              height: item.baseHeight *
                                  item.worldScale *
                                  layout.renderScaleY,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      )),
              if (mainNpc != null)
                _EntitySlot(
                  entity: mainNpc,
                  size: portraitSize,
                  alignment: Alignment.centerLeft,
                  slotPosition: const Alignment(0.72, -0.62),
                  offset: const Offset(-100, 150),
                  animTriggerId: battle.animTriggerId,
                  animAction: battle.animActiveEntityId == mainNpc.id
                      ? battle.animActiveAction
                      : (battle.animTargetEntityId == mainNpc.id
                          ? battle.animTargetAction
                          : null),
                  containerWidth: constraints.maxWidth,
                ),
              if (mainPlayer != null)
                _EntitySlot(
                  entity: mainPlayer,
                  size: portraitSize,
                  alignment: Alignment.centerRight,
                  slotPosition: const Alignment(-0.72, 0.62),
                  offset: const Offset(200, 0),
                  animTriggerId: battle.animTriggerId,
                  animAction: battle.animActiveEntityId == mainPlayer.id
                      ? battle.animActiveAction
                      : (battle.animTargetEntityId == mainPlayer.id
                          ? battle.animTargetAction
                          : null),
                  containerWidth: constraints.maxWidth,
                ),
              if (standbyNpcs.isNotEmpty)
                _StandbyStrip(
                  entities: standbyNpcs,
                  alignment: Alignment.topRight,
                  direction: Axis.vertical,
                  thumbSize: thumbSize,
                ),
              if (standbyPlayers.isNotEmpty)
                _StandbyStrip(
                  entities: standbyPlayers,
                  alignment: Alignment.bottomLeft,
                  direction: Axis.vertical,
                  thumbSize: thumbSize,
                ),
              if (currentActor != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _CurrentActorLabel(name: currentActor.name),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  SyncBattleEntityView? _pickMainEntity(
      List<SyncBattleEntityView> entities, BattleEntityKind kind) {
    for (final entity in entities) {
      if (entity.kind == kind && entity.isForeground) {
        final state = entity.state;
        if (state != 'retired' && state != 'standby' && state != 'defeated') {
          return entity;
        }
      }
    }
    for (final entity in entities) {
      if (entity.kind == kind && entity.state == 'active') {
        return entity;
      }
    }
    return null;
  }

  List<SyncBattleEntityView> _cornerEntities(
      List<SyncBattleEntityView> entities, BattleEntityKind kind) {
    final isMain = _pickMainEntity(entities, kind);
    return entities
        .where((e) =>
            e.kind == kind &&
            (e.state == 'standby' || e.state == 'defeated') &&
            e.id != (isMain?.id ?? ''))
        .toList();
  }

  SyncBattleEntityView? _findCurrentActor() {
    for (final entity in battle.entities) {
      if (entity.isCurrentActor) {
        return entity;
      }
    }
    return null;
  }

  bool _hasAsset(String? path) {
    if (path == null || path.trim().isEmpty) {
      return false;
    }
    return File(path).existsSync();
  }
}

class _EntitySlot extends StatelessWidget {
  const _EntitySlot({
    required this.entity,
    required this.size,
    required this.alignment,
    required this.slotPosition,
    required this.offset,
    required this.animTriggerId,
    required this.animAction,
    required this.containerWidth,
  });

  final SyncBattleEntityView entity;
  final double size;
  final Alignment alignment;
  final Alignment slotPosition;
  final Offset offset;
  final int animTriggerId;
  final BattleAnimAction? animAction;
  final double containerWidth;

  @override
  Widget build(BuildContext context) {
    final hasAsset = (entity.assetAbsolutePath ?? '').trim().isNotEmpty;
    final portrait = SizedBox(
      width: size,
      height: size,
      child: hasAsset
          ? Image.file(
              File(entity.assetAbsolutePath!),
              fit: BoxFit.contain,
              alignment: alignment,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            )
          : const SizedBox.shrink(),
    );

    return Align(
      alignment: slotPosition,
      child: Transform.translate(
        offset: offset,
        child: BattleEntityAnimator(
          entityId: entity.id,
          triggerId: animTriggerId,
          action: animAction,
          kind: entity.kind,
          containerWidth: containerWidth,
          child: portrait,
        ),
      ),
    );
  }
}

class _StandbyStrip extends StatelessWidget {
  const _StandbyStrip({
    required this.entities,
    required this.alignment,
    required this.direction,
    required this.thumbSize,
  });

  final List<SyncBattleEntityView> entities;
  final Alignment alignment;
  final Axis direction;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entity in entities)
              Padding(
                padding: EdgeInsets.only(
                  top: direction == Axis.vertical ? 4 : 0,
                  left: direction == Axis.horizontal ? 4 : 0,
                ),
                child: _SmallPortrait(
                  entity: entity,
                  size: thumbSize,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallPortrait extends StatelessWidget {
  const _SmallPortrait({required this.entity, required this.size});

  final SyncBattleEntityView entity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasAsset = (entity.assetAbsolutePath ?? '').trim().isNotEmpty;
    final defeated = entity.state == 'defeated';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasAsset)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(
                File(entity.assetAbsolutePath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          if (defeated)
            CustomPaint(
              painter: _DefeatedThumbPainter(),
            ),
        ],
      ),
    );
  }
}

class _DefeatedThumbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xCCE53935)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CurrentActorLabel extends StatelessWidget {
  const _CurrentActorLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC0E1320),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x88F3C05E)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded,
                color: Color(0xFFFFE2A6), size: 22),
            const SizedBox(width: 8),
            Text(
              '当前行动: $name',
              style: const TextStyle(
                color: Color(0xFFFFE2A6),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
