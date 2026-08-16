import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controller/project_controller.dart';
import 'facade/project_ui_facade.dart';
import 'main_shell/stage_content.dart';
import 'widgets/bgm_panel.dart';
import 'widgets/dice_panel.dart';
import 'widgets/file_drop_wrapper.dart';
import 'widgets/right_sidebar_panel.dart';

class MainShell extends GetView<ProjectController> {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = controller.store;
    final ui = MainShellUiFacade(store);
    return FileDropWrapper(
      facade: ui.layerTree,
      child: _GlobalKeyboardHandler(
        onUndo: () {
          controller.undoLayerChange();
        },
        onDelete: () {
          controller.deleteSelected();
        },
        child: MainShellBody(ui: ui),
      ),
    );
  }
}

class _GlobalKeyboardHandler extends StatefulWidget {
  const _GlobalKeyboardHandler({
    required this.onUndo,
    required this.onDelete,
    required this.child,
  });

  final VoidCallback onUndo;
  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_GlobalKeyboardHandler> createState() => _GlobalKeyboardHandlerState();
}

class _GlobalKeyboardHandlerState extends State<_GlobalKeyboardHandler> {
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
    if (event is! KeyDownEvent) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete) {
      if (!_isEditableTextFocused()) {
        widget.onDelete();
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      final isControl = HardwareKeyboard.instance.isControlPressed;
      if (isControl && !_isEditableTextFocused()) {
        widget.onUndo();
        return true;
      }
    }
    return false;
  }

  bool _isEditableTextFocused() {
    final focusedChild = WidgetsBinding.instance.focusManager.primaryFocus;
    if (focusedChild == null) {
      return false;
    }
    final context = focusedChild.context;
    if (context == null) {
      return false;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MainShellBody extends StatelessWidget {
  const MainShellBody({super.key, required this.ui});

  final MainShellUiFacade ui;
  static const double _rightSidebarWidth = 340;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        ListenableBuilder(
                          listenable: ui.dice.diceListenable,
                          builder: (context, child) {
                            return DicePanel(facade: ui.dice);
                          },
                        ),
                        Expanded(child: StageContent(ui: ui)),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: ui.audio.audioListenable,
                    builder: (context, child) {
                      return BgmPanel(facade: ui.audio);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _rightSidebarWidth,
              child: RightSidebarPanel(facade: ui.layerTree),
            ),
          ],
        ),
        ListenableBuilder(
          listenable: ui.layerTree.globalLoadingListenable,
          builder: (context, child) {
            final loading = ui.layerTree.globalLoading;
            if (!loading) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: ColoredBox(
                color: const Color(0x55000000),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('资源处理中...'),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
