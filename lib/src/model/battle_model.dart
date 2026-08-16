int? _tryReadJsonInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final intValue = int.tryParse(normalized);
    if (intValue != null) {
      return intValue;
    }
    final doubleValue = double.tryParse(normalized);
    return doubleValue?.toInt();
  }
  return null;
}

int _readJsonInt(dynamic value, {required int fallback}) {
  return _tryReadJsonInt(value) ?? fallback;
}

bool _readJsonBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return fallback;
}

List<String> _readJsonStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}

Map<String, dynamic> _readJsonMap(dynamic value) {
  return (value as Map?)?.cast<String, dynamic>() ?? const {};
}

ProjectMode projectModeFromJson(dynamic value) {
  final rawValue = (value as String?)?.toLowerCase();
  if (rawValue == ProjectMode.battle.name) {
    return ProjectMode.battle;
  }
  return ProjectMode.scene;
}

BattlePage battlePageFromJson(dynamic value) {
  final rawValue = (value as String?)?.toLowerCase();
  if (rawValue == BattlePage.preparation.name) {
    return BattlePage.preparation;
  }
  if (rawValue == 'roster' || rawValue == 'library') {
    return BattlePage.preparation;
  }
  return BattlePage.workspace;
}

BattleEntityKind battleEntityKindFromJson(dynamic value) {
  final rawValue = (value as String?)?.toLowerCase();
  if (rawValue == BattleEntityKind.player.name) {
    return BattleEntityKind.player;
  }
  return BattleEntityKind.npc;
}

BattleEntityState battleEntityStateFromJson(dynamic value) {
  final rawValue = (value as String?)?.toLowerCase();
  if (rawValue == BattleEntityState.active.name) {
    return BattleEntityState.active;
  }
  if (rawValue == BattleEntityState.retired.name) {
    return BattleEntityState.retired;
  }
  if (rawValue == BattleEntityState.defeated.name) {
    return BattleEntityState.defeated;
  }
  return BattleEntityState.standby;
}

enum ProjectMode { scene, battle }

enum BattlePage { workspace, preparation }

enum BattleEntityKind { npc, player }

enum BattleEntityState { standby, active, retired, defeated }

enum BattleAnimAction { attack, dodge, counter }

class BattleResourcePortraitBinding {
  final String asset;

  const BattleResourcePortraitBinding({required this.asset});

  factory BattleResourcePortraitBinding.fromJson(Map<String, dynamic> json) {
    return BattleResourcePortraitBinding(
      asset: (json['asset'] as String?) ?? '',
    );
  }

  BattleResourcePortraitBinding copyWith({String? asset}) {
    return BattleResourcePortraitBinding(
      asset: asset ?? this.asset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset': asset,
    };
  }
}

class NpcTemplateModel {
  static const Object _unsetPortrait = Object();

  final String id;
  final String name;
  final BattleResourcePortraitBinding? portrait;
  final String traitText;
  final int maxHp;
  final int keyBonus;

  const NpcTemplateModel({
    required this.id,
    required this.name,
    required this.portrait,
    required this.traitText,
    required this.maxHp,
    required this.keyBonus,
  });

  factory NpcTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawPortrait = _readJsonMap(json['portrait']);
    return NpcTemplateModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      portrait: rawPortrait.isEmpty
          ? null
          : BattleResourcePortraitBinding.fromJson(rawPortrait),
      traitText: (json['traitText'] as String?) ?? '',
      maxHp: _readJsonInt(json['maxHp'], fallback: 0),
      keyBonus: _readJsonInt(json['keyBonus'], fallback: 0),
    );
  }

  NpcTemplateModel copyWith({
    String? id,
    String? name,
    Object? portrait = _unsetPortrait,
    String? traitText,
    int? maxHp,
    int? keyBonus,
  }) {
    return NpcTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      portrait: identical(portrait, _unsetPortrait)
          ? this.portrait
          : portrait as BattleResourcePortraitBinding?,
      traitText: traitText ?? this.traitText,
      maxHp: maxHp ?? this.maxHp,
      keyBonus: keyBonus ?? this.keyBonus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'portrait': portrait?.toJson(),
      'traitText': traitText,
      'maxHp': maxHp,
      'keyBonus': keyBonus,
    };
  }
}

