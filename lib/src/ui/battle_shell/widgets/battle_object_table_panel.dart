import 'package:flutter/material.dart';

import '../../facade/project_ui_facade.dart';

class BattleObjectTablePanel extends StatelessWidget {
  const BattleObjectTablePanel({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    final entities = facade.battle.workspace.entities;
    final selectedId = facade.battle.workspace.selectedEntityId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '当前战斗对象',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entities.isEmpty
                  ? const Center(child: Text('暂无参战对象'))
                  : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 4.0,
                      ),
                      itemCount: entities.length,
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        final selected = entity.id == selectedId;
                        return Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => facade.selectBattleEntity(entity.id),
                            onDoubleTap: () =>
                                facade.toggleBattleEntityActive(entity.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                               child: Row(
                                 children: [
                                   Expanded(
                                     child: Text(
                                       entity.displayName,
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis,
                                       style: const TextStyle(
                                         fontSize: 13,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                   ),
                                   Text(
                                     entity.currentHp == null
                                         ? '--'
                                         : 'HP ${entity.currentHp}',
                                     style: TextStyle(
                                       fontSize: 12,
                                       color: Theme.of(context)
                                           .colorScheme
                                           .outline,
                                     ),
                                   ),
                                 ],
                               ),
                            ),
                          ),
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
