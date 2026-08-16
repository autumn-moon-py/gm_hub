import 'dart:convert';

import 'battle_model.dart';

enum NodeType { group, image, text }

double? _tryReadJsonDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
  return null;
}

double _readJsonDouble(dynamic value, {required double fallback}) {
  return _tryReadJsonDouble(value) ?? fallback;
}

double? _readJsonNullableDouble(dynamic value) {
  return _tryReadJsonDouble(value);
}

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

int? _readJsonNullableInt(dynamic value) {
  return _tryReadJsonInt(value);
}

class TransformModel {
  final double x;
  final double y;
  final double scale;
  final double rotation;

  const TransformModel({
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  const TransformModel.identity()
      : x = 0,
        y = 0,
        scale = 1,
        rotation = 0;

  factory TransformModel.fromJson(Map<String, dynamic> json) {
    return TransformModel(
      x: _readJsonDouble(json['x'], fallback: 0),
      y: _readJsonDouble(json['y'], fallback: 0),
      scale: _readJsonDouble(json['scale'], fallback: 1),
      rotation: _readJsonDouble(json['rotation'], fallback: 0),
    );
  }

  TransformModel copyWith({
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return TransformModel(
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }
}

class CanvasModel {
  final double width;
  final double height;

  const CanvasModel({
    required this.width,
    required this.height,
  });

  factory CanvasModel.fromJson(Map<String, dynamic> json) {
    return CanvasModel(
      width: _readJsonDouble(json['width'], fallback: 1920),
      height: _readJsonDouble(json['height'], fallback: 1080),
    );
  }
}

class NodeModel {
  final String id;
  final NodeType type;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;
  final TransformModel transform;
  final List<NodeModel> children;
  final String? asset;
  final String? text;
  final double? fontSize;
  final int? textColorValue;
  final double? width;
  final double? height;

  const NodeModel({
    required this.id,
    required this.type,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    required this.transform,
    this.children = const [],
    this.asset,
    this.text,
    this.fontSize,
    this.textColorValue,
    this.width,
    this.height,
  });

  static String _defaultName(NodeType type) {
    if (type == NodeType.group) {
      return '分组';
    }
    if (type == NodeType.text) {
      return '文字';
    }
    return '图片';
  }

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    final typeString = (json['type'] as String? ?? 'group').toLowerCase();
    final type = typeString == 'image'
        ? NodeType.image
        : (typeString == 'text' ? NodeType.text : NodeType.group);
    final rawChildren = json['children'];
    return NodeModel(
      id: (json['id'] as String?) ?? '',
      type: type,
      name: (json['name'] as String?) ?? _defaultName(type),
      visible: (json['visible'] as bool?) ?? true,
      locked: (json['locked'] as bool?) ?? false,
      opacity: _readJsonDouble(json['opacity'], fallback: 1),
      transform: TransformModel.fromJson(
        (json['transform'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map>()
              .map((e) => NodeModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      asset: json['asset'] as String?,
      text: json['text'] as String?,
      fontSize: _readJsonNullableDouble(json['fontSize']),
      textColorValue: _readJsonNullableInt(json['textColorValue']),
      width: _readJsonNullableDouble(json['width']),
      height: _readJsonNullableDouble(json['height']),
    );
  }

  bool get isGroup => type == NodeType.group;
  bool get isText => type == NodeType.text;

  NodeModel copyWith({
    String? id,
    NodeType? type,
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    TransformModel? transform,
    List<NodeModel>? children,
    String? asset,
    String? text,
    double? fontSize,
    int? textColorValue,
    double? width,
    double? height,
  }) {
    return NodeModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      transform: transform ?? this.transform,
      children: children ?? this.children,
      asset: asset ?? this.asset,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      textColorValue: textColorValue ?? this.textColorValue,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'visible': visible,
      'locked': locked,
      'opacity': opacity,
      'transform': transform.toJson(),
      if (isGroup) 'children': children.map((e) => e.toJson()).toList(),
      if (type == NodeType.image) 'asset': asset ?? '',
      if (type == NodeType.text) 'text': text ?? '',
      if (type == NodeType.text && fontSize != null) 'fontSize': fontSize,
      if (type == NodeType.text && textColorValue != null)
        'textColorValue': textColorValue,
      if (!isGroup && width != null) 'width': width,
      if (!isGroup && height != null) 'height': height,
    };
  }
}

class AudioTrackModel {
  final String id;
  final String name;
  final String asset;
  final List<String> tags;

  const AudioTrackModel({
    required this.id,
    required this.name,
    required this.asset,
    this.tags = const [],
  });

  static List<String> _normalizeTags(Iterable<String> rawTags) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in rawTags) {
      final value = raw.trim();
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (seen.add(key)) {
        result.add(value);
      }
    }
    return result;
  }

  factory AudioTrackModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return AudioTrackModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      asset: (json['asset'] as String?) ?? '',
      tags: rawTags is List
          ? _normalizeTags(rawTags.map((item) => item.toString()))
          : const [],
    );
  }

  AudioTrackModel copyWith({
    String? id,
    String? name,
    String? asset,
    List<String>? tags,
  }) {
    return AudioTrackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      asset: asset ?? this.asset,
      tags: tags == null ? this.tags : _normalizeTags(tags),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }
}

class AudioStateModel {
  static const Object _unsetTrackId = Object();

  final String? currentTrackId;
  final bool loop;
  final double volume;
  final bool isPlaying;

  const AudioStateModel({
    required this.currentTrackId,
    required this.loop,
    required this.volume,
    required this.isPlaying,
  });

  const AudioStateModel.initial()
      : currentTrackId = null,
        loop = true,
        volume = 0.3,
        isPlaying = false;

  factory AudioStateModel.fromJson(Map<String, dynamic> json) {
    return AudioStateModel(
      currentTrackId: json['currentTrackId'] as String?,
      loop: (json['loop'] as bool?) ?? true,
      volume: _readJsonDouble(json['volume'], fallback: 0.3),
      isPlaying: (json['isPlaying'] as bool?) ?? false,
    );
  }

  AudioStateModel copyWith({
    Object? currentTrackId = _unsetTrackId,
    bool? loop,
    double? volume,
    bool? isPlaying,
  }) {
    return AudioStateModel(
      currentTrackId: identical(currentTrackId, _unsetTrackId)
          ? this.currentTrackId
          : currentTrackId as String?,
      loop: loop ?? this.loop,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTrackId': currentTrackId,
      'loop': loop,
      'volume': volume,
      'isPlaying': isPlaying,
    };
  }
}

class UiStateModel {
  final List<String> collapsedGroupIds;
  final String outputScaleMode;
  final bool layerTreePanelCollapsed;
  final bool notesPanelCollapsed;
  final String notesText;

  const UiStateModel({
    required this.collapsedGroupIds,
    required this.outputScaleMode,
    required this.layerTreePanelCollapsed,
    required this.notesPanelCollapsed,
    required this.notesText,
  });

  const UiStateModel.initial()
      : collapsedGroupIds = const [],
        outputScaleMode = 'stretch',
        layerTreePanelCollapsed = false,
        notesPanelCollapsed = true,
        notesText = '';

  factory UiStateModel.fromJson(Map<String, dynamic> json) {
    final raw = json['collapsedGroupIds'];
    final rawMode = (json['outputScaleMode'] as String?)?.toLowerCase();
    final mode = rawMode == 'contain' ? 'contain' : 'stretch';
    final hasLayerTreePanelCollapsed =
        json.containsKey('layerTreePanelCollapsed');
    final hasNotesPanelCollapsed = json.containsKey('notesPanelCollapsed');
    var layerTreePanelCollapsed = json['layerTreePanelCollapsed'] == true;
    var notesPanelCollapsed =
        hasNotesPanelCollapsed ? json['notesPanelCollapsed'] == true : true;
    final notesText =
        json['notesText'] is String ? json['notesText'] as String : '';
    if (!hasLayerTreePanelCollapsed && !hasNotesPanelCollapsed) {
      layerTreePanelCollapsed = false;
      notesPanelCollapsed = true;
    } else if (!layerTreePanelCollapsed && !notesPanelCollapsed) {
      notesPanelCollapsed = true;
    }
    if (raw is List) {
      return UiStateModel(
        collapsedGroupIds: raw.whereType<String>().toList(),
        outputScaleMode: mode,
        layerTreePanelCollapsed: layerTreePanelCollapsed,
        notesPanelCollapsed: notesPanelCollapsed,
        notesText: notesText,
      );
    }
    return UiStateModel(
      collapsedGroupIds: const [],
      outputScaleMode: mode,
      layerTreePanelCollapsed: layerTreePanelCollapsed,
      notesPanelCollapsed: notesPanelCollapsed,
      notesText: notesText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collapsedGroupIds': collapsedGroupIds,
      'outputScaleMode': outputScaleMode,
      'layerTreePanelCollapsed': layerTreePanelCollapsed,
      'notesPanelCollapsed': notesPanelCollapsed,
      'notesText': notesText,
    };
  }
}

class ProjectModel {
  final int version;
  final int formatVersion;
  final String name;
  final ProjectMode currentMode;
  final CanvasModel canvas;
  final NodeModel root;
  final List<AudioTrackModel> tracks;
  final AudioStateModel audioState;
  final BattleModuleModel battle;
  final UiStateModel uiState;

  const ProjectModel({
    required this.version,
    required this.formatVersion,
    required this.name,
    required this.currentMode,
    required this.canvas,
    required this.root,
    required this.tracks,
    required this.audioState,
    required this.battle,
    required this.uiState,
  });

  factory ProjectModel.initial() {
    return ProjectModel(
      version: 1,
      formatVersion: 1,
      name: '主持中枢项目',
      currentMode: ProjectMode.scene,
      canvas: const CanvasModel(width: 1920, height: 1080),
      root: NodeModel(
        id: 'root',
        type: NodeType.group,
        name: '根节点',
        visible: true,
        locked: false,
        opacity: 1,
        transform: const TransformModel.identity(),
        children: const [
          NodeModel(
            id: 'group_cg',
            type: NodeType.group,
            name: 'CG',
            visible: true,
            locked: false,
            opacity: 1,
            transform: TransformModel.identity(),
            children: [],
          ),
          NodeModel(
            id: 'group_npc',
            type: NodeType.group,
            name: 'NPC',
            visible: true,
            locked: false,
            opacity: 1,
            transform: TransformModel.identity(),
            children: [],
          ),
          NodeModel(
            id: 'group_player',
            type: NodeType.group,
            name: '玩家',
            visible: true,
            locked: false,
            opacity: 1,
            transform: TransformModel.identity(),
            children: [],
          ),
          NodeModel(
            id: 'group_background',
            type: NodeType.group,
            name: '背景',
            visible: true,
            locked: false,
            opacity: 1,
            transform: TransformModel.identity(),
            children: [],
          ),
        ],
      ),
      tracks: const [],
      audioState: const AudioStateModel.initial(),
      battle: const BattleModuleModel.initial(),
      uiState: const UiStateModel.initial(),
    );
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final rawAudio =
        (json['audio'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawTracks = rawAudio['tracks'];
    final rawBattle =
        (json['battle'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProjectModel(
      version: _readJsonInt(json['version'], fallback: 1),
      formatVersion: _readJsonInt(json['formatVersion'], fallback: 1),
      name: (json['name'] as String?) ?? '主持中枢项目',
      currentMode: projectModeFromJson(json['currentMode']),
      canvas: CanvasModel.fromJson(
        (json['canvas'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      root: NodeModel.fromJson(
        (json['root'] as Map?)?.cast<String, dynamic>() ??
            ProjectModel.initial().root.toJson(),
      ),
      tracks: rawTracks is List
          ? rawTracks
              .whereType<Map>()
              .map((e) => AudioTrackModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      audioState: AudioStateModel.fromJson(
        (rawAudio['state'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      battle: BattleModuleModel.fromJson(rawBattle),
      uiState: UiStateModel.fromJson(
        (json['uiState'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  ProjectModel copyWith({
    int? version,
    int? formatVersion,
    String? name,
    ProjectMode? currentMode,
    CanvasModel? canvas,
    NodeModel? root,
    List<AudioTrackModel>? tracks,
    AudioStateModel? audioState,
    BattleModuleModel? battle,
    UiStateModel? uiState,
  }) {
    return ProjectModel(
      version: version ?? this.version,
      formatVersion: formatVersion ?? this.formatVersion,
      name: name ?? this.name,
      currentMode: currentMode ?? this.currentMode,
      canvas: canvas ?? this.canvas,
      root: root ?? this.root,
      tracks: tracks ?? this.tracks,
      audioState: audioState ?? this.audioState,
      battle: battle ?? this.battle,
      uiState: uiState ?? this.uiState,
    );
  }

  String toPrettyJson() {
    final jsonObject = {
      'version': version,
      'formatVersion': formatVersion,
      'name': name,
      'currentMode': currentMode.name,
      'canvas': {
        'width': canvas.width,
        'height': canvas.height,
      },
      'root': root.toJson(),
      'audio': {
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'state': audioState.toJson(),
      },
      'battle': battle.toJson(),
      'uiState': uiState.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(jsonObject);
  }
}