class PlayerResourceModel {
  static const Object _unsetPortrait = Object();
  static const Object _unsetSourceNodeId = Object();

  final String id;
  final String name;
  final BattleResourcePortraitBinding? portrait;
  final String? sourceNodeId;

  const PlayerResourceModel({
    required this.id,
    required this.name,
    required this.portrait,
    required this.sourceNodeId,
  });

  factory PlayerResourceModel.fromJson(Map<String, dynamic> json) {
    final rawPortrait = _readJsonMap(json['portrait']);
    return PlayerResourceModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      portrait: rawPortrait.isEmpty
          ? null
          : BattleResourcePortraitBinding.fromJson(rawPortrait),
      sourceNodeId: json['sourceNodeId'] as String?,
    );
  }

  PlayerResourceModel copyWith({
    String? id,
    String? name,
    Object? portrait = _unsetPortrait,
    Object? sourceNodeId = _unsetSourceNodeId,
  }) {
    return PlayerResourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      portrait: identical(portrait, _unsetPortrait)
          ? this.portrait
          : portrait as BattleResourcePortraitBinding?,
      sourceNodeId: identical(sourceNodeId, _unsetSourceNodeId)
          ? this.sourceNodeId
          : sourceNodeId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'portrait': portrait?.toJson(),
      'sourceNodeId': sourceNodeId,
    };
  }
}

class BattleRosterEntryModel {
  final String resourceId;
  final BattleEntityKind kind;

  const BattleRosterEntryModel({
    required this.resourceId,
    required this.kind,
  });

  factory BattleRosterEntryModel.fromJson(Map<String, dynamic> json) {
    return BattleRosterEntryModel(
      resourceId: (json['resourceId'] as String?) ?? '',
      kind: battleEntityKindFromJson(json['kind']),
    );
  }

  BattleRosterEntryModel copyWith({
    String? resourceId,
    BattleEntityKind? kind,
  }) {
    return BattleRosterEntryModel(
      resourceId: resourceId ?? this.resourceId,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resourceId': resourceId,
      'kind': kind.name,
    };
  }
}

class BattleEntityModel {
  static const Object _unsetCurrentHp = Object();

  final String id;
  final String resourceId;
  final BattleEntityKind kind;
  final String displayName;
  final int? currentHp;
  final BattleEntityState state;
  final List<String> markers;
  final String note;
  final bool isForeground;
  final bool isCurrentActor;

  const BattleEntityModel({
    required this.id,
    required this.resourceId,
    required this.kind,
    required this.displayName,
    required this.currentHp,
    required this.state,
    required this.markers,
    required this.note,
    required this.isForeground,
    required this.isCurrentActor,
  });

  factory BattleEntityModel.fromJson(Map<String, dynamic> json) {
    return BattleEntityModel(
      id: (json['id'] as String?) ?? '',
      resourceId: (json['resourceId'] as String?) ?? '',
      kind: battleEntityKindFromJson(json['kind']),
      displayName: (json['displayName'] as String?) ?? '',
      currentHp: _tryReadJsonInt(json['currentHp']),
      state: battleEntityStateFromJson(json['state']),
      markers: _readJsonStringList(json['markers']),
      note: (json['note'] as String?) ?? '',
      isForeground: _readJsonBool(json['isForeground'], fallback: false),
      isCurrentActor: _readJsonBool(json['isCurrentActor'], fallback: false),
    );
  }

  BattleEntityModel copyWith({
    String? id,
    String? resourceId,
    BattleEntityKind? kind,
    String? displayName,
    Object? currentHp = _unsetCurrentHp,
    BattleEntityState? state,
    List<String>? markers,
    String? note,
    bool? isForeground,
    bool? isCurrentActor,
  }) {
    return BattleEntityModel(
      id: id ?? this.id,
      resourceId: resourceId ?? this.resourceId,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      currentHp: identical(currentHp, _unsetCurrentHp)
          ? this.currentHp
          : currentHp as int?,
      state: state ?? this.state,
      markers: markers ?? this.markers,
      note: note ?? this.note,
      isForeground: isForeground ?? this.isForeground,
      isCurrentActor: isCurrentActor ?? this.isCurrentActor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceId': resourceId,
      'kind': kind.name,
      'displayName': displayName,
      'currentHp': currentHp,
      'state': state.name,
      'markers': markers,
      'note': note,
      'isForeground': isForeground,
      'isCurrentActor': isCurrentActor,
    };
  }
}

