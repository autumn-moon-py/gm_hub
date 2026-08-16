import 'package:flutter/material.dart';

import '../../../model/battle_model.dart';
import '../../facade/project_ui_facade.dart';
import '../../widgets/dice_panel.dart';

class BattleInspectorPanel extends StatelessWidget {
  const BattleInspectorPanel({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    final entity = facade.selectedBattleEntity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: Text('战斗辅助面板', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entity == null
                  ? const _BattleInspectorEmptyState()
                  : _BattleInspectorDetailView(facade: facade, entity: entity),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleInspectorEmptyState extends StatelessWidget {
  const _BattleInspectorEmptyState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '请选择一个对象',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '从下方对象表选中对象即可查看详情。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BattleInspectorDetailView extends StatefulWidget {
  const _BattleInspectorDetailView(
      {required this.facade, required this.entity});

  final BattleShellFacade facade;
  final BattleEntityModel entity;

  @override
  State<_BattleInspectorDetailView> createState() =>
      _BattleInspectorDetailViewState();
}

class _BattleInspectorDetailViewState
    extends State<_BattleInspectorDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.facade.ensureAnimEntities();
    });
  }

  @override
  void didUpdateWidget(covariant _BattleInspectorDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entity.id != oldWidget.entity.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.facade.rebindAnimEntities(widget.entity.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final sections = entity.kind == BattleEntityKind.npc
        ? _buildNpcSections(context)
        : _buildPlayerSections(context);
    return ListView.separated(
      itemCount: sections.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => sections[index],
    );
  }

  List<Widget> _buildNpcSections(BuildContext context) {
    final entity = widget.entity;
    final template = widget.facade.resolveNpcTemplate(entity.resourceId);
    return [
      _BattleInspectorSection(
        title: '基础信息',
        backgroundColor: const Color(0xFFF5F9FC),
        borderColor: const Color(0xFFCEDAE3),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: '从战斗中移除',
          onPressed: () => widget.facade.removeBattleEntity(entity.id),
        ),
        child: _BattleEntityBasicInfo(
            entity: entity, npcTemplate: template, facade: widget.facade),
      ),
      DicePanel(
        facade: widget.facade.diceFacade,
        margin: EdgeInsets.zero,
        mode: DicePanelMode.battle,
        fateDefaultBonus: template?.keyBonus ?? 0,
      ),
    ];
  }

  List<Widget> _buildPlayerSections(BuildContext context) {
    final entity = widget.entity;
    final resource = widget.facade.resolvePlayerResource(entity.resourceId);
    return [
      _BattleInspectorSection(
        title: '基础信息',
        backgroundColor: const Color(0xFFF5F9FC),
        borderColor: const Color(0xFFCEDAE3),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: '从战斗中移除',
          onPressed: () => widget.facade.removeBattleEntity(entity.id),
        ),
        child: _BattleEntityBasicInfo(
            entity: entity, playerResource: resource, facade: widget.facade),
      ),
    ];
  }
}

