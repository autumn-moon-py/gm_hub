import 'package:flutter/material.dart';

import '../../../model/battle_model.dart';
import '../../facade/project_ui_facade.dart';
import '../battle_preparation_page.dart';

class BattleResourceDetailPanel extends StatefulWidget {
  const BattleResourceDetailPanel({
    super.key,
    required this.facade,
    required this.section,
    required this.selectedResource,
    required this.onDeleteCompleted,
  });

  final BattleShellFacade facade;
  final BattleResourceLibrarySection section;
  final BattleResourceLibraryItemViewModel? selectedResource;
  final VoidCallback onDeleteCompleted;

  @override
  State<BattleResourceDetailPanel> createState() =>
      _BattleResourceDetailPanelState();
}

class _BattleResourceDetailPanelState extends State<BattleResourceDetailPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _traitTextController;
  late final TextEditingController _maxHpController;
  late final TextEditingController _keyBonusController;

  String? _lastSyncedResourceId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _traitTextController = TextEditingController();
    _maxHpController = TextEditingController();
    _keyBonusController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant BattleResourceDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.selectedResource?.id;
    final oldId = oldWidget.selectedResource?.id;
    if (newId != oldId || _lastSyncedResourceId != newId) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _traitTextController.dispose();
    _maxHpController.dispose();
    _keyBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedResource = widget.selectedResource;
    final isPlayerResource = selectedResource?.kind == BattleEntityKind.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: selectedResource == null
            ? const _BattleResourceDetailEmptyState()
            : ListView(
                children: [
                  Row(
                    children: [
                      Text(
                        selectedResource.kind == BattleEntityKind.npc
                            ? 'NPC详情'
                            : '玩家详情',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        selectedResource.id,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _handleAddToRoster,
                        child: const Text('加入'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _handleDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isPlayerResource) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '名称',
                            ),
                            onChanged: _handleNameChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _traitTextController,
                            minLines: 1,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: '特性',
                              alignLabelWithHint: true,
                            ),
                            onChanged: _handleTraitTextChanged,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxHpController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'HP',
                            ),
                            onChanged: _handleMaxHpChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _keyBonusController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '加值',
                            ),
                            onChanged: _handleKeyBonusChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _BattleNpcPortraitBindingSection(
                            assetPath: selectedResource.portrait?.asset,
                            assetMissing: widget.facade
                                .isNpcTemplatePortraitMissing(
                                  selectedResource.id,
                                ),
                            onRelink: _handleRelinkNpcPortrait,
                            onBind: _handleBindNpcPortrait,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: '名称'),
                            onChanged: _handleNameChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BattlePlayerPortraitBindingSection(
                            assetPath: selectedResource.portrait?.asset,
                            assetMissing: widget.facade
                                .isBattleResourceAssetMissing(
                                  selectedResource.portrait?.asset,
                                ),
                            onRelink: _handleRelinkPlayerPortrait,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
      ),
    );
  }

  void _syncControllers() {
    final selectedResource = widget.selectedResource;
    if (selectedResource == null) {
      _lastSyncedResourceId = null;
      _nameController.text = '';
      _traitTextController.text = '';
      _maxHpController.text = '';
      _keyBonusController.text = '';
      return;
    }
    _lastSyncedResourceId = selectedResource.id;
    _nameController.text = selectedResource.name;
    _traitTextController.text = selectedResource.npcTemplate?.traitText ?? '';
    _maxHpController.text =
        selectedResource.npcTemplate?.maxHp.toString() ?? '';
    _keyBonusController.text =
        selectedResource.npcTemplate?.keyBonus.toString() ?? '';
  }

  void _handleNameChanged(String value) {
    final selectedResource = widget.selectedResource;
    if (selectedResource == null) {
      return;
    }
    if (selectedResource.kind == BattleEntityKind.npc) {
      widget.facade.updateNpcTemplate(
        templateId: selectedResource.id,
        name: value,
      );
      return;
    }
    widget.facade
        .updatePlayerResource(resourceId: selectedResource.id, name: value);
  }

  void _handleTraitTextChanged(String value) {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.npc) {
      return;
    }
    widget.facade.updateNpcTemplate(
      templateId: selectedResource!.id,
      traitText: value,
    );
  }

  void _handleMaxHpChanged(String value) {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.npc) {
      return;
    }
    final parsedValue = int.tryParse(value.trim());
    if (parsedValue == null) {
      _maxHpController.text =
          selectedResource!.npcTemplate?.maxHp.toString() ?? '';
      _maxHpController.selection = TextSelection.collapsed(
        offset: _maxHpController.text.length,
      );
      return;
    }
    widget.facade.updateNpcTemplate(
      templateId: selectedResource!.id,
      maxHp: parsedValue,
    );
  }

  void _handleKeyBonusChanged(String value) {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.npc) {
      return;
    }
    final parsedValue = int.tryParse(value.trim());
    if (parsedValue == null) {
      _keyBonusController.text =
          selectedResource!.npcTemplate?.keyBonus.toString() ?? '';
      _keyBonusController.selection = TextSelection.collapsed(
        offset: _keyBonusController.text.length,
      );
      return;
    }
    widget.facade.updateNpcTemplate(
      templateId: selectedResource!.id,
      keyBonus: parsedValue,
    );
  }

  void _handleDelete() {
    final selectedResource = widget.selectedResource;
    if (selectedResource == null) {
      return;
    }
    final deleted = selectedResource.kind == BattleEntityKind.npc
        ? widget.facade.deleteNpcTemplate(selectedResource.id)
        : widget.facade.deletePlayerResource(selectedResource.id);
    if (deleted) {
      widget.onDeleteCompleted();
    }
  }

  void _handleAddToRoster() {
    final selectedResource = widget.selectedResource;
    if (selectedResource == null) {
      return;
    }
    widget.facade.appendDefaultRosterEntry(
      resourceId: selectedResource.id,
      kind: selectedResource.kind,
    );
  }

  Future<void> _handleRelinkPlayerPortrait() async {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.player) {
      return;
    }
    await widget.facade.relinkPlayerResourcePortrait(selectedResource!.id);
  }

  Future<void> _handleRelinkNpcPortrait() async {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.npc) {
      return;
    }
    await widget.facade.relinkNpcTemplatePortrait(selectedResource!.id);
  }

  Future<void> _handleBindNpcPortrait() async {
    final selectedResource = widget.selectedResource;
    if (selectedResource?.kind != BattleEntityKind.npc) {
      return;
    }
    await widget.facade.bindNpcTemplatePortraitFromExternal(
      selectedResource!.id,
    );
  }
}

