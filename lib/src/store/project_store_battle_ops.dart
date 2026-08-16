part of 'project_store.dart';

extension ProjectStoreBattleOps on ProjectStore {
  BattleModuleModel get battle => _project.battle;

  void setProjectMode(ProjectMode mode) {
    if (_project.currentMode == mode) {
      return;
    }
    _project = _project.copyWith(currentMode: mode);
    _notifyBattleListeners();
    _onProjectChanged(
      notifyController: true,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
      invalidateRenderList: false,
      invalidateAssetExists: false,
    );
  }

  void setBattlePage(BattlePage page) {
    if (_project.battle.uiState.currentPage == page) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        uiState: _project.battle.uiState.copyWith(currentPage: page),
      ),
    );
  }

  void setBattleOutputShowing(bool value) {
    if (_project.battle.workspace.outputShowingBattle == value) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        workspace: _project.battle.workspace.copyWith(
          outputShowingBattle: value,
        ),
      ),
    );
  }

  void selectBattleEntity(String? entityId) {
    if (_project.battle.workspace.selectedEntityId == entityId) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        workspace: _project.battle.workspace.copyWith(
          selectedEntityId: entityId,
        ),
      ),
    );
  }

  void createNpcTemplate() {
    final templates = <NpcTemplateModel>[
      ..._project.battle.library.npcTemplates,
      _createEmptyNpcTemplate(),
    ];
    _updateBattle(
      _project.battle.copyWith(
        library: _project.battle.library.copyWith(npcTemplates: templates),
      ),
    );
  }

  void importNpcTemplatesFromSceneNodeIds(List<String> nodeIds) {
    if (nodeIds.isEmpty) {
      return;
    }
    final existingResources = <NpcTemplateModel>[
      ..._project.battle.library.npcTemplates,
    ];
    final collected = <NpcTemplateModel>[];
    var upgradedExistingTemplate = false;
    var idSeq = _idNumberForPrefix('npc_tpl');

    String nextIdLocal() => 'npc_tpl_${idSeq++}';

    for (final nodeId in nodeIds) {
      final node = _findNodeById(_project.root, nodeId);
      if (node == null || node.type != NodeType.image) {
        continue;
      }
      final asset = (node.asset ?? '').trim();
      if (asset.isEmpty) {
        continue;
      }
      final name = node.name.trim().isEmpty ? '未命名 NPC' : node.name.trim();
      final normalizedAsset = asset.toLowerCase();

      final existingByAsset = existingResources.any(
        (template) =>
            (template.portrait?.asset ?? '').trim().toLowerCase() ==
            normalizedAsset,
      );
      if (existingByAsset) {
        continue;
      }

      final template = NpcTemplateModel(
        id: nextIdLocal(),
        name: name,
        portrait: BattleResourcePortraitBinding(asset: asset),
        traitText: '',
        maxHp: 1,
        keyBonus: 0,
      );
      collected.add(template);
      existingResources.add(template);
    }

    if (!upgradedExistingTemplate && collected.isEmpty) {
      return;
    }

    _updateBattle(
      _project.battle.copyWith(
        library: _project.battle.library.copyWith(
          npcTemplates: [
            ..._project.battle.library.npcTemplates,
            ...collected,
          ],
        ),
      ),
    );
  }

  void updateNpcTemplate({
    required String templateId,
    String? name,
    String? traitText,
    int? maxHp,
    int? keyBonus,
    BattleResourcePortraitBinding? portrait,
    bool updatePortrait = false,
  }) {
    final templates = _project.battle.library.npcTemplates;
    var changed = false;
    final nextTemplates = templates.map((template) {
      if (template.id != templateId) {
        return template;
      }
      changed = true;
      final nextTemplate = template.copyWith(
        name: name,
        traitText: traitText,
        maxHp: maxHp,
        keyBonus: keyBonus,
      );
      if (!updatePortrait) {
        return nextTemplate;
      }
      return nextTemplate.copyWith(portrait: portrait);
    }).toList(growable: false);
    if (!changed) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        library: _project.battle.library.copyWith(npcTemplates: nextTemplates),
      ),
    );
  }

  bool deleteNpcTemplate(String templateId) {
    final library = _project.battle.library;
    final templates = library.npcTemplates;
    final nextTemplates = templates
        .where((template) => template.id != templateId)
        .toList(growable: false);
    if (nextTemplates.length == templates.length) {
      return false;
    }
    final nextDefaultRoster = _project.battle.defaultRoster
        .where(
          (entry) =>
              !(entry.kind == BattleEntityKind.npc &&
                  entry.resourceId == templateId),
        )
        .toList(growable: false);
    _updateBattle(
      _project.battle.copyWith(
        library: library.copyWith(npcTemplates: nextTemplates),
        defaultRoster: nextDefaultRoster,
      ),
    );
    return true;
  }

  void importPlayerResourcesFromCurrentScene() {
    final nodeIds = <String>[];

    void visit(NodeModel node) {
      if (node.type == NodeType.image) {
        final asset = (node.asset ?? '').trim();
        if (asset.isNotEmpty) {
          nodeIds.add(node.id);
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(_project.root);
    importPlayerResourcesFromSceneNodeIds(nodeIds);
  }

  void importPlayerResourcesFromSceneNodeIds(List<String> nodeIds) {
    if (nodeIds.isEmpty) {
      return;
    }
    final collected = <PlayerResourceModel>[];
    final existingResources = <PlayerResourceModel>[
      ..._project.battle.library.playerResources,
    ];
    var upgradedExistingResource = false;
    var idSeq = _idNumberForPrefix('player_res');

    String nextIdLocal() => 'player_res_${idSeq++}';

    for (final nodeId in nodeIds) {
      final node = _findNodeById(_project.root, nodeId);
      if (node == null || node.type != NodeType.image) {
        continue;
      }
      final asset = (node.asset ?? '').trim();
      if (asset.isEmpty) {
        continue;
      }
      final name = node.name.trim().isEmpty ? '未命名资源' : node.name.trim();
      final normalizedAsset = asset.toLowerCase();

      final existingByNode = existingResources.any(
        (resource) => resource.sourceNodeId?.trim() == node.id,
      );
      if (existingByNode) {
        continue;
      }

      final upgradeIndex = existingResources.indexWhere((resource) {
        final resourceSourceNodeId = resource.sourceNodeId?.trim() ?? '';
        final resourceAsset = (resource.portrait?.asset ?? '').trim().toLowerCase();
        return resourceSourceNodeId.isEmpty && resourceAsset == normalizedAsset;
      });
      if (upgradeIndex >= 0) {
        existingResources[upgradeIndex] = existingResources[upgradeIndex].copyWith(
          sourceNodeId: node.id,
        );
        upgradedExistingResource = true;
        continue;
      }

      final resource = PlayerResourceModel(
        id: nextIdLocal(),
        name: name,
        portrait: BattleResourcePortraitBinding(asset: asset),
        sourceNodeId: node.id,
      );
      collected.add(resource);
      existingResources.add(resource);
    }
    if (!upgradedExistingResource && collected.isEmpty) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        library: _project.battle.library.copyWith(
          playerResources: [
            ..._project.battle.library.playerResources,
            ...collected,
          ],
        ),
      ),
    );
  }

  void updatePlayerResource({
    required String resourceId,
    String? name,
    BattleResourcePortraitBinding? portrait,
    bool updatePortrait = false,
  }) {
    final resources = _project.battle.library.playerResources;
    var changed = false;
    final nextResources = resources.map((resource) {
      if (resource.id != resourceId) {
        return resource;
      }
      changed = true;
      final nextResource = resource.copyWith(
        name: name,
      );
      if (!updatePortrait) {
        return nextResource;
      }
      return nextResource.copyWith(portrait: portrait);
    }).toList(growable: false);
    if (!changed) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        library: _project.battle.library.copyWith(
          playerResources: nextResources,
        ),
      ),
    );
  }

  bool deletePlayerResource(String resourceId) {
    final library = _project.battle.library;
    final resources = library.playerResources;
    final nextResources = resources
        .where((resource) => resource.id != resourceId)
        .toList(growable: false);
    if (nextResources.length == resources.length) {
      return false;
    }
    final nextDefaultRoster = _project.battle.defaultRoster
        .where(
          (entry) =>
              !(entry.kind == BattleEntityKind.player &&
                  entry.resourceId == resourceId),
        )
        .toList(growable: false);
    _updateBattle(
      _project.battle.copyWith(
        library: library.copyWith(playerResources: nextResources),
        defaultRoster: nextDefaultRoster,
      ),
    );
    return true;
  }

  void appendDefaultRosterEntry(BattleRosterEntryModel entry) {
    _updateBattle(
      _project.battle.copyWith(
        defaultRoster: [..._project.battle.defaultRoster, entry],
      ),
    );
  }

  void removeDefaultRosterEntryAt(int index) {
    final defaultRoster = _project.battle.defaultRoster;
    if (index < 0 || index >= defaultRoster.length) {
      return;
    }
    final nextRoster = [...defaultRoster]..removeAt(index);
    _updateBattle(
      _project.battle.copyWith(
        defaultRoster: nextRoster,
      ),
    );
  }

  void moveDefaultRosterEntry(int from, int delta) {
    final defaultRoster = _project.battle.defaultRoster;
    if (from < 0 || from >= defaultRoster.length || delta == 0) {
      return;
    }
    final targetIndex = from + delta;
    if (targetIndex < 0 || targetIndex >= defaultRoster.length) {
      return;
    }
    final nextRoster = [...defaultRoster];
    final movedEntry = nextRoster.removeAt(from);
    nextRoster.insert(targetIndex, movedEntry);
    _updateBattle(
      _project.battle.copyWith(
        defaultRoster: nextRoster,
      ),
    );
  }

  bool hasMissingResourcesInDefaultRoster() {
    final battle = _project.battle;
    return _defaultRosterHasMissingResources(
      library: battle.library,
      entries: battle.defaultRoster,
    );
  }

  bool materializeCurrentBattleFromDefaultRoster() {
    final library = _project.battle.library;
    final entries = _project.battle.defaultRoster;
    if (entries.isEmpty) {
      return false;
    }
    if (_defaultRosterHasMissingResources(library: library, entries: entries)) {
      return false;
    }
    final entities = <BattleEntityModel>[];
    final npcNameCounts = <String, int>{};
    var entityIdSeq = _idNumberForPrefix('battle_entity');

    for (final entry in entries) {
      if (entry.kind == BattleEntityKind.npc) {
        final template = _findNpcTemplateById(library, entry.resourceId);
        if (template == null) {
          continue;
        }
        final nextIndex = (npcNameCounts[template.name] ?? 0) + 1;
        npcNameCounts[template.name] = nextIndex;
        entities.add(
          BattleEntityModel(
            id: 'battle_entity_${entityIdSeq++}',
            resourceId: template.id,
            kind: BattleEntityKind.npc,
            displayName: '${template.name}$nextIndex',
            currentHp: template.maxHp,
            state: BattleEntityState.standby,
            markers: const [],
            note: '',
            isForeground: false,
            isCurrentActor: false,
          ),
        );
        continue;
      }

      final resource = _findPlayerResourceById(library, entry.resourceId);
      if (resource == null) {
        continue;
      }
      entities.add(
        BattleEntityModel(
          id: 'battle_entity_${entityIdSeq++}',
          resourceId: resource.id,
          kind: BattleEntityKind.player,
          displayName: resource.name,
          currentHp: null,
          state: BattleEntityState.standby,
          markers: const [],
          note: '',
          isForeground: false,
          isCurrentActor: false,
        ),
      );
    }

    final currentWorkspace = _project.battle.workspace;
    _updateBattle(
      _project.battle.copyWith(
        workspace: currentWorkspace.copyWith(
          entities: entities,
          selectedEntityId: null,
        ),
      ),
    );
    return true;
  }

  void updateBattleEntity({
    required String entityId,
    String? displayName,
    Object? currentHp,
    BattleEntityState? state,
    List<String>? markers,
    String? note,
    bool? isForeground,
    bool? isCurrentActor,
  }) {
    final workspace = _project.battle.workspace;
    final index = workspace.entities.indexWhere((e) => e.id == entityId);
    if (index < 0) {
      return;
    }
    final entity = workspace.entities[index];
    final resolvedHp =
        currentHp is int ? currentHp : (currentHp == null ? entity.currentHp : null);
    final effectiveState = (resolvedHp is int && resolvedHp <= 0)
        ? BattleEntityState.defeated
        : state;
    List<BattleEntityModel> nextEntities;
    if (effectiveState == BattleEntityState.active) {
      nextEntities = workspace.entities.map((e) {
        if (e.id == entityId) {
          return entity.copyWith(
            displayName: displayName,
            currentHp: resolvedHp,
            state: effectiveState,
            markers: markers,
            note: note,
            isForeground: isForeground,
            isCurrentActor: isCurrentActor,
          );
        }
        if (e.kind == entity.kind && e.state == BattleEntityState.active) {
          return e.copyWith(state: BattleEntityState.standby);
        }
        return e;
      }).toList(growable: false);
    } else {
      final updated = entity.copyWith(
        displayName: displayName,
        currentHp: resolvedHp,
        state: effectiveState,
        markers: markers,
        note: note,
        isForeground: isForeground,
        isCurrentActor: isCurrentActor,
      );
      nextEntities = [...workspace.entities];
      nextEntities[index] = updated;
    }
    _updateBattle(
      _project.battle.copyWith(
        workspace: workspace.copyWith(entities: nextEntities),
      ),
    );
  }

  void removeBattleEntity(String entityId) {
    final workspace = _project.battle.workspace;
    final index = workspace.entities.indexWhere((e) => e.id == entityId);
    if (index < 0) {
      return;
    }
    final nextEntities = List<BattleEntityModel>.from(workspace.entities)..removeAt(index);
    final nextSelectedId = workspace.selectedEntityId == entityId
        ? null
        : workspace.selectedEntityId;
    _updateBattle(
      _project.battle.copyWith(
        workspace: workspace.copyWith(
          entities: nextEntities,
          selectedEntityId: nextSelectedId,
        ),
      ),
    );
  }

  void addEntityToBattle(String resourceId, BattleEntityKind kind) {
    final battle = _project.battle;
    final library = battle.library;
    final workspace = battle.workspace;

    if (kind == BattleEntityKind.npc) {
      final template = library.npcTemplates.cast<NpcTemplateModel?>().firstWhere(
        (t) => t!.id == resourceId,
        orElse: () => null,
      );
      if (template == null) {
        return;
      }
      final count = workspace.entities
          .where((e) => e.kind == BattleEntityKind.npc && e.resourceId == resourceId)
          .length;
      final entity = BattleEntityModel(
        id: 'battle_entity_${_idNumberForPrefix('battle_entity')}',
        resourceId: template.id,
        kind: BattleEntityKind.npc,
        displayName: count > 0 ? '${template.name}${count + 1}' : template.name,
        currentHp: template.maxHp,
        state: BattleEntityState.standby,
        markers: const [],
        note: '',
        isForeground: false,
        isCurrentActor: false,
      );
      _updateBattle(
        battle.copyWith(
          workspace: workspace.copyWith(
            entities: [...workspace.entities, entity],
          ),
        ),
      );
      return;
    }
    final resource = library.playerResources.cast<PlayerResourceModel?>().firstWhere(
      (r) => r!.id == resourceId,
      orElse: () => null,
    );
    if (resource == null) {
      return;
    }
    final count = workspace.entities
        .where((e) => e.kind == BattleEntityKind.player && e.resourceId == resourceId)
        .length;
    final entity = BattleEntityModel(
      id: 'battle_entity_${_idNumberForPrefix('battle_entity')}',
      resourceId: resource.id,
      kind: BattleEntityKind.player,
      displayName: count > 0 ? '${resource.name}${count + 1}' : resource.name,
      currentHp: null,
      state: BattleEntityState.standby,
      markers: const [],
      note: '',
      isForeground: false,
      isCurrentActor: false,
    );
    _updateBattle(
      battle.copyWith(
        workspace: workspace.copyWith(
          entities: [...workspace.entities, entity],
        ),
      ),
    );
  }

  void clearCurrentBattleWorkspace() {
    final workspace = _project.battle.workspace;
    if (workspace.entities.isEmpty &&
        workspace.selectedEntityId == null) {
      return;
    }
    _updateBattle(
      _project.battle.copyWith(
        workspace: workspace.copyWith(
          entities: const [],
          selectedEntityId: null,
        ),
      ),
    );
  }

  bool reorderBattleTurnOrder(int oldIndex, int newIndex) {
    final entities = _project.battle.workspace.entities;
    if (oldIndex < 0 || oldIndex >= entities.length) {
      return false;
    }
    if (newIndex < 0 || newIndex > entities.length) {
      return false;
    }
    if (oldIndex == newIndex || oldIndex + 1 == newIndex) {
      return true;
    }
    // ReorderableListView.onReorder 在下移时 newIndex 比目标位置大 1。
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final nextEntities = [...entities];
    final moved = nextEntities.removeAt(oldIndex);
    nextEntities.insert(adjustedNewIndex, moved);
    _updateBattle(
      _project.battle.copyWith(
        workspace:
            _project.battle.workspace.copyWith(entities: nextEntities),
      ),
    );
    return true;
  }

  void _updateBattle(BattleModuleModel battle) {
    _project = _project.copyWith(battle: battle);
    _notifyBattleListeners();
    _onProjectChanged(
      notifyController: true,
      notifyStage: false,
      notifyLayerTree: false,
      notifyAudio: false,
      notifyDice: false,
      notifyTransform: false,
      invalidateRenderList: false,
      invalidateAssetExists: false,
    );
  }

  NpcTemplateModel _createEmptyNpcTemplate() {
    return NpcTemplateModel(
      id: _nextId('npc_tpl'),
      name: '未命名 NPC',
      portrait: null,
      traitText: '',
      maxHp: 1,
      keyBonus: 0,
    );
  }

  NpcTemplateModel? _findNpcTemplateById(
    BattleLibraryModel library,
    String id,
  ) {
    for (final template in library.npcTemplates) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }

  PlayerResourceModel? _findPlayerResourceById(
    BattleLibraryModel library,
    String id,
  ) {
    for (final resource in library.playerResources) {
      if (resource.id == id) {
        return resource;
      }
    }
    return null;
  }

  bool _defaultRosterHasMissingResources({
    required BattleLibraryModel library,
    required List<BattleRosterEntryModel> entries,
  }) {
    for (final entry in entries) {
      if (entry.kind == BattleEntityKind.npc) {
        if (_findNpcTemplateById(library, entry.resourceId) == null) {
          return true;
        }
        continue;
      }
      if (_findPlayerResourceById(library, entry.resourceId) == null) {
        return true;
      }
    }
    return false;
  }

  int _idNumberForPrefix(String prefix) {
    final id = _nextId(prefix);
    final lastUnderscore = id.lastIndexOf('_');
    if (lastUnderscore < 0) {
      return 1;
    }
    return int.tryParse(id.substring(lastUnderscore + 1)) ?? 1;
  }

  void _repairDuplicateBattleIds() {
    var changed = false;
    final battle = _project.battle;

    final seenNpcIds = <String>{};
    final idRemap = <String, String>{};
    final repairedNpc = <NpcTemplateModel>[];
    var idSeq = _idNumberForPrefix('npc_tpl');
    for (final template in battle.library.npcTemplates) {
      if (seenNpcIds.add(template.id)) {
        repairedNpc.add(template);
      } else {
        final newId = 'npc_tpl_${idSeq++}';
        idRemap[template.id] = newId;
        repairedNpc.add(template.copyWith(id: newId));
        changed = true;
      }
    }

    final seenPlayerIds = <String>{};
    final repairedPlayer = <PlayerResourceModel>[];
    var playerIdSeq = _idNumberForPrefix('player_res');
    for (final resource in battle.library.playerResources) {
      if (seenPlayerIds.add(resource.id)) {
        repairedPlayer.add(resource);
      } else {
        final newId = 'player_res_${playerIdSeq++}';
        idRemap[resource.id] = newId;
        repairedPlayer.add(resource.copyWith(id: newId));
        changed = true;
      }
    }

    final seenEntityIds = <String>{};
    final repairedEntities = <BattleEntityModel>[];
    var entityIdSeq = _idNumberForPrefix('battle_entity');
    for (final entity in battle.workspace.entities) {
      if (seenEntityIds.add(entity.id)) {
        repairedEntities.add(entity);
      } else {
        final newId = 'battle_entity_${entityIdSeq++}';
        idRemap[entity.id] = newId;
        repairedEntities.add(entity.copyWith(id: newId));
        changed = true;
      }
    }

    String remapId(String id) => idRemap[id] ?? id;

    if (!changed) {
      return;
    }

    final repairedRoster = battle.defaultRoster.map((entry) {
      final newResourceId = remapId(entry.resourceId);
      if (newResourceId != entry.resourceId) {
        return entry.copyWith(resourceId: newResourceId);
      }
      return entry;
    }).toList(growable: false);

    final repairedSelected = battle.workspace.selectedEntityId != null
        ? remapId(battle.workspace.selectedEntityId!)
        : null;

    _project = _project.copyWith(
      battle: battle.copyWith(
        library: battle.library.copyWith(
          npcTemplates: repairedNpc,
          playerResources: repairedPlayer,
        ),
        defaultRoster: repairedRoster,
        workspace: battle.workspace.copyWith(
          entities: repairedEntities,
          selectedEntityId: repairedSelected,
        ),
      ),
    );
    _markLatestProjectJsonDirty();
  }

  void setAnimAction({
    required String activeEntityId,
    required String targetEntityId,
    required BattleAnimAction activeAction,
    required BattleAnimAction targetAction,
  }) {
    _updateBattle(
      _project.battle.copyWith(
        animation: _project.battle.animation.copyWith(
          activeEntityId: activeEntityId,
          targetEntityId: targetEntityId,
          activeAction: activeAction,
          targetAction: targetAction,
        ),
      ),
    );
  }

  void triggerAnimation() {
    final anim = _project.battle.animation;
    if (anim.activeEntityId == null ||
        anim.targetEntityId == null ||
        anim.activeAction == null ||
        anim.targetAction == null) {
      return;
    }

    final entities = _project.battle.workspace.entities;
    String? findName(String id) {
      for (final e in entities) {
        if (e.id == id) return e.displayName;
      }
      return null;
    }

    final activeName = findName(anim.activeEntityId!) ?? '未知';
    final targetName = findName(anim.targetEntityId!) ?? '未知';
    final activeLabel = _animActionLabel(anim.activeAction!);
    final targetLabel = anim.targetAction == BattleAnimAction.counter
        ? '被命中'
        : _animActionLabel(anim.targetAction!);

    pushFlowMessage('$activeName 对 $targetName 发动了$activeLabel！',
        color: const Color(0xFFFFF59D));
    pushFlowMessage('$targetName $targetLabel了！',
        color: const Color(0xFF80CBC4));

    _updateBattle(
      _project.battle.copyWith(
        animation: anim.copyWith(triggerId: anim.triggerId + 1),
      ),
    );
  }

  String _animActionLabel(BattleAnimAction action) {
    switch (action) {
      case BattleAnimAction.attack:
        return '攻击';
      case BattleAnimAction.dodge:
        return '闪避';
      case BattleAnimAction.counter:
        return '命中';
    }
  }

  void ensureAnimEntities() {
    final anim = _project.battle.animation;
    if (anim.activeEntityId != null && anim.targetEntityId != null) return;

    final entities = _project.battle.workspace.entities;
    String? resolveActive(BattleEntityKind kind) {
      for (final e in entities) {
        if (e.kind == kind && e.state == BattleEntityState.active) {
          return e.id;
        }
      }
      return null;
    }

    final playerActive = resolveActive(BattleEntityKind.player);
    final npcActive = resolveActive(BattleEntityKind.npc);

    _updateBattle(
      _project.battle.copyWith(
        animation: anim.copyWith(
          activeEntityId: anim.activeEntityId ?? playerActive ?? npcActive,
          targetEntityId: anim.targetEntityId ??
              (anim.activeEntityId != null
                  ? (playerActive != null &&
                          playerActive != anim.activeEntityId
                      ? playerActive
                      : npcActive)
                  : (playerActive != null && npcActive != null
                      ? npcActive
                      : (playerActive ?? npcActive))),
        ),
      ),
    );
  }

  void rebindAnimEntities(String activeEntityId) {
    final entities = _project.battle.workspace.entities;
    BattleEntityModel? active;
    for (final e in entities) {
      if (e.id == activeEntityId) {
        active = e;
        break;
      }
    }
    if (active == null) return;

    final opponentKind = active.kind == BattleEntityKind.npc
        ? BattleEntityKind.player
        : BattleEntityKind.npc;
    String? targetId;
    for (final e in entities) {
      if (e.kind == opponentKind && e.state == BattleEntityState.active) {
        targetId = e.id;
        break;
      }
    }
    targetId ??= entities.cast<BattleEntityModel?>().firstWhere(
      (e) => e!.kind == opponentKind,
      orElse: () => null,
    )?.id;

    _updateBattle(
      _project.battle.copyWith(
        animation: _project.battle.animation.copyWith(
          activeEntityId: activeEntityId,
          targetEntityId: targetId,
        ),
      ),
    );
  }

  void _refreshIdSeedFromBattle() {}
}
