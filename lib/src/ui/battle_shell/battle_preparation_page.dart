import 'package:flutter/material.dart';

import '../../model/battle_model.dart';
import '../facade/project_ui_facade.dart';
import 'widgets/battle_resource_card_grid.dart';
import 'widgets/battle_resource_detail_panel.dart';

enum BattleResourceLibrarySection { npc, player }

class BattlePreparationPage extends StatefulWidget {
  const BattlePreparationPage({super.key, required this.facade});

  final BattleShellFacade facade;

  @override
  State<BattlePreparationPage> createState() => _BattlePreparationPageState();
}

class _BattlePreparationPageState extends State<BattlePreparationPage> {
  BattleResourceLibrarySection _section = BattleResourceLibrarySection.npc;
  String? _selectedResourceId;

  @override
  void initState() {
    super.initState();
    widget.facade.battleListenable.addListener(_onBattleChanged);
  }

  @override
  void dispose() {
    widget.facade.battleListenable.removeListener(_onBattleChanged);
    super.dispose();
  }

  void _onBattleChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final resources = _resolveResources();
    final resolvedSelection =
        _findResourceById(_selectedResourceId, resources);

    final rosterEntries = widget.facade.defaultRosterResolvedEntries;
    final hasMissingRosterEntries =
        widget.facade.defaultRosterHasMissingResources;
    final canMaterializeCurrentBattle =
        rosterEntries.isNotEmpty && !hasMissingRosterEntries;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: _DefaultRosterPanel(
            facade: widget.facade,
            entries: rosterEntries,
            hasMissingResources: hasMissingRosterEntries,
            canMaterializeCurrentBattle: canMaterializeCurrentBattle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: BattleResourceCardGrid(
                  section: _section,
                  resources: resources,
                  selectedResourceId: resolvedSelection?.id,
                  onSelectResource: _handleSelectResource,
                  onPrimaryAction: _handlePrimaryAction,
                  onSecondaryAction:
                      _section == BattleResourceLibrarySection.npc
                          ? _handleNpcSceneImport
                          : null,
                  onSectionChanged: _handleSectionChanged,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: BattleResourceDetailPanel(
                  facade: widget.facade,
                  section: _section,
                  selectedResource: resolvedSelection,
                  onDeleteCompleted: _handleDeleteCompleted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<BattleResourceLibraryItemViewModel> _resolveResources() {
    switch (_section) {
      case BattleResourceLibrarySection.npc:
        return widget.facade.npcTemplates
            .map(
              (template) =>
                  BattleResourceLibraryItemViewModel.npc(template: template),
            )
            .toList(growable: false);
      case BattleResourceLibrarySection.player:
        return widget.facade.playerResources
            .map(
              (resource) =>
                  BattleResourceLibraryItemViewModel.player(resource: resource),
            )
            .toList(growable: false);
    }
  }

  BattleResourceLibraryItemViewModel? _findResourceById(
    String? id,
    List<BattleResourceLibraryItemViewModel> resources,
  ) {
    if (id == null || resources.isEmpty) {
      return null;
    }
    for (final resource in resources) {
      if (resource.id == id) {
        return resource;
      }
    }
    return null;
  }

  void _handleSectionChanged(BattleResourceLibrarySection section) {
    if (_section == section) {
      return;
    }
    setState(() {
      _section = section;
      _selectedResourceId = null;
    });
  }

  void _handleSelectResource(String resourceId) {
    if (_selectedResourceId == resourceId) {
      return;
    }
    setState(() {
      _selectedResourceId = resourceId;
    });
  }

  void _handleDeleteCompleted() {
    setState(() {
      _selectedResourceId = null;
    });
  }

  Future<void> _handlePrimaryAction() async {
    switch (_section) {
      case BattleResourceLibrarySection.npc:
        widget.facade.createNpcTemplate();
        final templates = widget.facade.npcTemplates;
        if (templates.isEmpty) {
          return;
        }
        setState(() {
          _selectedResourceId = templates.last.id;
        });
        return;
      case BattleResourceLibrarySection.player:
        final candidates = widget.facade.currentSceneImageCandidates;
        if (candidates.isEmpty) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前场景没有可直接引用的玩家图层。')),
          );
          return;
        }
        final selectedNodeIds = candidates
            .map((candidate) => candidate.nodeId)
            .toList(growable: false);
        final beforeIds = widget.facade.playerResources
            .map((resource) => resource.id)
            .toSet();
        widget.facade.importPlayerResourcesFromSceneNodeIds(selectedNodeIds);
        for (final resource in widget.facade.playerResources) {
          if (!beforeIds.contains(resource.id)) {
            setState(() {
              _selectedResourceId = resource.id;
            });
            return;
          }
        }
        return;
    }
  }

  void _handleNpcSceneImport() {
    final candidates = widget.facade.currentSceneNpcImageCandidates;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前场景没有可直接引用的 NPC 图层。')),
      );
      return;
    }
    final beforeIds =
        widget.facade.npcTemplates.map((template) => template.id).toSet();
    widget.facade.importNpcTemplatesFromSceneNodeIds(
      candidates.map((candidate) => candidate.nodeId).toList(growable: false),
    );
    for (final template in widget.facade.npcTemplates) {
      if (!beforeIds.contains(template.id)) {
        setState(() {
          _selectedResourceId = template.id;
        });
        return;
      }
    }
  }
}