class _BattleResourceDetailEmptyState extends StatelessWidget {
  const _BattleResourceDetailEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '请选择角色',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _BattlePlayerPortraitBindingSection extends StatelessWidget {
  const _BattlePlayerPortraitBindingSection({
    required this.assetPath,
    required this.assetMissing,
    required this.onRelink,
  });

  final String? assetPath;
  final bool assetMissing;
  final Future<void> Function() onRelink;

  @override
  Widget build(BuildContext context) {
    final trimmedPath = assetPath?.trim() ?? '';
    final hasAsset = trimmedPath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(hasAsset ? trimmedPath : '未绑定'),
        if (assetMissing) ...[
          const SizedBox(height: 12),
          Text(
            '立绘资源已失效，请重新选择文件。',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRelink,
            child: const Text('重新选择文件'),
          ),
        ],
      ],
    );
  }
}

class _BattleNpcPortraitBindingSection extends StatelessWidget {
  const _BattleNpcPortraitBindingSection({
    required this.assetPath,
    required this.assetMissing,
    required this.onRelink,
    required this.onBind,
  });

  final String? assetPath;
  final bool assetMissing;
  final Future<void> Function() onRelink;
  final Future<void> Function() onBind;

  @override
  Widget build(BuildContext context) {
    final trimmedPath = assetPath?.trim() ?? '';
    final hasAsset = trimmedPath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(hasAsset ? trimmedPath : '未绑定'),
        if (!hasAsset) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onBind,
            child: const Text('绑定立绘'),
          ),
        ] else if (assetMissing) ...[
          const SizedBox(height: 12),
          Text(
            '立绘资源已失效，请重新选择文件。',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRelink,
            child: const Text('重新选择文件'),
          ),
        ],
      ],
    );
  }
}