class BattleWorkspaceModel {
  static const Object _unsetSelectedEntityId = Object();

  final List<BattleEntityModel> entities;
  final String? selectedEntityId;
  final bool outputShowingBattle;

  const BattleWorkspaceModel({
    required this.entities,
    required this.selectedEntityId,
    required this.outputShowingBattle,
  });

  const BattleWorkspaceModel.initial()
      : entities = const [],
        selectedEntityId = null,
        outputShowingBattle = false;

  factory BattleWorkspaceModel.fromJson(Map<String, dynamic> json) {
    final rawEntities = json['entities'];
    return BattleWorkspaceModel(
      entities: rawEntities is List
          ? rawEntities
              .whereType<Map>()
              .map((e) => BattleEntityModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      selectedEntityId: json['selectedEntityId'] as String?,
      outputShowingBattle: _readJsonBool(
        json['outputShowingBattle'],
        fallback: false,
      ),
    );
  }

  BattleWorkspaceModel copyWith({
    List<BattleEntityModel>? entities,
    Object? selectedEntityId = _unsetSelectedEntityId,
    bool? outputShowingBattle,
  }) {
    return BattleWorkspaceModel(
      entities: entities ?? this.entities,
      selectedEntityId: identical(selectedEntityId, _unsetSelectedEntityId)
          ? this.selectedEntityId
          : selectedEntityId as String?,
      outputShowingBattle: outputShowingBattle ?? this.outputShowingBattle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entities': entities.map((e) => e.toJson()).toList(),
      'selectedEntityId': selectedEntityId,
      'outputShowingBattle': outputShowingBattle,
    };
  }

}

class BattleLibraryModel {
  final List<NpcTemplateModel> npcTemplates;
  final List<PlayerResourceModel> playerResources;

  const BattleLibraryModel({
    required this.npcTemplates,
    required this.playerResources,
  });

  const BattleLibraryModel.initial()
      : npcTemplates = const [],
        playerResources = const [];

