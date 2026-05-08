import 'package:flutter/material.dart';

import '../../controller/project_controller.dart';
import 'main_shell_actions.dart';

class MainShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainShellAppBar({
    super.key,
    required this.controller,
  });

  final ProjectController controller;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: buildMainMenuButton(
        context: context,
        controller: controller,
      ),
      actions: buildMainShellActions(controller: controller),
    );
  }
}