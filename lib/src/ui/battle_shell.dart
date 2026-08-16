import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/project_controller.dart';
import '../model/battle_model.dart';
import 'battle_shell/battle_preparation_page.dart';
import 'battle_shell/battle_workspace_page.dart';
import 'facade/project_ui_facade.dart';

class BattleShell extends GetView<ProjectController> {
  const BattleShell({super.key});

  @override
  Widget build(BuildContext context) {
    final facade = BattleShellFacade(controller.store);
    return ListenableBuilder(
      listenable: facade.battleListenable,
      builder: (context, child) {
        final page = facade.battle.uiState.currentPage;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: switch (page) {
            BattlePage.workspace => BattleWorkspacePage(facade: facade),
            BattlePage.preparation => BattlePreparationPage(facade: facade),
          },
        );
      },
    );
  }
}