  factory BattleLibraryModel.fromJson(Map<String, dynamic> json) {
    final rawNpcTemplates = json['npcTemplates'];
    final rawPlayerResources = json['playerResources'];
    return BattleLibraryModel(
      npcTemplates: rawNpcTemplates is List
          ? rawNpcTemplates
              .whereType<Map>()
              .map((e) => NpcTemplateModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      playerResources: rawPlayerResources is List
          ? rawPlayerResources
              .whereType<Map>()
              .map((e) =>
                  PlayerResourceModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  BattleLibraryModel copyWith({
    List<NpcTemplateModel>? npcTemplates,
    List<PlayerResourceModel>? playerResources,
  }) {
    return BattleLibraryModel(
      npcTemplates: npcTemplates ?? this.npcTemplates,
      playerResources: playerResources ?? this.playerResources,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'npcTemplates': npcTemplates.map((e) => e.toJson()).toList(),
      'playerResources': playerResources.map((e) => e.toJson()).toList(),
    };
  }
}

class BattleUiStateModel {
  final BattlePage currentPage;

  const BattleUiStateModel({
    required this.currentPage,
  });

  const BattleUiStateModel.initial()
      : currentPage = BattlePage.workspace;

  factory BattleUiStateModel.fromJson(Map<String, dynamic> json) {
    return BattleUiStateModel(
      currentPage: battlePageFromJson(json['currentPage']),
    );
  }

  BattleUiStateModel copyWith({
    BattlePage? currentPage,
  }) {
    return BattleUiStateModel(
      currentPage: currentPage ?? this.currentPage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage.name,
    };
  }
}

class BattleAnimationState {
  const BattleAnimationState({
    required this.triggerId,
    required this.activeEntityId,
    required this.targetEntityId,
    required this.activeAction,
    required this.targetAction,
  });

  const BattleAnimationState.initial()
      : triggerId = 0,
        activeEntityId = null,
        targetEntityId = null,
        activeAction = null,
        targetAction = null;

  final int triggerId;
  final String? activeEntityId;
  final String? targetEntityId;
  final BattleAnimAction? activeAction;
  final BattleAnimAction? targetAction;

  factory BattleAnimationState.fromJson(Map<String, dynamic> json) {
    return BattleAnimationState(
      triggerId: _readJsonInt(json['triggerId'], fallback: 0),
      activeEntityId: json['activeEntityId'] as String?,
      targetEntityId: json['targetEntityId'] as String?,
      activeAction: _animActionFromJson(json['activeAction']),
      targetAction: _animActionFromJson(json['targetAction']),
    );
  }

  BattleAnimationState copyWith({
    int? triggerId,
    Object? activeEntityId = _unsetEntityId,
    Object? targetEntityId = _unsetTargetEntityId,
    Object? activeAction = _unsetAnimAction,
    Object? targetAction = _unsetTargetAnimAction,
  }) {
    return BattleAnimationState(
      triggerId: triggerId ?? this.triggerId,
      activeEntityId: identical(activeEntityId, _unsetEntityId)
          ? this.activeEntityId
          : activeEntityId as String?,
      targetEntityId: identical(targetEntityId, _unsetTargetEntityId)
          ? this.targetEntityId
          : targetEntityId as String?,
      activeAction: identical(activeAction, _unsetAnimAction)
          ? this.activeAction
          : activeAction as BattleAnimAction?,
      targetAction: identical(targetAction, _unsetTargetAnimAction)
          ? this.targetAction
          : targetAction as BattleAnimAction?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'triggerId': triggerId,
      'activeEntityId': activeEntityId,
      'targetEntityId': targetEntityId,
      'activeAction': activeAction?.name,
      'targetAction': targetAction?.name,
    };
  }

  static const _unsetEntityId = Object();
  static const _unsetTargetEntityId = Object();
  static const _unsetAnimAction = Object();
  static const _unsetTargetAnimAction = Object();
}

BattleAnimAction? _animActionFromJson(dynamic value) {
  final raw = (value as String?)?.toLowerCase();
  if (raw == BattleAnimAction.attack.name) return BattleAnimAction.attack;
  if (raw == BattleAnimAction.dodge.name) return BattleAnimAction.dodge;
  if (raw == BattleAnimAction.counter.name) return BattleAnimAction.counter;
  return null;
}

class BattleModuleModel {
  final BattleLibraryModel library;
  final List<BattleRosterEntryModel> defaultRoster;
  final BattleWorkspaceModel workspace;
  final BattleUiStateModel uiState;
  final BattleAnimationState animation;

  const BattleModuleModel({
    required this.library,
    required this.defaultRoster,
    required this.workspace,
    required this.uiState,
    required this.animation,
  });

  const BattleModuleModel.initial()
      : library = const BattleLibraryModel.initial(),
        defaultRoster = const [],
        workspace = const BattleWorkspaceModel.initial(),
        uiState = const BattleUiStateModel.initial(),
        animation = const BattleAnimationState.initial();

  factory BattleModuleModel.fromJson(Map<String, dynamic> json) {
    final rawDefaultRoster = json['defaultRoster'];
    return BattleModuleModel(
      library: BattleLibraryModel.fromJson(_readJsonMap(json['library'])),
      defaultRoster: rawDefaultRoster is List
          ? rawDefaultRoster
              .whereType<Map>()
              .map(
                (e) => BattleRosterEntryModel.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
              .toList()
          : const [],
      workspace: BattleWorkspaceModel.fromJson(_readJsonMap(json['workspace'])),
      uiState: BattleUiStateModel.fromJson(_readJsonMap(json['uiState'])),
      animation: BattleAnimationState.fromJson(
          _readJsonMap(json['animation'])),
    );
  }

  BattleModuleModel copyWith({
    BattleLibraryModel? library,
    List<BattleRosterEntryModel>? defaultRoster,
    BattleWorkspaceModel? workspace,
    BattleUiStateModel? uiState,
    BattleAnimationState? animation,
  }) {
    return BattleModuleModel(
      library: library ?? this.library,
      defaultRoster: defaultRoster ?? this.defaultRoster,
      workspace: workspace ?? this.workspace,
      uiState: uiState ?? this.uiState,
      animation: animation ?? this.animation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'library': library.toJson(),
      'defaultRoster': defaultRoster.map((e) => e.toJson()).toList(),
      'workspace': workspace.toJson(),
      'uiState': uiState.toJson(),
      'animation': animation.toJson(),
    };
  }
}
