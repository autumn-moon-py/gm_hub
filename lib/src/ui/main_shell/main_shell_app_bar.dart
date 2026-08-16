import 'package:flutter/material.dart';

import '../../controller/project_controller.dart';
import '../../model/battle_model.dart';
import '../battle_shell/battle_shell_header.dart';
import '../facade/project_ui_facade.dart';
import 'main_shell_actions.dart';

class MainShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainShellAppBar({super.key, required this.controller});

  final ProjectController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final battleFacade = BattleShellFacade(controller.store);
    final currentMode = controller.store.project.currentMode;
    final actions = buildMainShellActions(
      controller: controller,
      battleFacade: battleFacade,
    );
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final backgroundColor =
        appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final foregroundColor =
        appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      elevation: 0,
      shadowColor: appBarTheme.shadowColor,
      surfaceTintColor: appBarTheme.surfaceTintColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: IconTheme.merge(
            data: IconThemeData(color: foregroundColor),
            child: DefaultTextStyle(
              style:
                  theme.textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                  ) ??
                  TextStyle(color: foregroundColor),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: buildMainMenuButton(
                      context: context,
                      controller: controller,
                    ),
                  ),
                  if (currentMode == ProjectMode.battle)
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 50),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: BattleShellHeader(facade: battleFacade),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
