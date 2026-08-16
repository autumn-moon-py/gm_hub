import 'package:flutter/material.dart';

import '../../controller/project_controller.dart';
import '../../model/battle_model.dart';
import '../../store/project_store.dart';
import '../facade/project_ui_facade.dart';

Widget buildMainMenuButton({
  required BuildContext context,
  required ProjectController controller,
}) {
  return PopupMenuButton<String>(
    tooltip: '菜单',
    onSelected: (value) async {
      if (value == 'new_project') {
        _showCreateProjectDialog(context, controller);
        return;
      }
      if (value == 'open_project') {
        await controller.openProjectDir();
        return;
      }
      if (value == 'save_project') {
        await saveProjectWithFeedback(context, controller);
        return;
      }
      if (value == 'save_as_project') {
        await saveProjectAsWithFeedback(context, controller);
        return;
      }
      if (value == 'clear_project') {
        await controller.clearProject();
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空，恢复为初始状态')));
      }
      if (value == 'convert_project') {
        await convertProjectWithFeedback(context, controller);
        return;
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: 'new_project',
        child: Text('新建项目'),
      ),
      PopupMenuItem(
        value: 'open_project',
        child: Text('打开项目'),
      ),
      PopupMenuItem(
        value: 'save_project',
        child: Text('保存'),
      ),
      PopupMenuItem(
        value: 'save_as_project',
        child: Text('另存为项目'),
      ),
      PopupMenuDivider(),
      PopupMenuItem(
        value: 'clear_project',
        child: Text('清空'),
      ),
      PopupMenuItem(
        value: 'convert_project',
        child: Text('转换为新版本格式'),
      ),
    ],
    icon: const Icon(Icons.menu),
  );
}

List<Widget> buildMainShellActions({
  required ProjectController controller,
  BattleShellFacade? battleFacade,
}) {
  final currentMode = controller.store.project.currentMode;
  final isBattleMode = currentMode == ProjectMode.battle;
  final showingBattle = isBattleMode &&
      (battleFacade?.battle.workspace.outputShowingBattle ?? false);
  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SegmentedButton<ProjectMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<ProjectMode>(
            value: ProjectMode.scene,
            label: Text('场景'),
          ),
          ButtonSegment<ProjectMode>(
            value: ProjectMode.battle,
            label: Text('战斗'),
          ),
        ],
        selected: <ProjectMode>{currentMode},
        onSelectionChanged: (selection) {
          final mode = selection.first;
          if (mode == ProjectMode.scene) {
            controller.switchToSceneMode();
            return;
          }
          controller.switchToBattleMode();
        },
      ),
    ),
    if (isBattleMode && battleFacade != null) ...[
      const SizedBox(width: 8),
      Text(
        '上屏',
        style: ThemeData.fallback().textTheme.bodyMedium,
      ),
      Transform.scale(
        scale: 0.82,
        child: Switch(
          value: showingBattle,
          onChanged: battleFacade.setBattleOutputShowing,
        ),
      ),
    ],
    TextButton(
      onPressed: controller.openOutputWindow,
      child: const Text('输出窗口'),
    ),
  ];
}

Future<void> saveProjectWithFeedback(
  BuildContext context,
  ProjectController controller,
) async {
  final ok = await controller.saveProject();
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? '保存成功' : '保存失败')),
  );
}

Future<void> saveProjectAsWithFeedback(
  BuildContext context,
  ProjectController controller,
) async {
  final ok = await controller.saveProjectAs();
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ok ? '另存为成功' : '另存为失败或已取消')),
  );
}

Future<void> convertProjectWithFeedback(
  BuildContext context,
  ProjectController controller,
) async {
  final outcome = await controller.convertToNewFormat(
    confirmMissing: (missing) async {
      if (!context.mounted) return false;
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('以下资源已丢失'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('迁移将跳过这些资源,继续吗?'),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          child: Text(
                            missing.join('\n'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('跳过并迁移'),
                ),
              ],
            ),
          ) ??
          false;
    },
  );
  if (!context.mounted) return;
  final msg = switch (outcome) {
    ConvertFormatOutcome.converted => '已转换为新版本,原文件备份为 .gmh.bak',
    ConvertFormatOutcome.alreadyNew => '当前已是新版本格式',
    ConvertFormatOutcome.aborted => '已取消',
    ConvertFormatOutcome.noFilePath => '项目尚未保存到文件',
    ConvertFormatOutcome.failed => '转换失败,已从备份恢复原文件',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

void _showCreateProjectDialog(
  BuildContext context,
  ProjectController controller,
) {
  final textController = TextEditingController(text: '主持中枢项目');
  showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('创建项目'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context, textController.text),
          decoration: const InputDecoration(hintText: '项目名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('创建'),
          ),
        ],
      );
    },
  ).then((name) {
    textController.dispose();
    if (name != null) {
      controller.createProject(name);
    }
  });
}
