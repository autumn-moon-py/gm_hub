import 'package:flutter/material.dart';

import '../../../model/battle_model.dart';
import '../../facade/project_ui_facade.dart';

class BattleTurnOrderPanel extends StatelessWidget {
  const BattleTurnOrderPanel({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    final workspace = facade.battle.workspace;
    final entitiesById = <String, BattleEntityModel>{
      for (final entity in workspace.entities) entity.id: entity,
    };
    final validTurnOrderIds = [
      for (final entity in workspace.entities) entity.id,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('行动顺序', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (validTurnOrderIds.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    '暂无行动顺序',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: true,
                  itemCount: validTurnOrderIds.length,
                  onReorder: (int oldIndex, int newIndex) {
                    facade.reorderBattleTurnOrder(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final entityId = validTurnOrderIds[index];
                    final entity = entitiesById[entityId]!;
                    final selected = entityId == workspace.selectedEntityId;
                    return ListTile(
                      key: ValueKey(entityId),
                      dense: true,
                      selected: selected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(entity.displayName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('第 ${index + 1} 位',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => facade.selectBattleEntity(entityId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
