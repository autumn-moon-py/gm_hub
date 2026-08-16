import 'package:flutter/material.dart';

import '../../model/battle_model.dart';
import '../facade/project_ui_facade.dart';
import 'widgets/battle_inspector_panel.dart';
import 'widgets/battle_object_table_panel.dart';
import 'widgets/battle_preview_panel.dart';

class BattleWorkspacePage extends StatelessWidget {
  const BattleWorkspacePage({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BattlePreviewPanelBody(facade: facade),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BattleActionButtons(facade: facade),
                    const SizedBox(height: 8),
                    Expanded(
                      child: BattleInspectorPanel(facade: facade),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: BattleObjectTablePanel(facade: facade),
        ),
      ],
    );
  }
}

class _BattleActionButtons extends StatelessWidget {
  const _BattleActionButtons({required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    final canMaterializeCurrentBattle =
        facade.battle.defaultRoster.isNotEmpty &&
        !facade.defaultRosterHasMissingResources;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('编成与增援', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: canMaterializeCurrentBattle
                  ? facade.materializeCurrentBattleFromDefaultRoster
                  : null,
              child: const Text('按默认编成重建当前战斗'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: facade.clearCurrentBattleWorkspace,
              child: const Text('清空当前战斗'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () => _showReinforcementDialog(context),
              child: const Text('战中临时增援'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReinforcementDialog(BuildContext context) {
    final npcTemplates = facade.npcTemplates;
    final playerResources = facade.playerResources;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('战中临时增援'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: npcTemplates.isEmpty && playerResources.isEmpty
                ? const Center(child: Text('资源库为空，请先在战斗准备页添加角色。'))
                : ListView(
                    children: [
                      ...npcTemplates.map(
                        (template) => ListTile(
                          dense: true,
                          title: Text(template.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text('ID: ${template.id}',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            facade.addEntityToBattle(
                                template.id, BattleEntityKind.npc);
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                      ...playerResources.map(
                        (resource) => ListTile(
                          dense: true,
                          title: Text(resource.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text('ID: ${resource.id}',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            facade.addEntityToBattle(
                                resource.id, BattleEntityKind.player);
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}