class _BattleInspectorSection extends StatelessWidget {
  const _BattleInspectorSection({
    required this.title,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _BattleEntityBasicInfo extends StatelessWidget {
  const _BattleEntityBasicInfo({
    required this.entity,
    required this.facade,
    this.npcTemplate,
    this.playerResource,
  });

  final BattleEntityModel entity;
  final BattleShellFacade facade;
  final NpcTemplateModel? npcTemplate;
  final PlayerResourceModel? playerResource;

  @override
  Widget build(BuildContext context) {
    final maxHp = entity.kind == BattleEntityKind.npc
        ? (npcTemplate?.maxHp ?? 0)
        : null;
    final currentHp = entity.currentHp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                entity.displayName,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entity.kind == BattleEntityKind.npc) ...[
              Text(
                currentHp != null && npcTemplate != null
                    ? 'HP $currentHp / ${npcTemplate!.maxHp}'
                    : 'HP --',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              _QuickHpButton(label: '-1', delta: -1, entity: entity, facade: facade, maxHp: maxHp ?? 0),
              _QuickHpButton(label: '+1', delta: 1, entity: entity, facade: facade, maxHp: maxHp!),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<BattleEntityState>(
                  value: entity.state,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(value: BattleEntityState.standby, child: Text('待命')),
                    DropdownMenuItem(value: BattleEntityState.active, child: Text('激活')),
                    DropdownMenuItem(value: BattleEntityState.retired, child: Text('退场')),
                    DropdownMenuItem(value: BattleEntityState.defeated, child: Text('失能')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      facade.updateBattleEntity(entityId: entity.id, state: value);
                    }
                  },
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<BattleEntityState>(
                  value: entity.state,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  items: const [
                    DropdownMenuItem(value: BattleEntityState.standby, child: Text('待命')),
                    DropdownMenuItem(value: BattleEntityState.active, child: Text('激活')),
                    DropdownMenuItem(value: BattleEntityState.retired, child: Text('退场')),
                    DropdownMenuItem(value: BattleEntityState.defeated, child: Text('失能')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      facade.updateBattleEntity(entityId: entity.id, state: value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        if (npcTemplate != null && npcTemplate!.traitText.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            npcTemplate!.traitText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        _BattleAnimInlineControl(facade: facade, currentEntity: entity),
        const SizedBox(height: 6),
        _BattleEntityNoteField(entity: entity, facade: facade),
      ],
    );
  }
}

class _QuickHpButton extends StatelessWidget {
  const _QuickHpButton({
    required this.label,
    required this.delta,
    required this.entity,
    required this.facade,
    required this.maxHp,
  });

  final String label;
  final int delta;
  final BattleEntityModel entity;
  final BattleShellFacade facade;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final currentHp = entity.currentHp ?? 0;
    final newHp = (currentHp + delta).clamp(0, maxHp);
    return OutlinedButton(
      onPressed: newHp != currentHp
          ? () => facade.updateBattleEntity(
              entityId: entity.id, currentHp: newHp)
          : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _BattleEntityNoteField extends StatefulWidget {
  const _BattleEntityNoteField({
    required this.entity,
    required this.facade,
  });

  final BattleEntityModel entity;
  final BattleShellFacade facade;

  @override
  State<_BattleEntityNoteField> createState() =>
      _BattleEntityNoteFieldState();
}

class _BattleEntityNoteFieldState extends State<_BattleEntityNoteField> {
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entity.note);
  }

  @override
  void didUpdateWidget(covariant _BattleEntityNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entity.id != oldWidget.entity.id) {
      _controller!.text = widget.entity.note;
    }
  }

  @override
  void dispose() {
      _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 3,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: '战斗备注',
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: (value) {
        widget.facade.updateBattleEntity(
            entityId: widget.entity.id, note: value);
      },
    );
  }
}

class _BattleAnimInlineControl extends StatelessWidget {
  const _BattleAnimInlineControl({
    required this.facade,
    required this.currentEntity,
  });

  final BattleShellFacade facade;
  final BattleEntityModel currentEntity;

  @override
  Widget build(BuildContext context) {
    final anim = facade.battleAnimation;
    final entities = facade.battle.workspace.entities;

    final opponentKind = currentEntity.kind == BattleEntityKind.npc
        ? BattleEntityKind.player
        : BattleEntityKind.npc;
    final opponent = entities.cast<BattleEntityModel?>().firstWhere(
      (e) => e!.kind == opponentKind && e.state == BattleEntityState.active,
      orElse: () => entities.cast<BattleEntityModel?>().firstWhere(
        (e) => e!.kind == opponentKind,
        orElse: () => null,
      ),
    );

    final canExecute = anim.activeAction != null &&
        anim.targetAction != null;

    return Row(
      children: [
        Expanded(
          child: _ActionDropdown(
            label: '主动',
            value: anim.activeAction,
            items: BattleAnimAction.values,
            itemLabel: _animLabel,
            onChanged: (action) {
              facade.setAnimAction(
                activeEntityId: currentEntity.id,
                targetEntityId: opponent?.id ?? '',
                activeAction: action,
                targetAction: anim.targetAction ?? BattleAnimAction.attack,
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ActionDropdown(
            label: '反应',
            value: anim.targetAction,
            items: BattleAnimAction.values,
            itemLabel: _animLabel,
            onChanged: (action) {
              facade.setAnimAction(
                activeEntityId: currentEntity.id,
                targetEntityId: opponent?.id ?? '',
                activeAction: anim.activeAction ?? BattleAnimAction.attack,
                targetAction: action,
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        FilledButton.tonal(
          onPressed: canExecute ? facade.triggerAnimation : null,
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: const Text('执行', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

String _animLabel(BattleAnimAction action) {
  switch (action) {
    case BattleAnimAction.attack:
      return '攻击';
    case BattleAnimAction.dodge:
      return '闪避';
    case BattleAnimAction.counter:
      return '命中';
  }
}

class _ActionDropdown extends StatelessWidget {
  const _ActionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final BattleAnimAction? value;
  final List<BattleAnimAction> items;
  final String Function(BattleAnimAction) itemLabel;
  final ValueChanged<BattleAnimAction> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BattleAnimAction>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: items.map((action) {
            return DropdownMenuItem(
              value: action,
              child: Text(itemLabel(action), style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
