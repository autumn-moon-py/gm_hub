import 'dart:io';

import 'package:flutter/material.dart';

import '../../../model/battle_model.dart';
import '../../../model/project_model.dart';
import '../../../animation/battle_entity_animator.dart';
import '../../../output/output_layout.dart';
import '../../../output/sync_render_payload.dart';
import '../../facade/project_ui_facade.dart';
import '../../widgets/flow_message_panel.dart';

class BattlePreviewPanelBody extends StatelessWidget {
  const BattlePreviewPanelBody({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final backgroundItems = facade.sceneBackgroundRenderList
            .where((item) =>
                item.visible &&
                item.type == NodeType.image &&
                (item.assetAbsolutePath?.isNotEmpty ?? false) &&
                File(item.assetAbsolutePath!).existsSync())
            .toList();

        final canvas = facade.project.canvas;
        final layout = computeOutputLayout(
          constraints: constraints,
          canvasWidth: canvas.width,
          canvasHeight: canvas.height,
          outputScaleMode: facade.outputScaleMode,
        );

        final battle = facade.previewBattlePayload;
        final entities = battle.entities;
        final mainPlayer = _pickMainEntity(entities, BattleEntityKind.player);
        final mainNpc = _pickMainEntity(entities, BattleEntityKind.npc);
        final standbyPlayers =
            _cornerEntities(entities, BattleEntityKind.player);
        final standbyNpcs =
            _cornerEntities(entities, BattleEntityKind.npc);
        final currentActor = _findCurrentActor(battle);

        final portraitSize = constraints.maxWidth * 0.16;
        final thumbSize = portraitSize * 0.30;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: Container(color: const Color(0xFF182028)),
              ),
              for (final item in backgroundItems)
                Positioned(
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
                ),
              if (mainNpc != null)
                _MiniEntitySlot(
                  entity: mainNpc,
                  size: portraitSize,
                  alignment: Alignment.centerLeft,
                  slotPosition: const Alignment(0.72, -0.62),
                  offset: const Offset(-100, 150),
                  onTap: () => facade.selectBattleEntity(mainNpc.id),
                  onDoubleTap: () => facade.toggleBattleEntityActive(mainNpc.id),
                  animTriggerId: battle.animTriggerId,
                  animAction: battle.animActiveEntityId == mainNpc.id
                      ? battle.animActiveAction
                      : (battle.animTargetEntityId == mainNpc.id
                          ? battle.animTargetAction
                          : null),
                  containerWidth: constraints.maxWidth,
                ),
              if (mainPlayer != null)
                _MiniEntitySlot(
                  entity: mainPlayer,
                  size: portraitSize,
                  alignment: Alignment.centerRight,
                  slotPosition: const Alignment(-0.72, 0.62),
                  offset: const Offset(200, 0),
                  onTap: () => facade.selectBattleEntity(mainPlayer.id),
                  onDoubleTap: () => facade.toggleBattleEntityActive(mainPlayer.id),
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
                  thumbSize: thumbSize,
                  onTap: (id) => facade.selectBattleEntity(id),
                  onDoubleTap: (id) => facade.toggleBattleEntityActive(id),
                ),
              if (standbyPlayers.isNotEmpty)
                _StandbyStrip(
                  entities: standbyPlayers,
                  alignment: Alignment.bottomLeft,
                  thumbSize: thumbSize,
                  onTap: (id) => facade.selectBattleEntity(id),
                  onDoubleTap: (id) => facade.toggleBattleEntityActive(id),
                ),
              if (currentActor != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC0E1320),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0x88F3C05E)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Text(
                          '褰撳墠: ${currentActor.name}',
                          style: const TextStyle(
                            color: Color(0xFFFFE2A6),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ListenableBuilder(
                listenable: facade.stageListenable,
                builder: (context, _) {
                  final messages = facade.flowMessages;
                  if (messages.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    right: 6,
                    bottom: 6,
                    child: FlowMessagePanel(
                      messages: messages,
                      width: 280,
                      height: 130,
                      onViewportChanged: (size) {
                        facade.setFlowViewport(
                            width: size.width, height: size.height);
                      },
                    ),
                  );
                },
              ),
              if (backgroundItems.isEmpty &&
                  mainPlayer == null &&
                  mainNpc == null &&
                  standbyPlayers.isEmpty &&
                  standbyNpcs.isEmpty)
                const Center(
                  child: Text(
                    '鎴樻枟棰勮',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 16,
                    ),
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

  SyncBattleEntityView? _findCurrentActor(SyncBattlePayload battle) {
    for (final entity in battle.entities) {
      if (entity.isCurrentActor) {
        return entity;
      }
    }
    return null;
  }
}

class _MiniEntitySlot extends StatelessWidget {
  const _MiniEntitySlot({
    required this.entity,
    required this.size,
    required this.alignment,
    required this.slotPosition,
    required this.offset,
    required this.onTap,
    required this.onDoubleTap,
    required this.animTriggerId,
    required this.animAction,
    required this.containerWidth,
  });

  final SyncBattleEntityView entity;
  final double size;
  final Alignment alignment;
  final Alignment slotPosition;
  final Offset offset;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
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
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: BattleEntityAnimator(
            entityId: entity.id,
            triggerId: animTriggerId,
            action: animAction,
            kind: entity.kind,
            containerWidth: containerWidth,
            child: portrait,
          ),
        ),
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

class _StandbyStrip extends StatelessWidget {
  const _StandbyStrip({
    required this.entities,
    required this.alignment,
    required this.thumbSize,
    required this.onTap,
    required this.onDoubleTap,
  });

  final List<SyncBattleEntityView> entities;
  final Alignment alignment;
  final double thumbSize;
  final void Function(String id) onTap;
  final void Function(String id) onDoubleTap;

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
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => onTap(entity.id),
                  onDoubleTap: () => onDoubleTap(entity.id),
                  child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if ((entity.assetAbsolutePath ?? '').trim().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.file(
                            File(entity.assetAbsolutePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      if (entity.state == 'defeated')
                        CustomPaint(
                          painter: _DefeatedThumbPainter(),
                        ),
                    ],
                  ),
                ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
