import 'dart:io';

import 'package:flutter/material.dart';

import '../battle_preparation_page.dart';

class BattleResourceCardGrid extends StatelessWidget {
  const BattleResourceCardGrid({
    super.key,
    required this.section,
    required this.resources,
    required this.selectedResourceId,
    required this.onSelectResource,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
    required this.onSectionChanged,
  });

  final BattleResourceLibrarySection section;
  final List<BattleResourceLibraryItemViewModel> resources;
  final String? selectedResourceId;
  final ValueChanged<String> onSelectResource;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final ValueChanged<BattleResourceLibrarySection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BattleResourceToolbar(
            section: section,
            onSectionChanged: onSectionChanged,
            actionLabel: section == BattleResourceLibrarySection.npc
                ? '新建 NPC'
                : '引用玩家图层',
            onPressed: onPrimaryAction,
            secondaryActionLabel: section == BattleResourceLibrarySection.npc
                ? '引用NPC图层'
                : null,
            onSecondaryPressed: onSecondaryAction,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: resources.isEmpty
                ? _BattleResourceGridEmptyState(section: section)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                          (constraints.maxWidth / 110).floor().clamp(3, 10);
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.9,
                          ),
                        itemCount: resources.length,
                        itemBuilder: (context, index) {
                          final resource = resources[index];
                          return _BattleResourceCard(
                            name: resource.name,
                            assetPath: resource.portrait?.asset,
                            selected: resource.id == selectedResourceId,
                            onTap: () => onSelectResource(resource.id),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BattleResourceToolbar extends StatelessWidget {
  const _BattleResourceToolbar({
    required this.section,
    required this.onSectionChanged,
    required this.actionLabel,
    required this.onPressed,
    required this.secondaryActionLabel,
    required this.onSecondaryPressed,
  });

  final BattleResourceLibrarySection section;
  final ValueChanged<BattleResourceLibrarySection> onSectionChanged;
  final String actionLabel;
  final VoidCallback onPressed;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SegmentedButton<BattleResourceLibrarySection>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: BattleResourceLibrarySection.npc,
              label: SizedBox(
                width: 72,
                child: Text(
                  'NPC',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            ButtonSegment(
              value: BattleResourceLibrarySection.player,
              label: SizedBox(
                width: 72,
                child: Text(
                  '玩家',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          selected: {section},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            onSectionChanged(selection.first);
          },
        ),
        const Spacer(),
        if (secondaryActionLabel != null && onSecondaryPressed != null) ...[
          OutlinedButton(
            onPressed: onSecondaryPressed,
            child: Text(secondaryActionLabel!),
          ),
          const SizedBox(width: 8),
        ],
        FilledButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    );
  }
}

class _BattleResourceCard extends StatelessWidget {
  const _BattleResourceCard({
    required this.name,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String? assetPath;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: double.infinity,
                    color: colorScheme.surface,
                    child: _BattlePortraitPreview(assetPath: assetPath),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattlePortraitPreview extends StatelessWidget {
  const _BattlePortraitPreview({required this.assetPath});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final trimmedPath = assetPath?.trim() ?? '';
    if (trimmedPath.isEmpty) {
      return Center(
        child: Text('无立绘', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final file = File(trimmedPath);
    return Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '资源不可用',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _BattleResourceGridEmptyState extends StatelessWidget {
  const _BattleResourceGridEmptyState({required this.section});

  final BattleResourceLibrarySection section;

  @override
  Widget build(BuildContext context) {
    final message = section == BattleResourceLibrarySection.npc
        ? '当前还没有 NPC 模板，先用右上角按钮新建。'
        : '当前还没有玩家展示对象，先从当前场景引用。';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}
