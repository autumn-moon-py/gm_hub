import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controller/project_controller.dart';
import '../model/battle_model.dart';
import 'battle_shell.dart';
import 'main_shell.dart';
import 'main_shell/main_shell_actions.dart';
import 'main_shell/main_shell_app_bar.dart';

class ProjectHostShell extends GetView<ProjectController> {
  const ProjectHostShell({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProjectController>(
      builder: (controller) {
        final currentMode = controller.store.project.currentMode;
        final body = currentMode == ProjectMode.battle
            ? const BattleShell()
            : const MainShell();
        return Scaffold(
          appBar: MainShellAppBar(controller: controller),
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  () {
                unawaited(
                    saveProjectWithFeedback(context, controller));
              },
            },
            child: Focus(
              autofocus: true,
              child: body,
            ),
          ),
        );
      },
    );
  }
}
