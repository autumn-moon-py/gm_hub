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
    return _SaveShortcutHandler(
      controller: controller,
      child: GetBuilder<ProjectController>(
        builder: (controller) {
          final currentMode = controller.store.project.currentMode;
          final body = currentMode == ProjectMode.battle
              ? const BattleShell()
              : const MainShell();
          return Scaffold(
            appBar: MainShellAppBar(controller: controller),
            body: body,
          );
        },
      ),
    );
  }
}

/// 用 HardwareKeyboard 全局监听 Ctrl+S，避免焦点不在 Shortcuts 子树时失效。
class _SaveShortcutHandler extends StatefulWidget {
  const _SaveShortcutHandler({
    required this.controller,
    required this.child,
  });

  final ProjectController controller;
  final Widget child;

  @override
  State<_SaveShortcutHandler> createState() => _SaveShortcutHandlerState();
}

class _SaveShortcutHandlerState extends State<_SaveShortcutHandler> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyS) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    unawaited(saveProjectWithFeedback(context, widget.controller));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
