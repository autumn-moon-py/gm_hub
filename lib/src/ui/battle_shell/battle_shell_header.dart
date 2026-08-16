import 'package:flutter/material.dart';

import '../../model/battle_model.dart';
import '../facade/project_ui_facade.dart';

class BattleShellHeader extends StatelessWidget {
  const BattleShellHeader({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  Widget build(BuildContext context) {
    final page = facade.battle.uiState.currentPage;
    return SegmentedButton<BattlePage>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<BattlePage>(
          value: BattlePage.workspace,
          label: SizedBox(
            width: 120,
            child: Text(
              '当前战斗',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        ButtonSegment<BattlePage>(
          value: BattlePage.preparation,
          label: SizedBox(
            width: 140,
            child: Text(
              '战斗准备',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
      selected: <BattlePage>{page},
      onSelectionChanged: (next) {
        if (next.isEmpty) {
          return;
        }
        facade.setBattlePage(next.first);
      },
    );
  }
}