class _DefaultRosterPanel extends StatelessWidget {
  const _DefaultRosterPanel({
    required this.facade,
    required this.entries,
    required this.hasMissingResources,
    required this.canMaterializeCurrentBattle,
  });

  final BattleShellFacade facade;
  final List<BattleRosterResolvedEntryViewModel> entries;
  final bool hasMissingResources;
  final bool canMaterializeCurrentBattle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '默认战斗编成',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canMaterializeCurrentBattle
                  ? facade.materializeCurrentBattleFromDefaultRoster
                  : null,
              icon: const Icon(Icons.refresh),
              label: const Text('重建当前战斗'),
            ),
          ],
        ),
        if (hasMissingResources) ...[
          const SizedBox(height: 8),
          _RosterWarningBanner(message: '存在资源缺失，修正后才能重建当前战斗。'),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(child: Text('当前默认编成为空。'))
                        : ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final titleColor = entry.missing
                                  ? Theme.of(context).colorScheme.error
                                  : null;
                              return ListTile(
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                leading: SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                title: Text(
                                  entry.displayName,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  entry.subtitle,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: '上移',
                                      onPressed: entry.canMoveUp
                                          ? () => facade.moveDefaultRosterEntry(
                                                entry.index,
                                                -1,
                                              )
                                          : null,
                                      icon: Icon(Icons.arrow_upward, size: 16),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: '下移',
                                      onPressed: entry.canMoveDown
                                          ? () => facade.moveDefaultRosterEntry(
                                                entry.index,
                                                1,
                                              )
                                          : null,
                                      icon: Icon(Icons.arrow_downward, size: 16),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: '移除',
                                      onPressed: () =>
                                          facade.removeDefaultRosterEntryAt(
                                            entry.index,
                                          ),
                                      icon:
                                          Icon(Icons.delete_outline, size: 16),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RosterWarningBanner extends StatelessWidget {
  const _RosterWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BattleResourceLibraryItemViewModel {
  const BattleResourceLibraryItemViewModel({
    required this.id,
    required this.name,
    required this.portrait,
    required this.kind,
    this.npcTemplate,
    this.playerResource,
  });

  factory BattleResourceLibraryItemViewModel.npc({
    required NpcTemplateModel template,
  }) {
    return BattleResourceLibraryItemViewModel(
      id: template.id,
      name: template.name,
      portrait: template.portrait,
      kind: BattleEntityKind.npc,
      npcTemplate: template,
    );
  }

  factory BattleResourceLibraryItemViewModel.player({
    required PlayerResourceModel resource,
  }) {
    return BattleResourceLibraryItemViewModel(
      id: resource.id,
      name: resource.name,
      portrait: resource.portrait,
      kind: BattleEntityKind.player,
      playerResource: resource,
    );
  }

  final String id;
  final String name;
  final BattleResourcePortraitBinding? portrait;
  final BattleEntityKind kind;
  final NpcTemplateModel? npcTemplate;
  final PlayerResourceModel? playerResource;
}
