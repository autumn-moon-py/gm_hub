import 'package:flutter/material.dart';

import '../../controller/project_controller.dart';

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
    ],
    icon: const Icon(Icons.menu),
  );
}

List<Widget> buildMainShellActions({
  required ProjectController controller,
}) {
  return [
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
